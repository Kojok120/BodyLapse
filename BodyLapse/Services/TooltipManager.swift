import Foundation
import SwiftUI

// MARK: - ツールチップマネージャーサービス
class TooltipManager: ObservableObject {
    static let shared = TooltipManager()
    
    // MARK: - 機能ID
    enum FeatureID: String, CaseIterable {
        case videoGeneration = "video_generation"
        case categoryAdding = "category_adding"
        case premiumFeatures = "premium_features"
        case categoryManagement = "category_management"
    }
    
    // MARK: - UserDefaultsキー
    private enum Keys {
        static let tooltipShownPrefix = "tooltip_shown_"
        static let tooltipCompletedPrefix = "tooltip_completed_"
    }
    
    // MARK: - 公開プロパティ
    @Published private var shownFeatures: Set<FeatureID> = []
    @Published private var completedFeatures: Set<FeatureID> = []
    
    // MARK: - 初期化
    private init() {
        loadState()
    }
    
    // MARK: - 公開メソッド
    
    /// 機能にガイダンス（赤いドット）が必要か確認
    func needsGuidance(for feature: FeatureID) -> Bool {
        return !completedFeatures.contains(feature)
    }
    
    /// 機能のツールチップが表示済みか確認
    func hasShownTooltip(for feature: FeatureID) -> Bool {
        return shownFeatures.contains(feature)
    }
    
    /// 機能のツールチップを表示済みとマーク
    func markTooltipShown(for feature: FeatureID) {
        shownFeatures.insert(feature)
        saveTooltipShown(for: feature)
    }
    
    /// 機能を完了とマーク（赤いドットを永久的に削除）
    func markFeatureCompleted(for feature: FeatureID) {
        completedFeatures.insert(feature)
        shownFeatures.insert(feature) // Also mark as shown
        saveTooltipCompleted(for: feature)
        saveTooltipShown(for: feature)
    }
    
    /// 全てのガイダンス状態をリセット（テスト/デバッグ用）
    func resetAllGuidance() {
        shownFeatures.removeAll()
        completedFeatures.removeAll()
        
        for feature in FeatureID.allCases {
            UserDefaults.standard.removeObject(forKey: Keys.tooltipShownPrefix + feature.rawValue)
            UserDefaults.standard.removeObject(forKey: Keys.tooltipCompletedPrefix + feature.rawValue)
        }
    }
    
    /// ガイダンスが必要な機能の総数を取得
    func getTotalGuidanceCount() -> Int {
        return FeatureID.allCases.count - completedFeatures.count
    }
    
    /// 完了率を取得
    func getCompletionPercentage() -> Double {
        let totalFeatures = FeatureID.allCases.count
        let completedCount = completedFeatures.count
        return totalFeatures > 0 ? Double(completedCount) / Double(totalFeatures) : 0.0
    }
    
    // MARK: - プライベートメソッド
    
    private func loadState() {
        for feature in FeatureID.allCases {
            if UserDefaults.standard.bool(forKey: Keys.tooltipShownPrefix + feature.rawValue) {
                shownFeatures.insert(feature)
            }
            if UserDefaults.standard.bool(forKey: Keys.tooltipCompletedPrefix + feature.rawValue) {
                completedFeatures.insert(feature)
            }
        }
    }
    
    private func saveTooltipShown(for feature: FeatureID) {
        UserDefaults.standard.set(true, forKey: Keys.tooltipShownPrefix + feature.rawValue)
    }
    
    private func saveTooltipCompleted(for feature: FeatureID) {
        UserDefaults.standard.set(true, forKey: Keys.tooltipCompletedPrefix + feature.rawValue)
    }
}

// MARK: - ガイダンスコンテンツプロバイダー
extension TooltipManager {
    
    /// 機能のローカライズされたタイトルを取得
    func getTitle(for feature: FeatureID) -> String {
        switch feature {
        case .videoGeneration:
            return "guidance.video_generation.title".localized
        case .categoryAdding:
            return "guidance.category_adding.title".localized
        case .premiumFeatures:
            return "guidance.premium_features.title".localized
        case .categoryManagement:
            return "guidance.category_management.title".localized
        }
    }
    
    /// 機能のローカライズされた説明を取得
    func getDescription(for feature: FeatureID) -> String {
        switch feature {
        case .videoGeneration:
            return "guidance.video_generation.description".localized
        case .categoryAdding:
            return "guidance.category_adding.description".localized
        case .premiumFeatures:
            return "guidance.premium_features.description".localized
        case .categoryManagement:
            return "guidance.category_management.description".localized
        }
    }
}
