import Foundation

public enum TXTImportPolicy {
    public static let maximumBytes = 100 * 1024 * 1024
    public static func validateSize(_ bytes: Int) throws {
        if bytes < 0 || bytes > maximumBytes { throw TXTImportError.tooLarge }
    }
    public static func read(_ url: URL) throws -> LocalBook {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        try validateSize(size)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        try validateSize(data.count)
        guard let text = String(data: data, encoding: .utf8) else { throw TXTImportError.invalidUTF8 }
        let book = LocalBook.importing(text: text, title: url.deletingPathExtension().lastPathComponent)
        guard !book.paragraphs.isEmpty else { throw TXTImportError.empty }
        return book
    }
}

public enum TXTImportError: LocalizedError {
    case tooLarge, invalidUTF8, empty
    public var errorDescription: String? {
        switch self {
        case .tooLarge: "当前支持 100 MB（100 MiB）以内的 TXT 文件。"
        case .invalidUTF8: "请将 TXT 文件保存为 UTF-8 编码后再导入。"
        case .empty: "文件中没有可阅读的文字。"
        }
    }
}

/// A single atomic snapshot keeps deletion recoverable even if saving fails.
public struct LocalLibraryArchive: Codable, Sendable {
    public var books: [LocalBook]
    public var deletedBooks: [LocalBook]
    public init(books: [LocalBook] = [], deletedBooks: [LocalBook] = []) {
        self.books = books; self.deletedBooks = deletedBooks
    }
    public static func decode(_ data: Data) throws -> Self {
        let decoder = JSONDecoder()
        if data.first(where: { ![9, 10, 13, 32].contains($0) }) == 91 {
            return Self(books: try decoder.decode([LocalBook].self, from: data))
        }
        return try decoder.decode(Self.self, from: data)
    }
    @discardableResult public mutating func delete(bookID: String) -> Bool {
        guard let index = books.firstIndex(where: { $0.book.id == bookID && $0.book.source == .local }) else { return false }
        let book = books.remove(at: index)
        deletedBooks.removeAll { $0.book.id == bookID }
        deletedBooks.append(book)
        return true
    }
    @discardableResult public mutating func restore(bookID: String) -> Bool {
        guard !books.contains(where: { $0.book.id == bookID }),
              let index = deletedBooks.firstIndex(where: { $0.book.id == bookID }) else { return false }
        books.append(deletedBooks.remove(at: index))
        return true
    }
}
