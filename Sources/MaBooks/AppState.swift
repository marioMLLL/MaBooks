import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ReaderCore
import WeReadKit

@MainActor
final class AppState: ObservableObject {
    @Published var localBooks: [LocalBook] = []
    @Published var deletedBooks: [LocalBook] = []
    @Published var libraryBusy = false
    @Published var showsDeletedBooks = false
    @Published var readingCandidates: [Book] = []
    @Published var searchingBooks = false
    @Published var searchError: String?
    @Published var showsBookSearch = false
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
    @Published var pageRanges: [NSRange] = []
    @Published var readingOffset = 0
    private(set) var readingDocument = ReadingDocument(paragraphs: SampleLibrary.paragraphs)
    let web = WebSession()
    private var client: GatewayClient?
    private var libraryStore: LibraryStore?
    private var bookRequest = UUID()
    private var commentRequest = UUID()
    private var shelfRequest = UUID()
    private var bookSearchRequest = UUID()
    private var commentTask: Task<Void, Never>?

    var books: [Book] { [SampleLibrary.book] + localBooks.map(\.book) }
    var pageCount: Int { max(1, pageRanges.count) }

    init(libraryStore suppliedStore: LibraryStore? = nil, loadCredential: Bool = true) {
        do {
            let store = try suppliedStore ?? LibraryStore()
            libraryStore = store
            libraryBusy = true
            Task {
                defer { libraryBusy = false }
                do {
                    let archive = try await Task.detached(priority: .userInitiated) { try store.load() }.value
                    localBooks = archive.books; deletedBooks = archive.deletedBooks
                } catch { notice = "本地书库读取失败：\(error.localizedDescription)" }
            }
        } catch { notice = "本地书库读取失败：\(error.localizedDescription)" }
        do {
            if loadCredential, let key = try KeychainStore.read(), !key.isEmpty { client = GatewayClient(apiKey: key); hasKey = true }
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
        bookSearchRequest = UUID(); showsBookSearch = false; searchingBooks = false
        selectedBook = book; paragraphs = []; resetComments(); page = 0
        pageRanges = []; readingOffset = 0
        showsWeb = true; loadingBook = true; bookError = nil
        web.openBook(book)
        Task {
            do {
                let detail = try await client.fetchBookInfo(bookID: book.id)
                guard bookRequest == token else { return }
                if let url = detail.readerURL, url != book.readerURL {
                    selectedBook = detail
                    web.openBook(detail)
                }
            } catch GatewayError.upgradeRequired {
                guard bookRequest == token else { return }
                web.readerNotice = GatewayError.upgradeRequired.localizedDescription
            } catch {
                // A failed metadata refresh must not block the supplied official reader URL.
            }
        }
        Task {
            do {
                let result = try await client.fetchHighlights(bookID: book.id)
                guard bookRequest == token else { return }
                // Server range IDs can repeat; SwiftUI requires unique paragraph identities.
                var seen = Set<String>()
                paragraphs = result.filter { seen.insert($0.id).inserted }
                readingDocument = ReadingDocument(paragraphs: paragraphs)
                restoreLocation()
            } catch {
                guard bookRequest == token else { return }
                bookError = readable(error)
            }
            if bookRequest == token { loadingBook = false }
        }
    }

    private func openLocal(_ book: Book) {
        bookSearchRequest = UUID(); showsBookSearch = false; searchingBooks = false
        bookRequest = UUID(); loadingBook = false; bookError = nil
        selectedBook = book
        paragraphs = book.source == .sample ? SampleLibrary.paragraphs : localBooks.first { $0.book.id == book.id }?.paragraphs ?? []
        readingDocument = ReadingDocument(paragraphs: paragraphs)
        pageRanges = []; readingOffset = 0
        showsWeb = false; resetComments(); page = 0; restoreLocation()
        if book.source == .local { showsComments = false }
    }

    private func resetComments() {
        commentTask?.cancel(); commentRequest = UUID()
        selectedParagraph = nil; comments = []; nextCursor = nil; commentError = nil; loadingComments = false
    }

    private func restoreLocation() {
        let id = UserDefaults.standard.string(forKey: "position.\(selectedBook.id)")
        let offset = UserDefaults.standard.integer(forKey: "position.offset.\(selectedBook.id)")
        if let paragraph = paragraphs.first(where: { $0.id == id }) {
            select(paragraph, reveal: false)
            readingOffset = readingDocument.offset(for: ReadingPosition(paragraphID: paragraph.id, utf16Offset: offset)) ?? 0
        }
        else if selectedBook.source == .sample, let first = paragraphs.first { select(first, reveal: false) }
    }

    func select(_ paragraph: Paragraph, reveal: Bool = true) {
        guard paragraphs.contains(where: { $0.id == paragraph.id }) else { return }
        resetComments()
        selectedParagraph = paragraph
        if reveal { showsComments = true }
        readingOffset = readingDocument.offset(for: ReadingPosition(paragraphID: paragraph.id)) ?? 0
        page = ReadingDocument.pageIndex(containing: readingOffset, pages: pageRanges)
        UserDefaults.standard.set(paragraph.id, forKey: "position.\(selectedBook.id)")
        UserDefaults.standard.set(0, forKey: "position.offset.\(selectedBook.id)")
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
        guard newPage != page, pageRanges.indices.contains(newPage) else { return }
        let location = pageRanges[newPage].location
        selectReadingOffset(location, reveal: false)
    }

    func selectReadingOffset(_ location: Int, reveal: Bool) {
        guard let position = readingDocument.position(at: location),
              let paragraph = paragraphs.first(where: { $0.id == position.paragraphID }) else { return }
        select(paragraph, reveal: reveal)
        page = ReadingDocument.pageIndex(containing: location, pages: pageRanges)
        readingOffset = location
        UserDefaults.standard.set(position.utf16Offset, forKey: "position.offset.\(selectedBook.id)")
    }

    func setPageRanges(_ ranges: [NSRange], bookID: String) {
        guard selectedBook.id == bookID else { return }
        pageRanges = ranges
        page = ReadingDocument.pageIndex(containing: readingOffset, pages: ranges)
    }

    func showOfficialReader(for book: Book? = nil) {
        if let book { web.openBook(book) }
        else { web.clearBookContext(); web.navigate(OfficialReaderURL.home) }
        showsWeb = true
    }

    func searchReadingCandidates(novels: Bool) {
        guard let client, selectedBook.source == .weread else { showsSettings = true; return }
        let bookID = selectedBook.id
        let title = selectedBook.title
        let token = UUID(); bookSearchRequest = token
        showsBookSearch = true; searchingBooks = true; searchError = nil; readingCandidates = []
        Task {
            do {
                let results = try await client.searchBooks(title: title, novels: novels)
                guard bookSearchRequest == token, selectedBook.id == bookID else { return }
                readingCandidates = results
            } catch {
                guard bookSearchRequest == token, selectedBook.id == bookID else { return }
                searchError = readable(error)
            }
            searchingBooks = false
        }
    }

    func showHighlights() { showsWeb = false }

    func importText() {
        guard !libraryBusy else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let libraryStore else { notice = AccountError.libraryUnavailable.localizedDescription; return }
        let granted = url.startAccessingSecurityScopedResource()
        let snapshot = LocalLibraryArchive(books: localBooks, deletedBooks: deletedBooks)
        libraryBusy = true
        Task {
            defer { if granted { url.stopAccessingSecurityScopedResource() }; libraryBusy = false }
            do {
                let (archive, local) = try await Task.detached(priority: .userInitiated) {
                    let local = try TXTImportPolicy.read(url)
                    var archive = snapshot
                    archive.books.append(local)
                    try libraryStore.save(archive)
                    return (archive, local)
                }.value
                localBooks = archive.books; openLocal(local.book)
            } catch { notice = "导入失败：\(error.localizedDescription)" }
        }
    }

    func deleteLocalBook(_ book: Book) {
        guard book.source == .local, !libraryBusy else { return }
        var archive = LocalLibraryArchive(books: localBooks, deletedBooks: deletedBooks)
        guard archive.delete(bookID: book.id) else { return }
        saveLibrary(archive, removedBookID: book.id)
    }

    func restoreLocalBook(_ book: Book) {
        guard !libraryBusy else { return }
        var archive = LocalLibraryArchive(books: localBooks, deletedBooks: deletedBooks)
        guard archive.restore(bookID: book.id) else { return }
        saveLibrary(archive)
    }

    private func saveLibrary(_ archive: LocalLibraryArchive, removedBookID: String? = nil) {
        guard let libraryStore else { notice = AccountError.libraryUnavailable.localizedDescription; return }
        libraryBusy = true
        Task {
            defer { libraryBusy = false }
            do {
                try await Task.detached(priority: .userInitiated) { try libraryStore.save(archive) }.value
                localBooks = archive.books; deletedBooks = archive.deletedBooks
                if selectedBook.id == removedBookID { openLocal(SampleLibrary.book) }
            } catch { notice = "书库保存失败，书籍未变更：\(error.localizedDescription)" }
        }
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
    case invalidKey, libraryUnavailable
    var errorDescription: String? {
        switch self {
        case .invalidKey: "API Key 应以 wrk- 开头，且不能包含空白字符。"
        case .libraryUnavailable: "本地书库不可用，请重新打开应用。"
        }
    }
}
