import SwiftUI
import AppKit

@main
struct WeReadMacApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        Window("阅窗 · WeRead Mac", id: "main") {
            ContentView(state: state)
                .frame(minWidth: 880, minHeight: 620)
                .onAppear {
                    NSApplication.shared.setActivationPolicy(.regular)
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }
        }
        .defaultSize(width: 1180, height: 780)
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
}
