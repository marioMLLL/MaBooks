import SwiftUI

struct AccountSettings: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.skinPalette) private var palette
    @State private var key = ""
    @State private var message: String?
    @State private var clearing = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Text("连接微信读书").font(.title2.bold())
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Text("连接后可同步电子书架、热门划线及划线下的想法。全文在内嵌的官方网页版阅读，需要单独扫码登录。")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Link("在微信读书官网获取 API Key ↗", destination: URL(string: "https://weread.qq.com/r/weread-skills")!)
            SecureField("wrk-…", text: $key).textFieldStyle(.roundedBorder)
            HStack {
                Button(state.hasKey ? "更新连接" : "保存并同步") {
                    do { try state.saveKey(key); key = ""; message = nil; dismiss() }
                    catch { message = error.localizedDescription }
                }.buttonStyle(.borderedProminent).disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                if state.hasKey {
                    Button("断开 API 连接", role: .destructive) {
                        do { try state.disconnect(); key = ""; message = "API 连接已断开。" }
                        catch { message = error.localizedDescription }
                    }
                }
            }
            Text(state.hasKey ? "API Key 已保存在 macOS 钥匙串中。" : "API Key 只保存在 macOS 钥匙串中。")
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            HStack {
                Button("打开官方网页版") { state.showOfficialReader(); dismiss() }
                Button("退出网页账号") {
                    clearing = true
                    Task { await state.web.clearSession(); clearing = false; message = "网页会话已清除。" }
                }.disabled(clearing)
                if clearing { ProgressView().controlSize(.small) }
            }
            Text("网页版登录与 API 连接相互独立。断开 API 不会自动退出网页账号。")
                .font(.caption).foregroundStyle(.secondary)
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
        }.padding(30).frame(width: 530).foregroundStyle(palette.ink).background(palette.paper).tint(palette.accent)
    }
}
