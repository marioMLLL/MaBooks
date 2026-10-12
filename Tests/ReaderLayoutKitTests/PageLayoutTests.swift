import AppKit
import Testing
import ReaderCore
import ReaderLayoutKit

@Test func longParagraphPagesHaveNoLostOrRepeatedText() {
    let text = String(repeating: "一段跨页的文字 👩🏽‍💻，标点与 emoji 应完整保留。Café reading. ", count: 180)
    let document = ReadingDocument(paragraphs: [Paragraph(id: "long", text: text, chapterTitle: "")])
    let layout = PageLayout(document: document, size: CGSize(width: 320, height: 300), fontSize: 20, color: .black)
    #expect(layout.ranges.count > 2)
    var next = 0
    let source = document.text as NSString
    var rebuilt = ""
    for range in layout.ranges {
        #expect(range.location == next)
        #expect(range.length > 0)
        next = NSMaxRange(range)
        rebuilt += source.substring(with: range)
        if next < source.length {
            #expect(NSMaxRange(source.rangeOfComposedCharacterSequence(at: next - 1)) == next)
        }
    }
    #expect(next == source.length)
    #expect(rebuilt == document.text)
}

@Test func typographyAndViewportRepaginateAroundTheSamePosition() {
    let paragraphs = (0..<50).map { Paragraph(id: "p-\($0)", text: String(repeating: "Original synthetic text for pagination. ", count: 8), chapterTitle: "") }
    let document = ReadingDocument(paragraphs: paragraphs)
    let small = PageLayout(document: document, size: CGSize(width: 600, height: 400), fontSize: 16, color: .black)
    let large = PageLayout(document: document, size: CGSize(width: 300, height: 250), fontSize: 30, color: .black)
    #expect(large.ranges.count > small.ranges.count)
    let position = ReadingPosition(paragraphID: "p-22", utf16Offset: 91)
    let offset = document.offset(for: position)!
    #expect(document.position(at: offset) == position)
    for layout in [small, large] {
        let index = ReadingDocument.pageIndex(containing: offset, pages: layout.ranges)
        #expect(NSLocationInRange(offset, layout.ranges[index]))
    }
}

@Test func emptyBookDoesNotCreateAPhantomPage() {
    let layout = PageLayout(document: ReadingDocument(paragraphs: []), size: CGSize(width: 300, height: 400), fontSize: 20, color: .black)
    #expect(layout.ranges.isEmpty)
}

@Test func unbrokenTextStillFitsAcrossPages() {
    let text = String(repeating: "abcdefghijklmnopqrstuvwxyz", count: 400)
    let document = ReadingDocument(paragraphs: [Paragraph(id: "unbroken", text: text, chapterTitle: "")])
    let pages = PageLayout(document: document, size: CGSize(width: 240, height: 250), fontSize: 24, color: .black)
    #expect(pages.ranges.count > 1)
    #expect(pages.ranges.reduce(0) { $0 + $1.length } == text.utf16.count)
}
