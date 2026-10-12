import Foundation

public struct LocalBook: Codable, Sendable {
    public let book: Book
    public let paragraphs: [Paragraph]
    public init(book: Book, paragraphs: [Paragraph]) { self.book = book; self.paragraphs = paragraphs }

    public static func importing(text: String, title: String, id: String = UUID().uuidString) -> LocalBook {
        let normalized = text.contains("\r") ? text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n") : text
        var paragraphs: [Paragraph] = []
        normalized.enumerateSubstrings(in: normalized.startIndex..<normalized.endIndex, options: .byLines) { line, _, _, _ in
            let content = (line ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty { paragraphs.append(Paragraph(id: "\(id)-\(paragraphs.count)", text: content, chapterTitle: title)) }
        }
        return LocalBook(book: Book(id: id, title: title, author: "本地 TXT", source: .local), paragraphs: paragraphs)
    }
}

public enum SampleLibrary {
    public static let book = Book(id: "sample-reading", title: "在文字里停留", author: "项目原创示例", source: .sample)
    public static let paragraphs: [Paragraph] = [
        "窗边有一束光，恰好落在翻开的那一页上。阅读开始于一个很小的决定：把别的事情放下，让眼前的文字暂时占据全部注意力。",
        "有些句子值得慢下来。我们划下一条线，不只是为了记住一句话，也是在标记自己与它相遇的时刻。再次读到时，留下来的也许是另一种理解。",
        "阅读可以安静，也可以是一场对话。看看同一段文字下的想法，就像在书页边缘遇见另一个读者：你们从不同的生活走来，却在这里停留。",
        "好的阅读界面应该给文字足够的空间。纸张、夜色、滚动或翻页，都是通向同一件事的不同路径：舒服地读完下一段。",
        "把一本书带回桌面，不只是换一块屏幕。你可以在工作间隙读几页，保留一段思考，然后在下次打开时从停下的地方继续。",
        "这本短书是项目自己的示例内容。点击段落可体验评论面板；切换到微信读书后，连接你的账号即可查看真实电子书架与热门划线下的想法。"
    ].enumerated().map { Paragraph(id: "sample-\($0.offset)", text: $0.element, chapterTitle: "第一章 · 阅读的空间") }
    public static func comments(for paragraph: Paragraph) -> [ReaderComment] {
        let authors = ["林间", "小舟", "慢读者"]
        let texts = ["我喜欢在读完一段以后再看大家的理解。", "留下的划线，也记录着当时关心的事情。", "同一段文字，隔一段时间再读会有新的感受。"]
        let index = Int(paragraph.id.split(separator: "-").last ?? "0") ?? 0
        return [ReaderComment(id: "demo-\(paragraph.id)-1", author: authors[index % 3], text: texts[index % 3]),
                ReaderComment(id: "demo-\(paragraph.id)-2", author: authors[(index + 1) % 3], text: texts[(index + 1) % 3])]
    }
}
