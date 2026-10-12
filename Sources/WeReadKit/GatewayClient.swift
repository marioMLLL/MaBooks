import Foundation
import ReaderCore

public enum GatewayError: LocalizedError {
    case missingKey, http(Int), remote(Int), upgradeRequired, malformed, unsupportedAnchor
    public var errorDescription: String? {
        switch self {
        case .missingKey: "请先在账号设置中保存微信读书 API Key。"
        case .http(let code): code == 401 || code == 403 ? "API Key 无效或权限不足，请重新设置。" : "微信读书连接失败（HTTP \(code)），请稍后重试。"
        case .remote(let code): "微信读书返回错误（\(code)），请检查账号或稍后重试。"
        case .upgradeRequired: "微信读书要求更新接口版本，请更新应用后重试。"
        case .malformed: "接口返回格式已变化，请更新应用或反馈问题。"
        case .unsupportedAnchor: "这段文字缺少可用的章节或划线位置。"
        }
    }
}

/// Adapter for Tencent/WeChatReading official Gateway docs. No private mobile endpoints.
public final class GatewayClient: @unchecked Sendable {
    public static let endpoint = URL(string: "https://i.weread.qq.com/api/agent/gateway")!
    public static let skillVersion = "1.0.5"
    private let apiKey: String
    private let session: URLSession
    public init(apiKey: String, session: URLSession = URLSession(configuration: .ephemeral)) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines); self.session = session
    }

    private func request(_ api: String, parameters: [String: Any] = [:]) async throws -> [String: Any] {
        guard !apiKey.isEmpty else { throw GatewayError.missingKey }
        var body = parameters
        body["api_name"] = api
        body["skill_version"] = Self.skillVersion
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GatewayError.malformed }
        guard (200..<300).contains(http.statusCode) else { throw GatewayError.http(http.statusCode) }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw GatewayError.malformed }
        try validate(root)
        // Some Gateway deployments envelope the business response in data.
        let payload = root["data"] as? [String: Any] ?? root
        try validate(payload)
        return payload
    }

    private func validate(_ payload: [String: Any]) throws {
        if let upgrade = payload["upgrade_info"], !(upgrade is NSNull) { throw GatewayError.upgradeRequired }
        if let code = integer(payload["errcode"]), code != 0 { throw GatewayError.remote(code) }
    }

    public func fetchShelf() async throws -> [Book] {
        let payload = try await request("/shelf/sync")
        guard let rows = payload["books"] as? [[String: Any]] else { throw GatewayError.malformed }
        return try rows.map { row in
            guard let id = string(row["bookId"]), let title = row["title"] as? String else { throw GatewayError.malformed }
            let url = (row["readerLink"] as? String).flatMap(URL.init(string:))
            let cover = (row["cover"] as? String).flatMap(URL.init(string:))
            return Book(id: id, title: title, author: row["author"] as? String ?? "未知作者", source: .weread,
                        readerURL: OfficialReaderURL.validated(url), coverURL: cover?.scheme == "https" ? cover : nil)
        }
    }

    public func fetchHighlights(bookID: String) async throws -> [Paragraph] {
        let payload = try await request("/book/bestbookmarks", parameters: ["bookId": bookID, "chapterUid": 0, "synckey": 0])
        // The live Gateway omits items for empty results and can return only synckey.
        // Keep malformed arrays and missing lists with a positive count as errors.
        if payload["items"] == nil || payload["items"] is NSNull {
            let count = integer(payload["totalCount"])
            if count == 0 || (payload["totalCount"] == nil && integer(payload["synckey"]) != nil) { return [] }
            throw GatewayError.malformed
        }
        guard let rows = payload["items"] as? [[String: Any]] else { throw GatewayError.malformed }
        let chapters = payload["chapters"] as? [[String: Any]] ?? []
        var titles: [Int: String] = [:]
        for chapter in chapters {
            if let uid = integer(chapter["chapterUid"]), let title = chapter["title"] as? String { titles[uid] = title }
        }
        return try rows.map { row in
            guard let chapter = integer(row["chapterUid"]), let range = row["range"] as? String,
                  !range.isEmpty, let text = row["markText"] as? String else { throw GatewayError.malformed }
            let anchor = ParagraphAnchor(bookID: bookID, chapterUID: chapter, range: range)
            return Paragraph(id: "\(bookID):\(chapter):\(range)", text: text,
                             chapterTitle: titles[chapter] ?? "章节 \(chapter)", anchor: anchor,
                             highlightCount: integer(row["totalCount"]) ?? 0)
        }
    }

    public func fetchBookInfo(bookID: String) async throws -> Book {
        let payload = try await request("/book/info", parameters: ["bookId": bookID])
        let book = try mapBook(payload)
        guard book.id == bookID else { throw GatewayError.malformed }
        return book
    }

    public func searchBooks(title: String, novels: Bool) async throws -> [Book] {
        let payload = try await request("/store/search", parameters: ["keyword": title, "scope": novels ? 16 : 10])
        guard let groups = payload["results"] as? [[String: Any]] else { throw GatewayError.malformed }
        var books: [Book] = []
        var seen = Set<String>()
        for group in groups {
            guard let rows = group["books"] as? [[String: Any]] else { continue }
            for row in rows {
                guard let info = row["bookInfo"] as? [String: Any] else { throw GatewayError.malformed }
                let book = try mapBook(info)
                if seen.insert(book.id).inserted { books.append(book) }
            }
        }
        return books
    }

    private func mapBook(_ row: [String: Any]) throws -> Book {
        guard let id = string(row["bookId"]), !id.isEmpty,
              let title = row["title"] as? String, !title.isEmpty else { throw GatewayError.malformed }
        let reader = (row["readerLink"] as? String).flatMap(URL.init(string:))
        let cover = (row["cover"] as? String).flatMap(URL.init(string:))
        return Book(id: id, title: title, author: row["author"] as? String ?? "未知作者", source: .weread,
                    readerURL: OfficialReaderURL.validated(reader), coverURL: cover?.scheme == "https" ? cover : nil,
                    publisher: row["publisher"] as? String)
    }

    public func fetchComments(anchor: ParagraphAnchor, cursor: CommentCursor? = nil) async throws -> CommentPage {
        guard !anchor.bookID.isEmpty, !anchor.range.isEmpty else { throw GatewayError.unsupportedAnchor }
        let selection: [String: Any] = ["range": anchor.range, "count": 20,
                                        "maxIdx": cursor?.maxIndex ?? 0, "synckey": cursor?.syncKey ?? 0]
        let payload = try await request("/book/readreviews", parameters: ["bookId": anchor.bookID,
                                                                          "chapterUid": anchor.chapterUID, "reviews": [selection]])
        guard let ranges = payload["reviews"] as? [[String: Any]],
              let result = ranges.first(where: { $0["range"] as? String == anchor.range }),
              let rows = result["pageReviews"] as? [[String: Any]] else { throw GatewayError.malformed }
        let comments: [ReaderComment] = try rows.map { row in
            guard let review = row["review"] as? [String: Any],
                  let id = string(row["reviewId"] ?? review["reviewId"]), let content = review["content"] as? String else {
                throw GatewayError.malformed
            }
            let author = review["author"] as? [String: Any]
            let name = author?["name"] as? String ?? author?["nickname"] as? String ?? "读者"
            let date = (review["createTime"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) }
            return ReaderComment(id: id, author: name, text: content, date: date)
        }
        var next: CommentCursor?
        if integer(result["hasMore"]) == 1 {
            guard let index = integer(result["maxIdx"]), let sync = integer(result["synckey"]) else { throw GatewayError.malformed }
            next = CommentCursor(maxIndex: index, syncKey: sync)
            // Refuse a repeated cursor instead of showing an endless 'load more' loop.
            if next == cursor || (cursor == nil && index == 0 && sync == 0) { throw GatewayError.malformed }
        }
        return CommentPage(comments: comments, nextCursor: next)
    }
}

private func integer(_ value: Any?) -> Int? {
    if let number = value as? NSNumber { return number.intValue }
    if let string = value as? String { return Int(string) }
    return nil
}

private func string(_ value: Any?) -> String? {
    if let text = value as? String { return text }
    if let number = value as? NSNumber { return number.stringValue }
    return nil
}
