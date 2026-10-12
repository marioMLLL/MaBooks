import SwiftUI
import ReaderCore

struct ContentView: View {
    @ObservedObject var state: AppState
    @AppStorage("reader.theme") private var theme: ReaderTheme = .sepia
    @AppStorage("reader.layout") private var layout: ReaderLayout = .scroll
    @AppStorage("reader.fontSize") private var fontSize = 20.0
    @Environment(\.colorScheme) private var systemScheme
    @State private var showsAppearance = false
    private var dark: Bool { theme == .dark || (theme == .system && systemScheme == .dark) }
    private var paper: Color { theme == .sepia ? Color(red: 0.97, green: 0.95, blue: 0.90) : dark ? Color(red: 0.10, green: 0.12, blue: 0.13) : Color(nsColor: .textBackgroundColor) }

    var body: some View {
        HSplitView {
            if layout != .focus || state.showsWeb { sidebar.frame(minWidth: 200, idealWidth: 235, maxWidth: 300) }
            VStack(spacing: 0) {
                if state.showsWeb { WebReader(session: state.web) }
                else { reader }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            if state.showsComments && !state.showsWeb {
                CommentPanel(state: state).frame(minWidth: 250, idealWidth: 300, maxWidth: 380)
            }
        }
        .preferredColorScheme(theme == .system ? nil : dark ? .dark : .light)
        .toolbar {
            ToolbarItemGroup {
                if layout == .focus && !state.showsWeb {
                    Button("退出专注") { layout = .scroll }
                }
                if !state.showsWeb {
                    Button { showsAppearance.toggle() } label: { Label("阅读设置", systemImage: "textformat.size") }
                        .popover(isPresented: $showsAppearance) { appearance }
                    Button { state.showsComments.toggle() } label: { Label("段落想法", systemImage: "text.bubble") }
                }
                Button { state.showsSettings = true } label: { Label("账号", systemImage: "person.crop.circle") }
            }
        }
        .sheet(isPresented: $state.showsSettings) { AccountSettings(state: state) }
        .alert("提示", isPresented: Binding(get: { state.notice != nil }, set: { if !$0 { state.notice = nil } })) {
            Button("好") { state.notice = nil }
        } message: { Text(state.notice ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(.teal)
                VStack(alignment: .leading) {
                    Text("阅窗").font(.title2.bold())
                    Text("一个安静的阅读空间").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20)
            List {
                Section("本地书库") {
                    ForEach(state.books) { book in bookRow(book) }
                    Button { state.importText() } label: { Label("导入 TXT", systemImage: "plus.circle") }
                }
                Section {
                    if state.loadingShelf { ProgressView("正在同步…").controlSize(.small) }
                    if let error = state.shelfError {
                        Text(error).font(.caption).foregroundStyle(.red)
                        Button("重新同步") { Task { await state.refreshShelf() } }
                    }
                    if !state.hasKey {
                        Button("连接账号，读取电子书架") { state.showsSettings = true }.font(.callout)
                    } else if state.shelf.isEmpty && !state.loadingShelf && state.shelfError == nil {
                        Text("点击同步读取电子书架").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(state.shelf) { book in bookRow(book) }
                } header: {
                    HStack {
                        Text("微信读书 · 电子书")
                        Spacer()
                        Button { Task { await state.refreshShelf() } } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).disabled(state.loadingShelf).help("同步电子书架")
                    }
                }
            }.listStyle(.sidebar)
            Divider()
            Button { state.showOfficialReader() } label: {
                Label("微信读书网页版", systemImage: "globe").frame(maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain).padding(18)
        }.background(Color(nsColor: .windowBackgroundColor))
    }

    private func bookRow(_ book: Book) -> some View {
        Button { state.open(book) } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: book.source == .weread ? "book.fill" : "doc.text").foregroundStyle(.teal).padding(.top, 2)
                VStack(alignment: .leading, spacing: 5) {
                    Text(book.title).lineLimit(2).font(.callout.weight(.medium))
                    Text(book.author).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if book.source == .sample { Text("示例内容").font(.caption2).foregroundStyle(.teal) }
                }
                Spacer(minLength: 0)
            }.padding(.vertical, 7).padding(.horizontal, 4)
                .background(state.selectedBook == book && !state.showsWeb ? Color.teal.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private var reader: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(state.selectedBook.title).font(.headline)
                    Text(state.selectedBook.source == .weread ? "热门划线 · 最多 20 条，点击原文查看真实想法" : state.selectedBook.source == .sample ? "原创示例 · 点击段落体验想法" : "本地 TXT · 点击段落保存位置")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if state.selectedBook.source == .weread {
                    Button("阅读全文 ↗") { state.showOfficialReader(for: state.selectedBook) }
                }
            }.padding(20)
            Divider()
            if state.loadingBook {
                Spacer(); ProgressView("读取热门划线…"); Spacer()
            } else if let error = state.bookError {
                Spacer()
                ContentUnavailableView {
                    Label("暂时无法读取", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: { Button("重试") { state.open(state.selectedBook) } }
                Spacer()
            } else if state.paragraphs.isEmpty {
                ContentUnavailableView("暂无热门划线", systemImage: "text.quote", description: Text("可以通过微信读书网页版继续阅读。"))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            HStack {
                                Text(state.selectedBook.source == .weread ? "划线与想法" : "\(state.selectedBook.title)").font(.system(size: 30, weight: .medium, design: .serif))
                                Spacer()
                            }.padding(.bottom, 12)
                            ForEach(visibleParagraphs) { paragraph in paragraphView(paragraph).id(paragraph.id) }
                        }.padding(.horizontal, 42).padding(.vertical, 40).frame(maxWidth: 800)
                            .frame(maxWidth: .infinity)
                    }
                    .task(id: "\(state.selectedBook.id)-\(state.paragraphs.count)-\(layout.rawValue)") {
                        if layout != .paged, let id = state.selectedParagraph?.id { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onChange(of: state.page) { _, _ in
                        if layout == .paged, let first = visibleParagraphs.first { proxy.scrollTo(first.id, anchor: .top) }
                    }
                }
            }
            Divider()
            HStack {
                Text(layout.title).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if layout == .paged {
                    Button { state.navigatePage(-1) } label: { Image(systemName: "chevron.left") }.disabled(state.page == 0)
                    Text("\(state.page + 1) / \(state.pageCount)").font(.caption.monospacedDigit()).frame(minWidth: 60)
                    Button { state.navigatePage(1) } label: { Image(systemName: "chevron.right") }.disabled(state.page + 1 >= state.pageCount)
                } else { Text("\(state.paragraphs.count) 段").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }.background(paper)
    }

    private var visibleParagraphs: [Paragraph] {
        if layout == .paged {
            return Array(state.paragraphs.dropFirst(state.page * 4).prefix(4))
        }
        return state.paragraphs
    }

    private func paragraphView(_ paragraph: Paragraph) -> some View {
        let selected = state.selectedParagraph?.id == paragraph.id
        return VStack(alignment: .leading, spacing: 12) {
            if state.selectedBook.source == .weread {
                Text(paragraph.chapterTitle).font(.caption).foregroundStyle(.secondary)
            }
            Text(paragraph.text).font(.system(size: fontSize, design: .serif)).lineSpacing(fontSize * 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if paragraph.highlightCount > 0 {
                    Label("\(paragraph.highlightCount) 人划线", systemImage: "pencil.line").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { state.select(paragraph) } label: {
                    Label(state.selectedBook.source == .local ? "记住位置" : "查看想法", systemImage: state.selectedBook.source == .local ? "bookmark" : "text.bubble")
                        .font(.caption)
                }.buttonStyle(.plain).foregroundStyle(.teal)
            }
        }.padding(16)
            .background(selected ? Color.teal.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .leading) { if selected { RoundedRectangle(cornerRadius: 2).fill(.teal).frame(width: 3) } }
            .contentShape(Rectangle())
            .onTapGesture { state.select(paragraph) }
            .accessibilityElement(children: .contain)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("阅读设置").font(.headline)
            Picker("主题", selection: $theme) { ForEach(ReaderTheme.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Picker("显示方式", selection: $layout) { ForEach(ReaderLayout.allCases, id: \.self) { Text($0.title).tag($0) } }
            HStack { Text("字号"); Slider(value: $fontSize, in: 16...32, step: 1); Text("\(Int(fontSize))").monospacedDigit() }
            Text("适用于本地书和划线。分组翻页每页四段；网页全文请使用网页内的设置。").font(.caption).foregroundStyle(.secondary)
        }.padding(24).frame(width: 390)
    }
}
