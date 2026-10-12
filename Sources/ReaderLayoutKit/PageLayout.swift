import AppKit
import CoreText
import ReaderCore

/// Built on a worker, then used only for drawing on the main thread.
public final class PageLayout: @unchecked Sendable {
    public let document: ReadingDocument
    public let size: CGSize
    public let ranges: [NSRange]
    private let setter: CTFramesetter

    public init(document: ReadingDocument, size: CGSize, fontSize: CGFloat, color: NSColor) {
        self.document = document
        self.size = CGSize(width: max(120, size.width), height: max(120, size.height))
        let descriptor = NSFont.systemFont(ofSize: fontSize).fontDescriptor.withDesign(.serif)
            ?? NSFont.systemFont(ofSize: fontSize).fontDescriptor
        let font = NSFont(descriptor: descriptor, size: fontSize)!
        let style = NSMutableParagraphStyle()
        style.lineSpacing = fontSize * 0.45
        style.paragraphSpacing = fontSize * 0.6
        let text = NSAttributedString(string: document.text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ])
        let setter = CTFramesetterCreateWithAttributedString(text)
        let path = CGPath(rect: CGRect(origin: .zero, size: self.size), transform: nil)
        var ranges: [NSRange] = []
        var offset = 0
        while offset < text.length {
            if Task.isCancelled { break }
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: offset, length: 0), path, nil)
            let visible = CTFrameGetVisibleStringRange(frame)
            precondition(visible.length > 0, "A page must fit at least one text line")
            ranges.append(NSRange(location: visible.location, length: visible.length))
            offset = visible.location + visible.length
        }
        self.setter = setter; self.ranges = ranges
    }

    private func frame(page: Int) -> CTFrame {
        let range = ranges[page]
        return CTFramesetterCreateFrame(setter, CFRange(location: range.location, length: range.length),
                                       CGPath(rect: CGRect(origin: .zero, size: size), transform: nil), nil)
    }

    public func draw(page: Int, in context: CGContext) {
        guard ranges.indices.contains(page) else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: 1, y: -1)
        CTFrameDraw(frame(page: page), context)
        context.restoreGState()
    }

    public func textOffset(page: Int, at point: CGPoint) -> Int? {
        guard ranges.indices.contains(page) else { return nil }
        let frame = frame(page: page)
        let lines = CTFrameGetLines(frame) as! [CTLine]
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        let y = size.height - point.y
        for (index, line) in lines.enumerated() {
            var ascent: CGFloat = 0, descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            let origin = origins[index]
            if y >= origin.y - descent && y <= origin.y + ascent {
                let offset = CTLineGetStringIndexForPosition(line, CGPoint(x: point.x - origin.x, y: 0))
                if offset != kCFNotFound { return offset }
            }
        }
        return nil
    }
}
