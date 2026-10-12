import Foundation

/// Visual identity is independent of reading mode, tone and typography.
public enum ReaderSkin: String, Codable, CaseIterable, Identifiable, Sendable {
    case sakura, ocean, forest, paper
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .sakura: "春日樱语"
        case .ocean: "海盐微风"
        case .forest: "林间书屋"
        case .paper: "素纸"
        }
    }
    public var subtitle: String {
        switch self {
        case .sakura: "樱花落在书页之间"
        case .ocean: "留一点海风给自己"
        case .forest: "在绿意里慢慢阅读"
        case .paper: "让文字回到纸上"
        }
    }
    public var symbol: String {
        switch self {
        case .sakura: "camera.macro"
        case .ocean: "water.waves"
        case .forest: "leaf"
        case .paper: "book.closed"
        }
    }
}
