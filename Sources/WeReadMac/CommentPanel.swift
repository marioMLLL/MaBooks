import SwiftUI
import ReaderCore

struct CommentPanel: View {
    @ObservedObject var state: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("段落想法").font(.headline)
                Spacer()
                Button { state.showsComments = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain).help("关闭面板")
            }.padding(20)
            Divider()
            if let paragraph = state.selectedParagraph {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(state.selectedBook.source == .sample ? "示例讨论" : state.selectedBook.source == .local ? "本地阅读" : "微信读书 · 划线下的想法")
                            .font(.caption).foregroundStyle(.teal)
                        Text(paragraph.text).font(.callout).lineSpacing(5).foregroundStyle(.secondary)
                            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.teal.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                        ForEach(state.comments) { comment in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "person.crop.circle.fill").foregroundStyle(.teal)
                                    Text(comment.author).font(.callout.weight(.medium))
                                    Spacer()
                                }
                                Text(comment.text).font(.callout).lineSpacing(5).textSelection(.enabled)
                                if let date = comment.date { Text(date, format: .dateTime.year().month().day()).font(.caption2).foregroundStyle(.tertiary) }
                            }
                            Divider()
                        }
                        if state.loadingComments { ProgressView("读取想法…").controlSize(.small) }
                        if let error = state.commentError {
                            Text(error).font(.caption).foregroundStyle(.red)
                            Button("重试") { state.loadComments() }
                        } else if state.nextCursor != nil {
                            Button("加载更多") { state.loadComments() }.disabled(state.loadingComments)
                        } else if state.comments.isEmpty && !state.loadingComments {
                            Text(state.selectedBook.source == .local ? "阅读位置已保存。本地书暂不提供社区评论。" : "这条划线暂无想法。")
                                .font(.callout).foregroundStyle(.secondary)
                        }
                    }.padding(20)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble").font(.system(size: 32)).foregroundStyle(.teal.opacity(0.7))
                    Text("在一句话旁，遇见另一种理解").font(.callout).multilineTextAlignment(.center)
                    Text("点击一段文字，在这里查看想法。").font(.caption).foregroundStyle(.secondary)
                }.padding(24).frame(maxWidth: .infinity)
                Spacer()
            }
        }.background(Color(nsColor: .windowBackgroundColor))
    }
}
