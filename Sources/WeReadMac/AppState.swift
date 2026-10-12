import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ReaderCore
import WeReadKit

@MainActor
final class AppState: ObservableObject {
    @Published var localBooks: [LocalBook] = []
    @Published var shelf: [Book] = []
    @Published var selectedBook = SampleLibrary.book
    @Published var paragraphs = SampleLibrary.paragraphs
    @Published var selectedParagraph: Paragraph?
    @Published var comments: [ReaderComment] = []
    @Published var nextCursor: CommentCursor?
    @Published var loadingShelf = false
    @Published var loadingBook = false
    @Published var loadingComments = false
    @Published var shelfError: String?
    @Published var bookError: String?
    @Published var commentError: String?
    @Published var notice: String?
    @Published var hasKey = false
    @Published var showsWeb = false
    @Published var showsSettings = false
    @Published var showsComments = true
    @Published var page = 0
    let web = WebSession()
    private var client: GatewayClient?
    private var libraryStore: LibraryStore?
    private var bookRequest = UUID()
    private var commentRequest = UUID()
    private var shelfRequest = UUID()
    private var commentTask: Task<Void, Never>?

    var books: [Book] { [SampleLibrary.book] + localBooks.map(\.book) }
    var pageCount: Int { max(1, (paragraphs.count + 3) / 4) }

    init() {
        do {
            let store = try LibraryStore()
            libraryStore = store
            localBooks = try store.load()
        } catch { notice = "本地书库读取失败：\(error.localizedDescription)" }
        do {
            if let key = try KeychainStore.read(), !key.isEmpty { client = GatewayClient(apiKey: key); hasKey = true }
        } catch { notice = error.localizedDescription }
        restoreLocation()
    }

    func saveKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("wrk-"), !trimmed.contains(where: { $0.isWhitespace }) else { throw AccountError.invalidKey }
        try KeychainStore.save(trimmed)
        invalidateRemoteData()
        client = GatewayClient(apiKey: trimmed); hasKey = true
        Task { await refreshShelf() }
    }

    func disconnect() throws {
        try KeychainStore.delete()
        invalidateRemoteData()
        client = nil; hasKey = false
    }

    private func invalidateRemoteData() {
        shelfRequest = UUID(); bookRequest = UUID(); commentRequest = UUID(); commentTask?.cancel()
        shelf = []; shelfError = nil; loadingShelf = false; loadingBook = false; loadingComments = false
        if selectedBook.source == .weread { openLocal(SampleLibrary.book) }
    }

    func refreshShelf() async {
        guard let client else { showsSettings = true; return }
        let token = UUID(); shelfRequest = token
        loadingShelf = true; shelfError = nil
        do {
            let result = try await client.fetchShelf()
            guard shelfRequest == token else { return }
            shelf = result
        } catch {
            guard shelfRequest == token else { return }
            shelfError = readable(error)
        }
        if shelfRequest == token { loadingShelf = false }
    }

    func open(_ book: Book) {
        if book.source != .weread { openLocal(book); return }
        guard let client else { showsSettings = true; return }
        let token = UUID(); bookRequest = token
        selectedBook = book; paragraphs = []; resetComments(); page = 0
        showsWeb = false; loadingBook = true; bookError = nil
        Task {
            do {
                let result = try await client.fetchHighlights(bookID: book.id)
                guard bookRequest == token else { return }
                // Server range IDs can repeat; SwiftUI requires unique paragraph identities.
                var seen = Set<String>()
                paragraphs = result.filter { seen.insert($0.id).inserted }
                restoreLocation()
            } catch {
                guard bookRequest == token else { return }
                bookError = readable(error)
            }
            if bookRequest == token { loadingBook = false }
        }
    }

    private func openLocal(_ book: Book) {
        bookRequest = UUID(); loadingBook = false; bookError = nil
        selectedBook = book
        paragraphs = book.source == .sample ? SampleLibrary.paragraphs : localBooks.first { $0.book.id == book.id }?.paragraphs ?? []
        showsWeb = false; resetComments(); page = 0; restoreLocation()
    }

    private func resetComments() {
        commentTask?.cancel(); commentRequest = UUID()
        selectedParagraph = nil; comments = []; nextCursor = nil; commentError = nil; loadingComments = false
    }

    private func restoreLocation() {
        let id = UserDefaults.standard.string(forKey: "position.\(selectedBook.id)")
        if let paragraph = paragraphs.first(where: { $0.id == id }) { select(paragraph, reveal: false) }
    }

    func select(_ paragraph: Paragraph, reveal: Bool = true) {
        guard paragraphs.contains(where: { $0.id == paragraph.id }) else { return }
        resetComments()
        selectedParagraph = paragraph
        if reveal { showsComments = true }
        if let index = paragraphs.firstIndex(where: { $0.id == paragraph.id }) { page = index / 4 }
        UserDefaults.standard.set(paragraph.id, forKey: "position.\(selectedBook.id)")
        if selectedBook.source == .sample { comments = SampleLibrary.comments(for: paragraph) }
        else if paragraph.anchor != nil { loadComments() }
    }

    func loadComments() {
        guard !loadingComments, let paragraph = selectedParagraph, let anchor = paragraph.anchor, let client else { return }
        let token = UUID(); commentRequest = token
        let cursor = nextCursor
        loadingComments = true; commentError = nil
        commentTask = Task {
            do {
                let result = try await client.fetchComments(anchor: anchor, cursor: cursor)
                guard !Task.isCancelled, commentRequest == token, selectedParagraph?.id == paragraph.id else { return }
                var seen = Set(comments.map(\.id))
                comments.append(contentsOf: result.comments.filter { seen.insert($0.id).inserted })
                nextCursor = result.nextCursor
            } catch {
                guard !Task.isCancelled, commentRequest == token else { return }
                commentError = readable(error)
            }
            if commentRequest == token { loadingComments = false }
        }
    }

    func navigatePage(_ offset: Int) {
        let newPage = min(max(page + offset, 0), pageCount - 1)
        guard newPage != page, paragraphs.indices.contains(newPage * 4) else { return }
        select(paragraphs[newPage * 4], reveal: false)
    }

    func showOfficialReader(for book: Book? = nil) {
        web.navigate(OfficialReaderURL.validated(book?.readerURL) ?? OfficialReaderURL.home)
        showsWeb = true
    }

    func importText() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size <= 10 * 1024 * 1024 else { throw AccountError.largeFile }
            let text = try String(contentsOf: url, encoding: .utf8)
            let local = LocalBook.importing(text: text, title: url.deletingPathExtension().lastPathComponent)
            guard !local.paragraphs.isEmpty else { throw AccountError.emptyFile }
            guard let libraryStore else { throw AccountError.libraryUnavailable }
            let updated = localBooks + [local]
            try libraryStore.save(updated)
            localBooks = updated; openLocal(local.book)
        } catch { notice = "导入失败：\(error.localizedDescription)" }
    }

    private func readable(_ error: Error) -> String {
        if error is GatewayError { return error.localizedDescription }
        if let network = error as? URLError {
            return "网络连接失败（\(network.code.rawValue)），请检查网络后重试。"
        }
        return "数据读取失败，请重试或更新应用。"
    }
}

enum AccountError: LocalizedError {
    case invalidKey, emptyFile, largeFile, libraryUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidKey: "API Key 应以 wrk- 开头，且不能包含空白字符。"
        case .emptyFile: "文件中没有可阅读的文字。"
        case .largeFile: "当前版本支持 10 MB 以内的 TXT 文件。"
        case .libraryUnavailable: "本地书库不可用，请重新打开应用。"
        }
    }
}
