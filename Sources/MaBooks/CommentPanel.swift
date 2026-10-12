import SwiftUI
import ReaderCore

struct CommentPanel: View {
    @ObservedObject var state: AppState
    @Environment(\.skinPalette) private var palette
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("段落想法").font(.system(size: 18, weight: .medium, design: .serif))
                if !state.comments.isEmpty { Text("（\(state.comments.count)）").font(.callout).foregroundStyle(palette.muted) }
                Spacer()
                SkinIconButton(title: "关闭评论面板", symbol: "xmark") { state.showsComments = false }
            }.padding(.horizontal, 22).padding(.vertical, 22).frame(height: 102)
            Rectangle().fill(palette.border).frame(height: 1).padding(.horizontal, 20)
            if let paragraph = state.selectedParagraph {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text(state.selectedBook.source == .sample ? "原创示例 · 示例讨论" : state.selectedBook.source == .local ? "本地阅读" : "微信读书 · 真实想法")
                            .font(.system(size: 10)).tracking(1).foregroundStyle(palette.muted)
                        if state.selectedBook.source == .weread {
                            Text(paragraph.text).font(.system(size: 12, design: .serif)).lineSpacing(5).foregroundStyle(palette.muted)
                                .padding(12).background(palette.selection.opacity(0.5), in: RoundedRectangle(cornerRadius: 9))
                        }
                        ForEach(state.comments) { comment in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14).fill(palette.selection)
                                    Image(systemName: palette.skin == .sakura ? "camera.macro" : "person.crop.circle").font(.system(size: 21, weight: .light)).foregroundStyle(palette.accent)
                                }.frame(width: 44, height: 48).accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(comment.author).font(.system(size: 14, weight: .medium, design: .serif))
                                        if let date = comment.date { Text(date, format: .dateTime.year().month().day()).font(.system(size: 10)).foregroundStyle(palette.muted) }
                                        else if state.selectedBook.source == .sample { Text("示例读者").font(.system(size: 10)).foregroundStyle(palette.muted) }
                                    }
                                    Text(comment.text).font(.system(size: 13, design: .serif)).lineSpacing(7).textSelection(.enabled)
                                }.frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Rectangle().fill(palette.border).frame(height: 1)
                        }
                        if state.loadingComments { ProgressView("读取想法…").controlSize(.small) }
                        if let error = state.commentError {
                            Text(error).font(.caption).foregroundStyle(.red); Button("重试") { state.loadComments() }
                        } else if state.nextCursor != nil { Button("加载更多") { state.loadComments() }.disabled(state.loadingComments) }
                        else if state.comments.isEmpty && !state.loadingComments {
                            Text(state.selectedBook.source == .local ? "阅读位置已保存。\n本地书暂不提供社区评论。" : "这条划线暂无想法。")
                                .font(.callout).lineSpacing(6).foregroundStyle(palette.muted)
                        }
                    }.padding(.horizontal, 22).padding(.vertical, 26)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "text.bubble").font(.system(size: 30, weight: .ultraLight)).foregroundStyle(palette.accent)
                    Text("在书页旁，遇见另一种理解").font(.system(size: 14, design: .serif))
                    Text("点击一段文字，展开这里的对话。").font(.system(size: 11)).foregroundStyle(palette.muted)
                }.padding(22).frame(maxWidth: .infinity)
                Spacer()
            }
            HStack(spacing: 7) {
                Image(systemName: palette.skin.symbol).foregroundStyle(palette.accent.opacity(0.7))
                Text("\(palette.skin.title) · 慢慢读，慢慢想").font(.system(size: 10, design: .serif)).foregroundStyle(palette.muted)
            }.padding(.horizontal, 22).padding(.bottom, 22)
        }.foregroundStyle(palette.ink).background(palette.paper.opacity(0.86))
    }
}
