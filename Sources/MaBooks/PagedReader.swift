import SwiftUI
import AppKit
import ReaderCore
import ReaderLayoutKit

struct PagedReader: View {
    @ObservedObject var state: AppState
    let fontSize: Double
    let color: Color
    @State private var pages: PageLayout?
    @State private var ready = false

    var body: some View {
        GeometryReader { geometry in
            let size = CGSize(width: min(766, max(120, geometry.size.width - 64)),
                              height: max(120, geometry.size.height - 52))
            let key = LayoutKey(bookID: state.selectedBook.id, size: size, fontSize: fontSize,
                                color: NSColor(color).description, paragraphCount: state.paragraphs.count)
            ZStack {
                if let pages, ready {
                    PageCanvas(pages: pages, page: state.page, turn: state.navigatePage) { offset in
                        state.selectReadingOffset(offset, reveal: state.selectedBook.source != .local)
                    }
                    .frame(width: size.width, height: size.height)
                    .help("点击书页左侧上一页、右侧下一页；← / →、Page Up / Page Down 或空格翻页")
                } else { ProgressView("正在分页…") }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task(id: key) {
                ready = false
                let document = state.readingDocument
                let ink = NSColor(color)
                let task = Task.detached(priority: .userInitiated) {
                    PageLayout(document: document, size: size, fontSize: fontSize, color: ink)
                }
                let result = await withTaskCancellationHandler {
                    await task.value
                } onCancel: {
                    task.cancel()
                }
                guard !Task.isCancelled, state.selectedBook.id == key.bookID else { return }
                pages = result
                state.setPageRanges(result.ranges, bookID: key.bookID)
                ready = true
            }
        }
    }
}

private struct LayoutKey: Equatable {
    let bookID: String
    let size: CGSize
    let fontSize: Double
    let color: String
    let paragraphCount: Int
}

private struct PageCanvas: NSViewRepresentable {
    let pages: PageLayout
    let page: Int
    let turn: (Int) -> Void
    let select: (Int) -> Void
    func makeNSView(context: Context) -> PageCanvasView { PageCanvasView() }
    func updateNSView(_ view: PageCanvasView, context: Context) {
        view.pages = pages; view.page = page; view.turn = turn; view.select = select
        view.setAccessibilityLabel("第 \(page + 1) 页，共 \(pages.ranges.count) 页")
        if pages.ranges.indices.contains(page) {
            view.setAccessibilityValue((pages.document.text as NSString).substring(with: pages.ranges[page]))
        }
        view.needsDisplay = true
    }
}

private final class PageCanvasView: NSView {
    var pages: PageLayout?
    var page = 0
    var turn: ((Int) -> Void)?
    var select: ((Int) -> Void)?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.textArea)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        pages?.draw(page: page, in: context)
    }
    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        if point.x < bounds.width * 0.2 { turn?(-1) }
        else if point.x > bounds.width * 0.8 { turn?(1) }
        else if let offset = pages?.textOffset(page: page, at: point) { select?(offset) }
    }
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 123, 116: turn?(-1)
        case 124, 121: turn?(1)
        case 49: turn?(event.modifierFlags.contains(.shift) ? -1 : 1)
        default: super.keyDown(with: event)
        }
    }
}
