import Foundation

public enum BookSource: String, Codable, Sendable {
    case sample, local, weread
}

public struct Book: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public var title: String
    public var author: String
    public var source: BookSource
    public var readerURL: URL?
    public var coverURL: URL?
    public init(id: String, title: String, author: String, source: BookSource, readerURL: URL? = nil, coverURL: URL? = nil) {
        self.id = id; self.title = title; self.author = author; self.source = source; self.readerURL = readerURL
        self.coverURL = coverURL
    }
}

/// Keep ranges opaque: WeRead ranges are server positions, not Swift String offsets.
public struct ParagraphAnchor: Hashable, Codable, Sendable {
    public let bookID: String
    public let chapterUID: Int
    public let range: String
    public init(bookID: String, chapterUID: Int, range: String) {
        self.bookID = bookID; self.chapterUID = chapterUID; self.range = range
    }
}

public struct Paragraph: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let text: String
    public let chapterTitle: String
    public let anchor: ParagraphAnchor?
    public let highlightCount: Int
    public init(id: String, text: String, chapterTitle: String, anchor: ParagraphAnchor? = nil, highlightCount: Int = 0) {
        self.id = id; self.text = text; self.chapterTitle = chapterTitle; self.anchor = anchor; self.highlightCount = highlightCount
    }
}

public struct ReaderComment: Identifiable, Hashable, Sendable {
    public let id: String
    public let author: String
    public let text: String
    public let date: Date?
    public init(id: String, author: String, text: String, date: Date? = nil) {
        self.id = id; self.author = author; self.text = text; self.date = date
    }
}

public struct CommentCursor: Equatable, Sendable {
    public let maxIndex: Int
    public let syncKey: Int
    public init(maxIndex: Int, syncKey: Int) { self.maxIndex = maxIndex; self.syncKey = syncKey }
}

public struct CommentPage: Sendable {
    public let comments: [ReaderComment]
    public let nextCursor: CommentCursor?
    public init(comments: [ReaderComment], nextCursor: CommentCursor? = nil) {
        self.comments = comments; self.nextCursor = nextCursor
    }
}

public enum ReaderTheme: String, CaseIterable, Codable {
    case system, light, sepia, dark
    public var title: String {
        switch self { case .system: "跟随系统"; case .light: "明亮"; case .sepia: "纸张"; case .dark: "夜间" }
    }
}

public enum ReaderLayout: String, CaseIterable, Codable {
    case scroll, paged, focus
    public var title: String {
        switch self { case .scroll: "连续滚动"; case .paged: "分组翻页"; case .focus: "专注阅读" }
    }
}

public enum OfficialReaderURL {
    public static let home = URL(string: "https://weread.qq.com/")!
    public static func validated(_ url: URL?) -> URL? {
        guard let url, url.scheme?.lowercased() == "https", url.host?.lowercased() == "weread.qq.com",
              url.user == nil, url.password == nil, url.port == nil || url.port == 443 else { return nil }
        return url
    }
}
