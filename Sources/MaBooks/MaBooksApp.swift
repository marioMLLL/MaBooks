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
            CommandGroup(replacing: .newItem) {
                Button("导入 TXT…") { state.importText() }.keyboardShortcut("o")
            }
            CommandGroup(replacing: .appSettings) {
                Button("账号设置…") { state.showsSettings = true }.keyboardShortcut(",")
            }
            CommandMenu("阅读") {
                Button("打开微信读书") { state.showOfficialReader() }.keyboardShortcut("w", modifiers: [.command, .shift])
                Button("显示／隐藏想法") { state.showsComments.toggle() }.keyboardShortcut("i", modifiers: [.command, .shift])
            }
        }
    }

    private static var applicationIcon: NSImage? {
        if let iconFile = Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
           let resources = Bundle.main.resourceURL,
           let icon = NSImage(contentsOf: resources.appendingPathComponent(iconFile)) { return icon }
        if let url = Bundle.main.url(forResource: "MaBooks", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) { return icon }
        if let resources = Bundle.main.resourceURL,
           let icon = NSImage(contentsOf: resources.appendingPathComponent("MaBooks_MaBooks.bundle/AppIcon.png")) {
            return icon
        }
        return NSImage(contentsOf: Bundle.module.bundleURL.appendingPathComponent("AppIcon.png"))
    }
}
