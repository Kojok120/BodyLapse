import Foundation
import UIKit

/// 撮影習慣の実績（バッジ）の解除状態を管理し、達成時の祝福を仲介するサービス。
@MainActor
class AchievementService: ObservableObject {
    static let shared = AchievementService()

    private let unlockedKey = "unlockedAchievementIDs"

    /// 解除済み実績ID。
    @Published private(set) var unlockedIDs: Set<String> = []

    /// まだ表示していない祝福（複数同時解除に備えてキュー）。先頭から順に表示する。
    @Published var pendingCelebrations: [Achievement] = []

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: unlockedKey) ?? []
        unlockedIDs = Set(stored)
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        unlockedIDs.contains(achievement.id)
    }

    /// 統計を評価し、新たに解除された実績があれば祝福キューに積む。
    /// 冪等：既に解除済みのものは再通知しない。複数回呼んでも安全。
    /// - Returns: 新たに解除された実績（しきい値の昇順）。
    @discardableResult
    func evaluate(_ stats: PhotoStatistics, notify: Bool = true) -> [Achievement] {
        var newlyUnlocked: [Achievement] = []

        for achievement in Achievement.all where !unlockedIDs.contains(achievement.id) {
            if achievement.achievedValue(in: stats) >= achievement.threshold {
                unlockedIDs.insert(achievement.id)
                newlyUnlocked.append(achievement)
            }
        }

        guard !newlyUnlocked.isEmpty else { return [] }

        save()
        if notify {
            pendingCelebrations.append(contentsOf: newlyUnlocked)
            Haptics.success()
        }
        return newlyUnlocked
    }

    /// 先頭の祝福を消化する（表示後に呼ぶ）。
    func dismissCurrentCelebration() {
        guard !pendingCelebrations.isEmpty else { return }
        pendingCelebrations.removeFirst()
    }

    private func save() {
        UserDefaults.standard.set(Array(unlockedIDs), forKey: unlockedKey)
    }

    #if DEBUG
    /// デバッグ用：全解除状態をリセット。
    func resetForDebug() {
        unlockedIDs = []
        pendingCelebrations = []
        UserDefaults.standard.removeObject(forKey: unlockedKey)
    }
    #endif
}
