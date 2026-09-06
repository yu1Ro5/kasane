import Foundation

/// 主対象部位
enum BodyPart: String, CaseIterable, Codable, Sendable {
    /// 腕
    case arms
    /// 背中
    case back
    /// 胸
    case chest
    /// 体幹
    case core
    /// 全身
    case fullBody
    /// 脚
    case legs
    /// 肩
    case shoulders
    /// その他
    case other

    var displayName: String {
        switch self {
        case .arms: "腕"
        case .back: "背中"
        case .chest: "胸"
        case .core: "体幹"
        case .fullBody: "全身"
        case .legs: "脚"
        case .shoulders: "肩"
        case .other: "その他"
        }
    }
}
