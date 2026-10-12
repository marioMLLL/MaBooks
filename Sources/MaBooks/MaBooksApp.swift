import SwiftUI
import AppKit

@main
struct MaBooksApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        Window("MaBooks", id: "main") {
            ContentView(state: state)
                .frame(minWidth: 1000, minHeight: 660)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    if let icon = Self.applicationIcon {
                        NSApplication.shared.applicationIconImage = icon
                    }
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 MaBooks") {
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [:]
                    if let icon = Self.applicationIcon {
                        options[.applicationIcon] = icon
                    }
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("导入 TXT…") { state.importText() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .appSettings) {
                Button("账号设置…") { state.showsSettings = true }.keyboardShortcut(",")
            }
            CommandMenu("阅读") {
                Button("进入／退出全屏阅读") { state.web.toggleFullScreen() }
                    .keyboardShortcut("f", modifiers: [.control, .command])
                Button("打开微信读书") { state.showOfficialReader() }.keyboardShortcut("w", modifiers: [.command, .shift])
                Button("显示／隐藏想法") { state.showsComments.toggle() }.keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }

    private static var applicationIcon: NSImage? {
        if let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let url = Bundle.main.url(forResource: iconFile, withExtension: nil),
           let icon = NSImage(contentsOf: url) { return icon }
        return NSImage(contentsOf: Bundle.module.bundleURL.appendingPathComponent("AppIcon.png"))
    }
}
