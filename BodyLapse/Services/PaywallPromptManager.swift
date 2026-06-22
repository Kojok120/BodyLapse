import Foundation

/// 文脈ペイウォール（Pro誘導）の表示状態を管理する軽量ヘルパー。
/// 各プロンプトは原則1回きり表示し、しつこくならないようにする。
@MainActor
final class PaywallPromptManager {
    static let shared = PaywallPromptManager()

    enum Prompt: String {
        case milestoneCloud = "paywall.shown.milestoneCloud"
        case shareWatermark = "paywall.shown.shareWatermark"
    }

    /// クラウド誘導を出す撮影日数のしきい値。
    let cloudMilestoneThreshold = 30

    private let defaults = UserDefaults.standard
    private init() {}

    func hasShown(_ prompt: Prompt) -> Bool {
        defaults.bool(forKey: prompt.rawValue)
    }

    func markShown(_ prompt: Prompt) {
        defaults.set(true, forKey: prompt.rawValue)
    }

    #if DEBUG
    func resetForDebug() {
        defaults.removeObject(forKey: Prompt.milestoneCloud.rawValue)
        defaults.removeObject(forKey: Prompt.shareWatermark.rawValue)
    }
    #endif
}
