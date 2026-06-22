import Foundation

/// 実績（バッジ）の種類。
enum AchievementCategory {
    case streak     // 連続撮影日数のマイルストーン
    case totalDays  // 通算撮影日数のマイルストーン
}

/// 撮影習慣のマイルストーンを表す実績バッジ。
/// データ駆動（カテゴリ＋しきい値）で、文言はローカライズのフォーマットから生成する。
struct Achievement: Identifiable, Equatable {
    let id: String
    let category: AchievementCategory
    let threshold: Int
    let iconName: String

    /// バッジ名（例: 「7日連続」「通算100日」）。
    var displayName: String {
        switch category {
        case .streak:
            return "achievement.streak.name".localized(with: threshold)
        case .totalDays:
            return "achievement.total.name".localized(with: threshold)
        }
    }

    /// 解除時の褒めメッセージ。
    var praiseMessage: String {
        switch category {
        case .streak:
            return "achievement.streak.praise".localized(with: threshold)
        case .totalDays:
            return "achievement.total.praise".localized(with: threshold)
        }
    }

    /// この統計が実績のしきい値を満たすか評価する際に使う値。
    /// 連続系は「最長記録」で判定する（達成後に途切れても解除は維持）。
    func achievedValue(in stats: PhotoStatistics) -> Int {
        switch category {
        case .streak:
            return stats.longestStreak
        case .totalDays:
            return stats.totalDays
        }
    }
}

extension Achievement {
    /// アプリで定義する全実績（しきい値の昇順）。
    static let all: [Achievement] = [
        Achievement(id: "streak_3",    category: .streak,    threshold: 3,   iconName: "flame"),
        Achievement(id: "streak_7",    category: .streak,    threshold: 7,   iconName: "flame.fill"),
        Achievement(id: "streak_14",   category: .streak,    threshold: 14,  iconName: "bolt.fill"),
        Achievement(id: "streak_30",   category: .streak,    threshold: 30,  iconName: "star.fill"),
        Achievement(id: "streak_60",   category: .streak,    threshold: 60,  iconName: "crown.fill"),
        Achievement(id: "streak_100",  category: .streak,    threshold: 100, iconName: "trophy.fill"),
        Achievement(id: "total_30",    category: .totalDays, threshold: 30,  iconName: "checkmark.seal.fill"),
        Achievement(id: "total_100",   category: .totalDays, threshold: 100, iconName: "rosette"),
        Achievement(id: "total_365",   category: .totalDays, threshold: 365, iconName: "sparkles")
    ]
}
