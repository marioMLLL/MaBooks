import Foundation
import Testing
import ReaderCore
@testable import WeReadKit

private final class StubProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, json) = try Self.handler!(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(json.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

private func body(_ request: URLRequest) throws -> [String: Any] {
    var data = request.httpBody ?? Data()
    if data.isEmpty, let stream = request.httpBodyStream {
        stream.open(); defer { stream.close() }
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(contentsOf: buffer.prefix(count))
        }
    }
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
}

@Suite(.serialized)
struct GatewayClientTests {
    private func makeClient(_ handler: @escaping (URLRequest) throws -> (Int, String)) -> GatewayClient {
        StubProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return GatewayClient(apiKey: "wrk-fixture-only", session: URLSession(configuration: config))
    }

    @Test func shelfRequestUsesOfficialEndpointAndFlatParameters() async throws {
        let client = makeClient { request in
            #expect(request.url == GatewayClient.endpoint)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer wrk-fixture-only")
            let payload = try body(request)
            #expect(payload["api_name"] as? String == "/shelf/sync")
            #expect(payload["skill_version"] as? String == "1.0.5")
            #expect(payload["params"] == nil)
            return (200, #"{"books":[{"bookId":"42","title":"Fixture","author":"Test","readerLink":"https://weread.qq.com/web/reader/opaque"}],"albums":[],"mp":null}"#)
        }
        let shelf = try await client.fetchShelf()
        #expect(shelf.count == 1)
        #expect(shelf[0].source == .weread)
        #expect(shelf[0].readerURL?.path == "/web/reader/opaque")
    }

    @Test func highlightsPreserveExactChapterAndOpaqueRange() async throws {
        let client = makeClient { request in
            let payload = try body(request)
            #expect(payload["bookId"] as? String == "42")
            #expect(payload["chapterUid"] as? Int == 0)
            #expect(payload["synckey"] as? Int == 0)
            return (200, #"{"items":[{"chapterUid":7,"range":"393-401","markText":"原文","totalCount":123},{"chapterUid":8,"range":"393-401","markText":"另一章"}],"chapters":[{"chapterUid":7,"title":"第七章"}]}"#)
        }
        let highlights = try await client.fetchHighlights(bookID: "42")
        #expect(highlights[0].anchor == ParagraphAnchor(bookID: "42", chapterUID: 7, range: "393-401"))
        #expect(highlights[0].chapterTitle == "第七章")
        #expect(highlights[0].highlightCount == 123)
        #expect(highlights[0].id != highlights[1].id)
    }

    @Test(arguments: [
        #"{"synckey":123}"#,
        #"{"synckey":123,"items":null}"#,
        #"{"totalCount":0}"#,
        #"{"synckey":123,"totalCount":0,"items":null}"#,
        #"{"items":[]}"#,
        #"{"errcode":0,"data":{"synckey":123}}"#
    ])
    func emptyHighlightsCanOmitTheItemsArray(_ json: String) async throws {
        let client = makeClient { request in
            let payload = try body(request)
            #expect(payload["api_name"] as? String == "/book/bestbookmarks")
            #expect(payload["synckey"] as? Int == 0)
            return (200, json)
        }
        #expect(try await client.fetchHighlights(bookID: "fixture-book").isEmpty)
    }

    @Test(arguments: [
        #"{}"#,
        #"{"unexpected":[]}"#,
        #"{"synckey":123,"totalCount":2}"#,
        #"{"synckey":123,"items":{}}"#,
        #"{"items":null}"#,
        #"{"items":[{"chapterUid":7,"markText":"合成摘录","range":""}]}"#
    ])
    func invalidHighlightsAreNotSilentlyTreatedAsEmpty(_ json: String) async throws {
        let client = makeClient { _ in (200, json) }
        do {
            _ = try await client.fetchHighlights(bookID: "fixture-book")
            Issue.record("Expected malformed response")
        } catch GatewayError.malformed {} catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func commentsUseSelectedRangeAndServerPagingCursor() async throws {
        let client = makeClient { request in
            let payload = try body(request)
            #expect(payload["api_name"] as? String == "/book/readreviews")
            #expect(payload["bookId"] as? String == "42")
            #expect(payload["chapterUid"] as? Int == 7)
            let ranges = payload["reviews"] as! [[String: Any]]
            #expect(ranges[0]["range"] as? String == "393-401")
            #expect(ranges[0]["maxIdx"] as? Int == 20)
            #expect(ranges[0]["synckey"] as? Int == 99)
            #expect(ranges[0]["count"] as? Int == 20)
            return (200, #"{"reviews":[{"range":"wrong","pageReviews":[]},{"range":"393-401","hasMore":1,"maxIdx":40,"synckey":101,"pageReviews":[{"reviewId":"r1","review":{"content":"这条想法","author":{"name":"读者甲"},"createTime":1748563200}}]}]}"#)
        }
        let page = try await client.fetchComments(anchor: ParagraphAnchor(bookID: "42", chapterUID: 7, range: "393-401"), cursor: CommentCursor(maxIndex: 20, syncKey: 99))
        #expect(page.comments[0].text == "这条想法")
        #expect(page.comments[0].author == "读者甲")
        #expect(page.nextCursor == CommentCursor(maxIndex: 40, syncKey: 101))
    }

    @Test func emptyCommentPageIsValid() async throws {
        let client = makeClient { _ in (200, #"{"reviews":[{"range":"a","hasMore":0,"pageReviews":[]}]}"#) }
        let page = try await client.fetchComments(anchor: ParagraphAnchor(bookID: "b", chapterUID: 1, range: "a"))
        #expect(page.comments.isEmpty)
        #expect(page.nextCursor == nil)
    }

    @Test func authAndUpgradeFailuresDoNotFallBackToSample() async throws {
        let auth = makeClient { _ in (401, "{}") }
        await #expect(throws: GatewayError.self) { _ = try await auth.fetchShelf() }
        let upgrade = makeClient { _ in (200, #"{"upgrade_info":{"message":"update"},"books":[]}"#) }
        do { _ = try await upgrade.fetchShelf(); Issue.record("Expected upgrade failure") }
        catch GatewayError.upgradeRequired {} catch { Issue.record("Wrong error: \(error)") }
        let remote = makeClient { _ in (200, #"{"errcode":-1}"#) }
        await #expect(throws: GatewayError.self) { _ = try await remote.fetchShelf() }
    }

    @Test func malformedOrUnrelatedRangeCannotBeAttachedToSelection() async throws {
        let client = makeClient { _ in (200, #"{"reviews":[{"range":"other","pageReviews":[]}]}"#) }
        await #expect(throws: GatewayError.self) {
            _ = try await client.fetchComments(anchor: ParagraphAnchor(bookID: "b", chapterUID: 1, range: "selected"))
        }
        let malformed = makeClient { _ in (200, #"{"unexpected":[]}"#) }
        await #expect(throws: GatewayError.self) { _ = try await malformed.fetchHighlights(bookID: "b") }
    }

    @Test func unchangedPaginationCursorFailsInsteadOfLooping() async throws {
        let client = makeClient { _ in (200, #"{"reviews":[{"range":"a","hasMore":1,"maxIdx":20,"synckey":99,"pageReviews":[]}]}"#) }
        await #expect(throws: GatewayError.self) {
            _ = try await client.fetchComments(anchor: ParagraphAnchor(bookID: "b", chapterUID: 1, range: "a"), cursor: CommentCursor(maxIndex: 20, syncKey: 99))
        }
    }

    @Test func envelopeResponseIsSupported() async throws {
        let client = makeClient { _ in (200, #"{"errcode":0,"data":{"books":[]}}"#) }
        #expect(try await client.fetchShelf().isEmpty)
    }

    @Test func missingKeyFailsBeforeNetwork() async throws {
        let client = GatewayClient(apiKey: "  ")
        do { _ = try await client.fetchShelf(); Issue.record("Expected missing key") }
        catch GatewayError.missingKey {} catch { Issue.record("Wrong error: \(error)") }
    }
}
