import SwiftUI
import ReaderCore

struct SkinPicker: View {
    @Binding var skin: ReaderSkin
    @Binding var decorated: Bool
    @Binding var theme: ReaderTheme
    @Environment(\.skinPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("给阅读换一种心情").font(.system(size: 26, weight: .medium, design: .serif))
                    Text("MaBooks 皮肤 · 每一种风景，都有自己的书页").font(.callout).foregroundStyle(palette.muted)
                }
                Spacer()
                SkinIconButton(title: "关闭皮肤设置", symbol: "xmark") { dismiss() }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                ForEach(ReaderSkin.allCases) { option in
                    Button { skin = option } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            SkinPreview(skin: option).frame(height: 110).clipped()
                            HStack {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(option.title).font(.headline)
                                    Text(option.subtitle).font(.caption).foregroundStyle(palette.muted)
                                }
                                Spacer()
                                Image(systemName: skin == option ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(skin == option ? palette.accent : palette.muted.opacity(0.5))
                            }.padding(14)
                        }.background(palette.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(skin == option ? palette.accent : palette.border, lineWidth: skin == option ? 2 : 1))
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(option.title)\(skin == option ? "，已选择" : "")")
                }
            }
            HStack {
                Image(systemName: "sparkles").foregroundStyle(palette.accent)
                Toggle("显示皮肤装饰", isOn: $decorated)
                Text("关闭后保留配色，让书页更安静").font(.caption).foregroundStyle(palette.muted)
            }
            HStack {
                Text("阅读主题").font(.callout)
                Picker("阅读主题", selection: $theme) {
                    ForEach(ReaderTheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            Text("皮肤应用于原生界面；微信读书网页使用网页自己的设置。选择会自动保存。").font(.caption).foregroundStyle(palette.muted)
        }.padding(30).frame(width: 620).foregroundStyle(palette.ink)
            .background(palette.sidebar).tint(palette.accent)
    }
}

private struct SkinPreview: View {
    let skin: ReaderSkin
    private var palette: SkinPalette { SkinPalette(skin: skin) }
    var body: some View {
        ZStack {
            SkinBackdrop(palette: palette, decorated: true)
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 7) {
                    Image(systemName: skin.symbol).foregroundStyle(palette.accent)
                    RoundedRectangle(cornerRadius: 2).fill(palette.accent.opacity(0.3)).frame(height: 5)
                    RoundedRectangle(cornerRadius: 2).fill(palette.border).frame(height: 5)
                    Spacer()
                }.padding(9).frame(width: 43).background(palette.sidebar.opacity(0.9))
                VStack(alignment: .leading, spacing: 8) {
                    Text("MaBooks").font(.system(size: 10, weight: .medium, design: .serif)).foregroundStyle(palette.ink)
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: 2).fill(index == 1 ? palette.selection : palette.border).frame(height: index == 1 ? 16 : 4)
                    }
                }.padding(10).frame(maxWidth: .infinity, maxHeight: .infinity).background(palette.paper.opacity(0.92))
                VStack(spacing: 6) {
                    Circle().fill(palette.accent.opacity(0.3)).frame(width: 13, height: 13)
                    RoundedRectangle(cornerRadius: 2).fill(palette.border).frame(height: 4)
                    Spacer()
                }.padding(8).frame(width: 35).background(palette.paper.opacity(0.84))
            }.frame(height: 80).clipShape(RoundedRectangle(cornerRadius: 7)).padding(.horizontal, 18)
        }.accessibilityHidden(true)
    }
}
