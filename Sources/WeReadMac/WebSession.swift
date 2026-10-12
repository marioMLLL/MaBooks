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
    func reload() { error = nil; view.reload() }
    func clearSession() async {
        view.stopLoading()
        let store = view.configuration.websiteDataStore
        await store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        navigate(OfficialReaderURL.home)
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { busy = true; error = nil }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { busy = false; canGoBack = webView.canGoBack }
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
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button { session.view.goBack() } label: { Image(systemName: "chevron.left") }.disabled(!session.canGoBack)
                Button { session.navigate(OfficialReaderURL.home) } label: { Label("首页", systemImage: "house") }
                Button { session.reload() } label: { Image(systemName: "arrow.clockwise") }
                if session.busy { ProgressView().controlSize(.small) }
                Spacer()
                Text("微信读书网页版 · 使用网页自身的阅读设置").font(.caption).foregroundStyle(.secondary)
                Button("默认浏览器打开") { NSWorkspace.shared.open(OfficialReaderURL.validated(session.view.url) ?? OfficialReaderURL.home) }
            }.padding(12)
            if let error = session.error { Text(error).foregroundStyle(.red).padding(8) }
            Divider()
            OfficialWebView(session: session)
        }
    }
}
