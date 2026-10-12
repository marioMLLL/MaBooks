import AppKit
import WebKit
import SwiftUI
import ReaderCore

@MainActor
final class WebSession: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    let view: WKWebView
    @Published var error: String?
    @Published var busy = false
    @Published var canGoBack = false
    @Published var readerUnavailable = false
    @Published var needsLogin = false
    @Published var readerNotice: String?
    private var bookNavigation = UUID()
    private var expectedReaderURL: URL?
    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        view.navigationDelegate = self; view.uiDelegate = self
    }
    func navigate(_ url: URL) {
        guard let url = OfficialReaderURL.validated(url) else { return }
        error = nil; view.load(URLRequest(url: url))
    }
    func openBook(_ book: Book) {
        bookNavigation = UUID()
        readerUnavailable = false; needsLogin = false; readerNotice = nil
        expectedReaderURL = OfficialReaderURL.validated(book.readerURL)
        if let url = expectedReaderURL { navigate(url) }
        else {
            readerUnavailable = true
            readerNotice = "这条书架记录没有可用的官方阅读链接。可在书城查找对应书籍，再确认版本打开。"
            navigate(OfficialReaderURL.home)
        }
    }
    func clearBookContext() {
        bookNavigation = UUID(); expectedReaderURL = nil
        readerUnavailable = false; needsLogin = false; readerNotice = nil
    }
    func reload() { error = nil; view.reload() }
    func toggleFullScreen() { (view.window ?? NSApplication.shared.mainWindow)?.toggleFullScreen(nil) }
    func clearSession() async {
        view.stopLoading()
        let store = view.configuration.websiteDataStore
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        navigate(OfficialReaderURL.home)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { busy = true; error = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        busy = false; canGoBack = webView.canGoBack
        guard OfficialReaderURL.validated(webView.url) != nil else { return }
        let token = bookNavigation
        // Inspect only UI status flags on the official page, never extract book text or cookies.
        Task {
            let script = """
            (() => ({
              unavailable: (document.body?.innerText || '').includes('无法打开该书籍'),
              login: Array.from(document.querySelectorAll('button,a')).some(e => e.textContent.trim() === '登录')
            }))()
            """
            guard let flags = try? await webView.evaluateJavaScript(script) as? [String: Any],
                  token == bookNavigation else { return }
            needsLogin = flags["login"] as? Bool ?? false
            if expectedReaderURL != nil, flags["unavailable"] as? Bool == true {
                readerUnavailable = true
                readerNotice = "微信读书拒绝了这条书架阅读链接。可在书城查找对应版本；不要把这条记录当作已下载的正文。"
            }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError failure: Error) { failed(failure) }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError failure: Error) { failed(failure) }
    private func failed(_ failure: Error) {
        busy = false
        if (failure as NSError).code != NSURLErrorCancelled { error = "网页暂时无法打开，请重试或使用默认浏览器。" }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "https" || url.absoluteString == "about:blank" { decisionHandler(.allow) }
        else { decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if action.targetFrame == nil, let url = action.request.url, url.scheme == "https" { webView.load(URLRequest(url: url)) }
        return nil
    }
}

struct OfficialWebView: NSViewRepresentable {
    let session: WebSession
    func makeNSView(context: Context) -> WKWebView { session.view }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

struct WebReader: View {
    @ObservedObject var session: WebSession
    @ObservedObject var state: AppState
    let fullScreen: Bool
    @Environment(\.skinPalette) private var palette
    var body: some View {
        VStack(spacing: 0) {
            if !fullScreen {
            HStack {
                Button { session.view.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!session.canGoBack)
                Button { session.navigate(OfficialReaderURL.home) } label: { Label("首页", systemImage: "house") }
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }
                if session.busy { ProgressView().controlSize(.small) }
                Spacer()
                Text(state.selectedBook.source == .weread ? state.selectedBook.title : "微信读书").font(.caption).lineLimit(1)
                Button { session.toggleFullScreen() } label: { Label("全屏阅读", systemImage: "arrow.up.left.and.arrow.down.right") }
                    .help("隐藏书架和工具栏，占满屏幕阅读（⌃⌘F）")
                Button("默认浏览器打开") { NSWorkspace.shared.open(OfficialReaderURL.validated(session.view.url) ?? OfficialReaderURL.home) }
            }.padding(12)
            if let error = session.error { Text(error).foregroundStyle(.red).padding(8) }
            if state.selectedBook.source == .weread {
                VStack(alignment: .leading, spacing: 8) {
                    if let notice = session.readerNotice { Text(notice).font(.callout) }
                    else if session.needsLogin { Text("网页账号尚未登录。先在官网扫码登录，再点击“重新打开此书”；API Key 不代替网页登录。").font(.callout) }
                    HStack {
                        Button("网页登录") { session.navigate(OfficialReaderURL.home) }
                        Button("重新打开此书") { state.open(state.selectedBook) }
                        Button("查找电子书") { state.searchReadingCandidates(novels: false) }
                        Button("查找网文小说") { state.searchReadingCandidates(novels: true) }
                        Button("划线与想法") { state.showHighlights() }
                    }
                }.padding(12)
            }
            Divider()
            }
            OfficialWebView(session: session)
        }
        .overlay(alignment: .topTrailing) {
            if fullScreen {
                Button { session.toggleFullScreen() } label: { Label("退出全屏", systemImage: "arrow.down.right.and.arrow.up.left") }
                    .buttonStyle(.plain).padding(9)
                    .foregroundStyle(palette.ink).background(palette.paper.opacity(0.92), in: Capsule())
                    .help("退出全屏阅读（⌃⌘F）").padding(12)
            }
        }
    }
}
