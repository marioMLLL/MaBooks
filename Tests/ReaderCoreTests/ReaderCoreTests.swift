import Foundation
import Testing
@testable import ReaderCore

@Test func localImportNormalizesLineEndingsAndPersistsStableIDs() throws {
    let imported = LocalBook.importing(text: "第一段\r\n\r\n 第二段 \r第三段\n", title: "测试书", id: "local-book")
    #expect(imported.paragraphs.map(\.text) == ["第一段", "第二段", "第三段"])
    #expect(imported.paragraphs.map(\.id) == ["local-book-0", "local-book-1", "local-book-2"])
    let decoded = try JSONDecoder().decode(LocalBook.self, from: JSONEncoder().encode(imported))
    #expect(decoded.book == imported.book)
    #expect(decoded.paragraphs == imported.paragraphs)
    #expect(decoded.paragraphs.allSatisfy { $0.anchor == nil })
}

@Test func anchorIdentityIncludesBookAndChapter() {
    let a = ParagraphAnchor(bookID: "a", chapterUID: 1, range: "393-401")
    let b = ParagraphAnchor(bookID: "b", chapterUID: 1, range: "393-401")
    let c = ParagraphAnchor(bookID: "a", chapterUID: 2, range: "393-401")
    #expect(Set([a, b, c]).count == 3)
}

@Test func readerLinksRequireExactOfficialHTTPSHost() {
    #expect(OfficialReaderURL.validated(URL(string: "https://weread.qq.com/web/reader/abc")) != nil)
    for text in ["http://weread.qq.com/", "https://weread.qq.com.evil.test/", "https://evil.test/weread.qq.com", "weread://reader/abc", "https://user:password@weread.qq.com/", "https://weread.qq.com:8443/"] {
        #expect(OfficialReaderURL.validated(URL(string: text)) == nil)
    }
}

@Test func emptyImportProducesNoSyntheticParagraph() {
    #expect(LocalBook.importing(text: "\n \n", title: "空书").paragraphs.isEmpty)
}
