import SwiftUI
import ReaderCore

struct ContentView: View {
    @ObservedObject var state: AppState
    @AppStorage("reader.skin") private var skin: ReaderSkin = .sakura
    @AppStorage("reader.decorations") private var decorated = true
    @AppStorage("reader.theme") private var theme: ReaderTheme = .sepia
    @AppStorage("reader.layout") private var layout: ReaderLayout = .paged
    @AppStorage("reader.paginationVersion") private var paginationVersion = 0
    @AppStorage("reader.fontSize") private var fontSize = 20.0
    @AppStorage("reader.sidebarVisible") private var sidebarVisible = true
    @Environment(\.colorScheme) private var systemScheme
    @State private var showsAppearance = false
    @State private var showsSkins = false
    @State private var sidebarTab: SidebarTab = .shelf
    @State private var jumpTarget: String?
    @State private var windowIsFullScreen = false
    private var palette: SkinPalette { SkinPalette(skin: skin, theme: theme, systemDark: systemScheme == .dark) }
    private var usesPagination: Bool { state.selectedBook.source != .weread && layout != .scroll }
    private var webFullScreen: Bool { state.showsWeb && windowIsFullScreen }
    private var showsSidebar: Bool { sidebarVisible && (layout != .focus || state.showsWeb) }

    var body: some View {
        ZStack {
            SkinBackdrop(palette: palette, decorated: decorated)
            VStack(spacing: 12) {
                HSplitView {
                    if showsSidebar { sidebar.frame(minWidth: 210, idealWidth: 235, maxWidth: 270) }
                    VStack(spacing: 0) {
                        if state.showsWeb {
                            HStack {
                                if !showsSidebar { sidebarToggle }
                                Text("MaBooks · 微信读书").font(.headline)
                                Spacer()
                                SkinIconButton(title: "切换皮肤", symbol: "paintpalette") { showsSkins = true }
                                SkinIconButton(title: "账号设置", symbol: "person.crop.circle") { state.showsSettings = true }
                            }.padding(16).background(palette.paper.opacity(0.94))
                            WebReader(session: state.web, state: state, fullScreen: webFullScreen)
                        } else { reader }
                    }.frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                    if state.showsComments && !state.showsWeb {
                        CommentPanel(state: state).frame(minWidth: 260, idealWidth: 300, maxWidth: 350)
                    }
                }
                .background(palette.paper.opacity(0.20))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(palette.dark ? 0.07 : 0.45)))
                .shadow(color: palette.ink.opacity(0.09), radius: 18, y: 8)
                HStack {
                    Text("MaBooks").font(.system(size: 10, weight: .medium)).tracking(3)
                    Spacer()
                    Text(skin.subtitle).font(.system(size: 10, design: .serif)).tracking(2)
                }.foregroundStyle(palette.ink.opacity(0.7)).padding(.horizontal, 14)
            }.padding(.horizontal, 20).padding(.top, 32).padding(.bottom, decorated ? 48 : 16)
        }
        .foregroundStyle(palette.ink).environment(\.skinPalette, palette).tint(palette.accent)
        .preferredColorScheme(theme == .system ? nil : palette.dark ? .dark : .light)
        .focusedSceneValue(\.toggleReaderSidebar, toggleSidebar)
        .onAppear {
            if paginationVersion == 0 { layout = .paged; paginationVersion = 1 }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { notification in
            if let window = notification.object as? NSWindow, window == state.web.view.window || window.title == "MaBooks" {
                windowIsFullScreen = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { notification in
            if let window = notification.object as? NSWindow, window == state.web.view.window || window.title == "MaBooks" {
                windowIsFullScreen = false
            }
        }
        .sheet(isPresented: $showsSkins) {
            SkinPicker(skin: $skin, decorated: $decorated, theme: $theme)
                .environment(\.skinPalette, palette)
                .preferredColorScheme(theme == .system ? nil : palette.dark ? .dark : .light)
        }
        .sheet(isPresented: $state.showsSettings) { AccountSettings(state: state).environment(\.skinPalette, palette) }
        .sheet(isPresented: $state.showsDeletedBooks) { deletedBooksSheet }
        .sheet(isPresented: $state.showsBookSearch) { readingCandidatesSheet }
        .alert("提示", isPresented: Binding(get: { state.notice != nil }, set: { if !$0 { state.notice = nil } })) {
            Button("好") { state.notice = nil }
        } message: { Text(state.notice ?? "") }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("MaBooks").font(.system(size: 29, weight: .medium, design: .serif))
                Image(systemName: skin.symbol).font(.system(size: 19)).foregroundStyle(palette.accent.opacity(0.8))
                Spacer(minLength: 0)
                sidebarToggle
            }.padding(.top, 27).padding(.horizontal, 22)
            Text("阅读让心靠近一点").font(.system(size: 10)).tracking(4)
                .foregroundStyle(palette.muted).padding(.horizontal, 24).padding(.top, 7).padding(.bottom, 24)
            VStack(spacing: 5) {
                navigationRow("书架", symbol: "books.vertical", active: sidebarTab == .shelf) { sidebarTab = .shelf }
                navigationRow("段落导航", symbol: "list.bullet", active: sidebarTab == .paragraphs) { sidebarTab = .paragraphs; state.showsWeb = false }
                navigationRow("段落想法", symbol: "text.bubble", active: state.showsComments && !state.showsWeb) { state.showsComments.toggle(); state.showsWeb = false }
            }.padding(.horizontal, 12)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    if sidebarTab == .shelf {
                        HStack {
                            Text("我的书架").font(.caption).foregroundStyle(palette.muted)
                            Spacer()
                            SkinIconButton(title: "最近删除", symbol: "trash") { state.showsDeletedBooks = true }
                            SkinIconButton(title: "导入 TXT（最多 100 MB）", symbol: "plus") { state.importText() }.disabled(state.libraryBusy)
                        }.padding(.horizontal, 10)
                        if state.libraryBusy { ProgressView("正在处理书库…").controlSize(.small).padding(.horizontal, 10) }
                        VStack(spacing: 6) { ForEach(state.books) { book in bookRow(book) } }
                        HStack {
                            Text("微信读书 · 书架与划线").font(.caption).foregroundStyle(palette.muted)
                            Spacer()
                            SkinIconButton(title: "同步电子书架", symbol: "arrow.clockwise") { Task { await state.refreshShelf() } }.disabled(state.loadingShelf)
                        }.padding(.horizontal, 10)
                        if state.loadingShelf { ProgressView("正在同步…").controlSize(.small).padding(.horizontal, 10) }
                        if let error = state.shelfError {
                            Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal, 10)
                            Button("重新同步") { Task { await state.refreshShelf() } }.padding(.horizontal, 10)
                        }
                        if !state.hasKey {
                            Button { state.showsSettings = true } label: {
                                Label("连接我的微信读书", systemImage: "link").font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    .background(palette.selection.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain).foregroundStyle(palette.accent)
                        } else if state.shelf.isEmpty && !state.loadingShelf && state.shelfError == nil {
                            Text("同步后，书籍会出现在这里").font(.caption).foregroundStyle(palette.muted).padding(10)
                        }
                        VStack(spacing: 6) { ForEach(state.shelf) { book in bookRow(book) } }
                    } else {
                        Text(state.selectedBook.source == .weread ? "热门划线导航" : "当前书籍 · 段落")
                            .font(.caption).foregroundStyle(palette.muted).padding(.horizontal, 10)
                        ForEach(Array(state.paragraphs.enumerated()), id: \.element.id) { index, paragraph in
                            Button { state.select(paragraph); jumpTarget = paragraph.id } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(state.selectedBook.source == .weread ? paragraph.chapterTitle : "第 \(index + 1) 段").font(.caption).foregroundStyle(palette.accent)
                                    Text(paragraph.text).font(.callout).lineLimit(2).multilineTextAlignment(.leading)
                                }.frame(maxWidth: .infinity, alignment: .leading).padding(12)
                                    .background(state.selectedParagraph?.id == paragraph.id ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 10))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(.horizontal, 12).padding(.top, 16).padding(.bottom, 24)
            }
            Rectangle().fill(palette.border).frame(height: 1).padding(.horizontal, 20)
            HStack(spacing: 2) {
                Button { state.showOfficialReader() } label: { Label("微信读书", systemImage: "globe").font(.caption) }.buttonStyle(.plain)
                Spacer()
                SkinIconButton(title: "切换皮肤", symbol: "paintpalette") { showsSkins = true }
                SkinIconButton(title: "账号设置", symbol: "person.crop.circle") { state.showsSettings = true }
            }.padding(.horizontal, 20).padding(.vertical, 12)
        }.background(palette.sidebar.opacity(decorated ? 0.91 : 1))
    }

    private func navigationRow(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 17)).frame(width: 22)
                Text(title).font(.system(size: 14)); Spacer()
            }.foregroundStyle(active ? palette.accent : palette.ink).padding(.horizontal, 15).padding(.vertical, 11)
                .background(active ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain)
    }

    private func bookRow(_ book: Book) -> some View {
        Button { state.open(book) } label: {
            HStack(spacing: 12) {
                BookCover(book: book)
                VStack(alignment: .leading, spacing: 7) {
                    Text(book.title).lineLimit(2).font(.system(size: 14, weight: .medium, design: .serif))
                    Text(book.source == .sample ? "原创示例" : book.author).font(.system(size: 11)).foregroundStyle(palette.muted).lineLimit(1)
                }
                Spacer(minLength: 0)
            }.padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(state.selectedBook == book && !state.showsWeb ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
        .contextMenu {
            if book.source == .local {
                Button(role: .destructive) { state.deleteLocalBook(book) } label: { Label("移到最近删除", systemImage: "trash") }
                    .disabled(state.libraryBusy)
            }
        }
    }

    private var reader: some View {
        VStack(spacing: 0) {
            readerHeader
            Rectangle().fill(palette.border).frame(height: 1).padding(.horizontal, 24)
            if state.loadingBook { Spacer(); ProgressView("读取热门划线…"); Spacer() }
            else if let error = state.bookError {
                ContentUnavailableView { Label("暂时无法读取", systemImage: "wifi.exclamationmark") }
                    description: { Text(error) } actions: { Button("重试") { state.open(state.selectedBook) } }
            } else if state.paragraphs.isEmpty {
                ContentUnavailableView {
                    Label("暂无热门划线", systemImage: "text.quote")
                } description: {
                    Text("已同步书架，但微信读书暂未返回热门划线。\n官方接口不提供整本正文下载，本地未保存该书全文。")
                } actions: {
                    Button("官方网页阅读", systemImage: "globe") {
                        state.showOfficialReader(for: state.selectedBook)
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else if usesPagination {
                PagedReader(state: state, fontSize: fontSize, color: palette.ink)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 22) {
                            ForEach(state.paragraphs) { paragraph in paragraphView(paragraph).id(paragraph.id) }
                        }.padding(.horizontal, 32).padding(.vertical, 26).frame(maxWidth: 830).frame(maxWidth: .infinity)
                    }
                    .task(id: "\(state.selectedBook.id)-\(state.paragraphs.count)-\(layout.rawValue)") {
                        if let id = state.selectedParagraph?.id { proxy.scrollTo(id, anchor: .center) }
                    }
                    .onChange(of: jumpTarget) { _, id in
                        if let id { withAnimation(.easeInOut(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) } }
                    }
                }
            }
            readerFooter
        }.background(palette.paper.opacity(decorated ? 0.94 : 1))
    }

    private var readerHeader: some View {
        HStack(spacing: 14) {
            if !showsSidebar { sidebarToggle }
            BookCover(book: state.selectedBook, width: 42, height: 58)
            VStack(alignment: .leading, spacing: 7) {
                Text(state.selectedBook.title).font(.system(size: 20, weight: .medium, design: .serif)).lineLimit(1)
                Text(state.selectedBook.source == .weread ? "热门划线摘录 · 非本地全文" : state.selectedBook.source == .sample ? "第一章 · 阅读的空间 · 原创示例" : "本地 TXT · 阅读位置自动保存")
                    .font(.system(size: 11)).foregroundStyle(palette.muted).lineLimit(1)
            }
            Spacer(minLength: 4)
            if state.selectedBook.source == .local {
                SkinIconButton(title: "删除本地书（可在最近删除恢复）", symbol: "trash") { state.deleteLocalBook(state.selectedBook) }
                    .disabled(state.libraryBusy)
            }
            SkinIconButton(title: "段落想法", symbol: "text.bubble", selected: state.showsComments) { state.showsComments.toggle() }
            SkinIconButton(title: "阅读设置", symbol: "textformat.size") { showsAppearance.toggle() }.popover(isPresented: $showsAppearance) { appearance }
            SkinIconButton(title: "切换皮肤", symbol: "paintpalette") { showsSkins = true }
            if state.selectedBook.source == .weread { SkinIconButton(title: "官方网页阅读", symbol: "globe") { state.showOfficialReader(for: state.selectedBook) } }
        }.padding(.horizontal, 24).padding(.vertical, 22)
    }

    private var sidebarToggle: some View {
        SkinIconButton(title: showsSidebar ? "收起侧边栏（⌘⌥S）" : "展开侧边栏（⌘⌥S）", symbol: "sidebar.left", selected: showsSidebar) {
            toggleSidebar()
        }
    }

    private func toggleSidebar() {
        if !showsSidebar {
            if layout == .focus && !state.showsWeb { layout = .paged }
            sidebarVisible = true
        } else {
            sidebarVisible = false
        }
    }

    private var readerFooter: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.border)
                    Capsule().fill(palette.accent.opacity(0.85)).frame(width: max(8, geometry.size.width * readingProgress))
                }
            }.frame(height: 3)
            HStack {
                Text(state.selectedBook.source == .weread ? "热门划线摘录" : layout.title).font(.system(size: 11)).foregroundStyle(palette.muted); Spacer()
                if usesPagination {
                    SkinIconButton(title: "上一页", symbol: "chevron.left") { state.navigatePage(-1) }.disabled(state.page == 0)
                    Text("\(state.page + 1) / \(state.pageCount)").font(.caption.monospacedDigit()).frame(minWidth: 45)
                    SkinIconButton(title: "下一页", symbol: "chevron.right") { state.navigatePage(1) }.disabled(state.page + 1 >= state.pageCount)
                } else {
                    Text("\(state.paragraphs.isEmpty ? 0 : selectedIndex + 1) / \(state.paragraphs.count) 段").font(.system(size: 11).monospacedDigit()).foregroundStyle(palette.muted)
                }
            }
        }.padding(.horizontal, 32).padding(.top, 10).padding(.bottom, 16)
    }

    private var selectedIndex: Int { state.paragraphs.firstIndex { $0.id == state.selectedParagraph?.id } ?? 0 }
    private var readingProgress: Double {
        guard !state.paragraphs.isEmpty else { return 0 }
        if usesPagination { return Double(state.page + 1) / Double(state.pageCount) }
        return Double(selectedIndex + 1) / Double(state.paragraphs.count)
    }

    private func paragraphView(_ paragraph: Paragraph) -> some View {
        let selected = state.selectedParagraph?.id == paragraph.id
        return VStack(alignment: .leading, spacing: 10) {
            if state.selectedBook.source == .weread { Text(paragraph.chapterTitle).font(.caption).foregroundStyle(palette.muted) }
            Text(paragraph.text).font(.system(size: fontSize, design: .serif)).lineSpacing(fontSize * 0.6).frame(maxWidth: .infinity, alignment: .leading)
            HStack {
                if paragraph.highlightCount > 0 { Label("\(paragraph.highlightCount) 人划线", systemImage: "pencil.line").font(.caption).foregroundStyle(palette.muted) }
                Spacer()
                Button { state.select(paragraph) } label: {
                    Image(systemName: state.selectedBook.source == .local ? "bookmark" : "text.bubble").font(.system(size: 12))
                        .foregroundStyle(selected ? palette.accent : palette.muted.opacity(0.55))
                }.buttonStyle(.plain).help(state.selectedBook.source == .local ? "记住位置" : "查看段落想法")
                    .accessibilityLabel(state.selectedBook.source == .local ? "记住位置" : "查看段落想法")
            }
        }.padding(.horizontal, 18).padding(.vertical, 14)
            .background(selected ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if selected { Circle().fill(palette.accent.opacity(0.6)).frame(width: 8, height: 8).offset(x: -3, y: 12) }
            }
            .contentShape(Rectangle()).onTapGesture { state.select(paragraph) }.accessibilityElement(children: .contain)
    }

    private var appearance: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("阅读设置").font(.system(size: 21, weight: .medium, design: .serif))
            Picker("阅读主题", selection: $theme) { ForEach(ReaderTheme.allCases, id: \.self) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
            Picker("显示方式", selection: $layout) { ForEach(ReaderLayout.allCases, id: \.self) { Text($0.title).tag($0) } }
            HStack { Text("字号"); Slider(value: $fontSize, in: 16...32, step: 1); Text("\(Int(fontSize))").monospacedDigit() }
            Button { showsAppearance = false; showsSkins = true } label: { Label("切换皮肤 · \(skin.title)", systemImage: "paintpalette") }.buttonStyle(.plain).foregroundStyle(palette.accent)
            Text("本地书按窗口与字号自动分页。点击书页左右边缘、← / → 或空格翻页；微信读书划线为摘录列表，官方网页使用网页内设置。").font(.caption).foregroundStyle(palette.muted)
        }.padding(24).frame(width: 380).foregroundStyle(palette.ink).background(palette.paper)
    }

    private var deletedBooksSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("最近删除").font(.title2)
                Spacer()
                Button("完成") { state.showsDeletedBooks = false }
            }
            Text("删除的本地书可在这里恢复，阅读位置也会保留。导入前的原始 TXT 文件不会被删除。").font(.callout).foregroundStyle(palette.muted)
            if state.deletedBooks.isEmpty {
                ContentUnavailableView("这里还没有书", systemImage: "trash", description: Text("书籍删除后会出现在这里。"))
            } else {
                List(state.deletedBooks, id: \.book.id) { local in
                    HStack {
                        Text(local.book.title)
                        Spacer()
                        Button("恢复") { state.restoreLocalBook(local.book) }.disabled(state.libraryBusy)
                    }
                    .listRowBackground(palette.paper)
                }
                .scrollContentBackground(.hidden)
            }
            if state.libraryBusy { ProgressView("正在保存…") }
        }
        .padding(24).frame(width: 520, height: 400)
        .foregroundStyle(palette.ink).background(palette.paper)
        .environment(\.skinPalette, palette)
    }

    private var readingCandidatesSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("在书城查找 · \(state.selectedBook.title)").font(.title2).lineLimit(1)
                Spacer()
                Button("关闭") { state.showsBookSearch = false }
            }
            Text("请核对书名、作者和版本。同名书的正文、划线和阅读位置可能不同；选择后打开该候选的官方阅读链接。").font(.callout).foregroundStyle(palette.muted)
            if state.searchingBooks { ProgressView("正在查询官方书城…") }
            else if let error = state.searchError { Text(error).foregroundStyle(.red) }
            else if state.readingCandidates.isEmpty { Text("这个分类没有返回候选。可关闭后切换“电子书”或“网文小说”再查找。") }
            else {
                List(state.readingCandidates) { book in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(book.title)
                            Text(book.author).font(.caption).foregroundStyle(palette.muted)
                            if let publisher = book.publisher { Text(publisher).font(.caption).foregroundStyle(palette.muted) }
                        }
                        Spacer()
                        Button("打开此版本") {
                            state.showsBookSearch = false
                            state.open(book)
                        }.disabled(book.readerURL == nil)
                    }.listRowBackground(palette.paper)
                }.scrollContentBackground(.hidden)
            }
        }.padding(24).frame(width: 650, height: 440)
            .foregroundStyle(palette.ink).background(palette.paper).environment(\.skinPalette, palette)
    }
}

private enum SidebarTab { case shelf, paragraphs }

private struct ToggleReaderSidebarKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var toggleReaderSidebar: (() -> Void)? {
        get { self[ToggleReaderSidebarKey.self] }
        set { self[ToggleReaderSidebarKey.self] = newValue }
    }
}
