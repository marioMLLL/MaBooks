import Foundation

public struct ReadingPosition: Codable, Equatable, Sendable {
    public let paragraphID: String
    public let utf16Offset: Int
    public init(paragraphID: String, utf16Offset: Int = 0) {
        self.paragraphID = paragraphID; self.utf16Offset = utf16Offset
    }
}

/// UTF-16 coordinates match the native text layout engine, never remote WeRead ranges.
public struct ReadingDocument: Sendable {
    public struct Span: Sendable {
        public let paragraphID: String
        public let range: NSRange
    }
    public let text: String
    public let spans: [Span]
    public init(paragraphs: [Paragraph]) {
        var text = ""
        var spans: [Span] = []
        var offset = 0
        for paragraph in paragraphs {
            if !spans.isEmpty { text += "\n"; offset += 1 }
            let length = paragraph.text.utf16.count
            spans.append(Span(paragraphID: paragraph.id, range: NSRange(location: offset, length: length)))
            text += paragraph.text; offset += length
        }
        self.text = text; self.spans = spans
    }
    public func offset(for position: ReadingPosition) -> Int? {
        guard let span = spans.first(where: { $0.paragraphID == position.paragraphID }) else { return nil }
        return span.range.location + min(max(position.utf16Offset, 0), span.range.length)
    }
    public func position(at offset: Int) -> ReadingPosition? {
        guard let span = spans.last(where: { $0.range.location <= max(0, offset) }) ?? spans.first else { return nil }
        return ReadingPosition(paragraphID: span.paragraphID,
                               utf16Offset: min(max(offset - span.range.location, 0), span.range.length))
    }
    public static func pageIndex(containing offset: Int, pages: [NSRange]) -> Int {
        pages.firstIndex(where: { NSLocationInRange(offset, $0) }) ?? max(0, pages.count - 1)
    }
}
