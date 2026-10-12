import SwiftUI
import ReaderCore

/// SwiftPM's generated accessor expects a sibling bundle, whereas a macOS app
/// stores it under Contents/Resources. Resolve packaged assets before dev paths.
enum SkinArtwork {
    static let sakura: NSImage? = {
        if let resourceURL = Bundle.main.resourceURL {
            let packaged = resourceURL.appendingPathComponent("MaBooks_MaBooks.bundle/sakura-reading.png")
            if let image = NSImage(contentsOf: packaged) { return image }
        }
        return NSImage(contentsOf: Bundle.module.bundleURL.appendingPathComponent("sakura-reading.png"))
    }()
}

struct SkinPalette {
    let skin: ReaderSkin
    let dark: Bool
    let accent: Color
    let ink: Color
    let muted: Color
    let paper: Color
    let sidebar: Color
    let backdrop: Color
    let wash: Color
    var border: Color { ink.opacity(dark ? 0.10 : 0.07) }
    var selection: Color { accent.opacity(dark ? 0.19 : 0.13) }

    init(skin: ReaderSkin, theme: ReaderTheme = .sepia, systemDark: Bool = false) {
        self.skin = skin
        dark = theme == .dark || (theme == .system && systemDark)
        let hue: UInt32
        let surface: UInt32
        let side: UInt32
        let background: UInt32
        switch skin {
        case .sakura: (hue, surface, side, background) = (0xD85E83, 0xFFF8F0, 0xFAEEEB, 0xEFCBD1)
        case .ocean: (hue, surface, side, background) = (0x397F98, 0xF5FAFA, 0xEAF3F6, 0xB6D5DF)
        case .forest: (hue, surface, side, background) = (0x55765D, 0xF8FAF2, 0xEEF1E5, 0xC2CEB2)
        case .paper: (hue, surface, side, background) = (0x8B735B, 0xFFFCF7, 0xF3EFE7, 0xDED7CD)
        }
        let nightHue: UInt32
        switch skin {
        case .sakura: nightHue = 0xEAA0B8
        case .ocean: nightHue = 0x8ABDD0
        case .forest: nightHue = 0xA8C49E
        case .paper: nightHue = 0xC8B39D
        }
        accent = Color(hex: dark ? nightHue : hue)
        ink = Color(hex: dark ? 0xE9E5E7 : 0x303344)
        muted = Color(hex: dark ? 0xACA6B0 : 0x787C8E)
        paper = Color(hex: dark ? 0x232329 : theme == .light ? 0xFFFDFA : surface)
        sidebar = Color(hex: dark ? 0x28272F : side)
        backdrop = Color(hex: dark ? 0x181A24 : background)
        wash = Color(hex: dark ? 0x35333C : surface)
    }
}

private struct SkinPaletteKey: EnvironmentKey {
    static let defaultValue = SkinPalette(skin: .sakura)
}

extension EnvironmentValues {
    var skinPalette: SkinPalette {
        get { self[SkinPaletteKey.self] }
        set { self[SkinPaletteKey.self] = newValue }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct SkinBackdrop: View {
    let palette: SkinPalette
    let decorated: Bool
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                palette.backdrop
                if decorated && palette.skin == .sakura, let artwork = SkinArtwork.sakura {
                    Image(nsImage: artwork).resizable().scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height).clipped()
                        .opacity(palette.dark ? 0.26 : 0.90)
                } else if decorated && palette.skin != .paper {
                    Canvas { context, size in
                        for index in 0..<7 {
                            var path = Path()
                            let start = CGFloat(index) * 70
                            path.move(to: CGPoint(x: 0, y: size.height * 0.75 + start))
                            path.addCurve(to: CGPoint(x: size.width, y: size.height * 0.3 + start),
                                          control1: CGPoint(x: size.width * 0.35, y: size.height * 0.9 + start),
                                          control2: CGPoint(x: size.width * 0.7, y: size.height * 0.1 + start))
                            context.stroke(path, with: .color(palette.accent.opacity(0.10)), lineWidth: palette.skin == .ocean ? 32 : 10)
                        }
                    }
                }
                LinearGradient(colors: [palette.paper.opacity(palette.dark ? 0.14 : 0.04), .clear, palette.accent.opacity(0.06)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }.ignoresSafeArea().allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct BookCover: View {
    let book: Book
    var width: CGFloat = 42
    var height: CGFloat = 58
    @Environment(\.skinPalette) private var palette
    var body: some View {
        Group {
            if let cover = book.coverURL {
                AsyncImage(url: cover) { image in image.resizable().scaledToFill() } placeholder: { decorativeCover }
            } else { decorativeCover }
        }.frame(width: width, height: height).clipped()
            .clipShape(RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.45)))
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .accessibilityHidden(true)
    }
    private var decorativeCover: some View {
        ZStack {
            LinearGradient(colors: [palette.accent.opacity(0.25), palette.paper, palette.accent.opacity(0.50)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if palette.skin == .sakura, let artwork = SkinArtwork.sakura {
                Image(nsImage: artwork).resizable().scaledToFill().offset(x: -width * 0.5)
            } else {
                Image(systemName: palette.skin.symbol).font(.system(size: width * 0.5, weight: .ultraLight)).foregroundStyle(palette.accent)
            }
        }
    }
}

struct SkinIconButton: View {
    let title: String
    let symbol: String
    var selected = false
    let action: () -> Void
    @Environment(\.skinPalette) private var palette
    var body: some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .regular))
                .foregroundStyle(selected ? palette.accent : palette.ink)
                .frame(width: 34, height: 34)
                .background(selected ? palette.selection : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).help(title).accessibilityLabel(title)
    }
}
