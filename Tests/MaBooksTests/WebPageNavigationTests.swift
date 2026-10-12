import AppKit
import WebKit
import Testing
@testable import MaBooks

@Suite(.serialized) @MainActor
struct WebPageNavigationTests {
    private func fixture(url: String) async throws -> WKWebView {
        _ = NSApplication.shared
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.userContentController.addUserScript(WKUserScript(source: WebPageNavigation.script,
            injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 1000, height: 700), configuration: configuration)
        view.loadHTMLString("""
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <style>body{margin:0}main{margin:40px;width:800px;height:500px;position:relative}footer{position:absolute;bottom:0}</style>
        <main id="card"><p id="text">原创合成阅读文字</p><input id="input"><a href="#">链接</a>
        <footer><button id="previous" onclick="window.previousCount++">上一页</button>
        <button id="next" onclick="window.nextCount++">下一页</button></footer></main>
        <script>
        window.previousCount=0;window.nextCount=0;
        window.tap=(fraction, target=document.getElementById('card'), drag=0, detail=1)=>{
          const rect=document.getElementById('card').getBoundingClientRect();
          const x=rect.left+rect.width*fraction,y=rect.top+150;
          target.dispatchEvent(new PointerEvent('pointerdown',{bubbles:true,clientX:x-drag,clientY:y,button:0}));
          target.dispatchEvent(new MouseEvent('click',{bubbles:true,cancelable:true,clientX:x,clientY:y,button:0,detail}));
        };
        </script>
        """, baseURL: URL(string: url))
        let deadline = Date().addingTimeInterval(8)
        while view.isLoading && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        try #require(!view.isLoading)
        return view
    }

    @Test func readerEdgesUseOfficialButtonsAndProtectInteractions() async throws {
        let view = try await fixture(url: "https://weread.qq.com/web/reader/synthetic-test")
        _ = try await view.evaluateJavaScript("tap(.1)")
        try await Task.sleep(for: .seconds(NSEvent.doubleClickInterval + 0.1))
        _ = try await view.evaluateJavaScript("tap(.9)")
        try await Task.sleep(for: .seconds(NSEvent.doubleClickInterval + 0.1))
        _ = try await view.evaluateJavaScript("""
        (()=>{
          tap(.5);
          tap(.1,document.getElementById('input'));
          tap(.1,document.querySelector('a'));
          tap(.1,document.getElementById('card'),20);
          tap(.1);tap(.1,document.getElementById('card'),0,2);
          document.getElementById('previous').disabled=true;tap(.1);
          const selection=getSelection(),range=document.createRange();
          range.selectNodeContents(document.getElementById('text'));selection.addRange(range);tap(.9);
          selection.removeAllRanges();
        })()
        """)
        try await Task.sleep(for: .seconds(NSEvent.doubleClickInterval + 0.1))
        let result = try await view.evaluateJavaScript("[previousCount,nextCount]")
        #expect(result as? [Int] == [1, 1])
    }

    @Test func nonReaderPagesDoNotGainEdgeNavigation() async throws {
        let view = try await fixture(url: "https://weread.qq.com/")
        let result = try await view.evaluateJavaScript("tap(.1);tap(.9);[previousCount,nextCount]")
        #expect(result as? [Int] == [0, 0])
    }
}
