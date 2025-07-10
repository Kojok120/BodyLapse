import Foundation
import SwiftUI

// MARK: - Tooltip Manager Service
class TooltipManager: ObservableObject {
    static let shared = TooltipManager()
    
    // MARK: - Feature IDs
    enum FeatureID: String, CaseIterable {
        case videoGeneration = "video_generation"
        case categoryAdding = "category_adding"
        case premiumFeatures = "premium_features"
        case categoryManagement = "category_management"
    }
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let tooltipShownPrefix = "tooltip_shown_"
        static let tooltipCompletedPrefix = "tooltip_completed_"
    }
    
    // MARK: - Published Properties
    @Published private var shownFeatures: Set<FeatureID> = []
    @Published private var completedFeatures: Set<FeatureID> = []
    
    // MARK: - Initialization
    private init() {
        loadState()
    }
    
    // MARK: - Public Methods
    
    /// Check if a feature needs guidance (red dot)
    func needsGuidance(for feature: FeatureID) -> Bool {
        return !completedFeatures.contains(feature)
    }
    
    /// Check if tooltip has been shown for a feature
    func hasShownTooltip(for feature: FeatureID) -> Bool {
        return shownFeatures.contains(feature)
    }
    
    /// Mark tooltip as shown for a feature
    func markTooltipShown(for feature: FeatureID) {
        shownFeatures.insert(feature)
        saveTooltipShown(for: feature)
    }
    
    /// Mark feature as completed (removes red dot permanently)
    func markFeatureCompleted(for feature: FeatureID) {
        completedFeatures.insert(feature)
        shownFeatures.insert(feature) // Also mark as shown
        saveTooltipCompleted(for: feature)
        saveTooltipShown(for: feature)
    }
    
    /// Reset all guidance state (for testing/debugging)
    func resetAllGuidance() {
        shownFeatures.removeAll()
        completedFeatures.removeAll()
        
        for feature in FeatureID.allCases {
            UserDefaults.standard.removeObject(forKey: Keys.tooltipShownPrefix + feature.rawValue)
            UserDefaults.standard.removeObject(forKey: Keys.tooltipCompletedPrefix + feature.rawValue)
        }
    }
    
    /// Get total number of features requiring guidance
    func getTotalGuidanceCount() -> Int {
        return FeatureID.allCases.count - completedFeatures.count
    }
    
    /// Get completion percentage
    func getCompletionPercentage() -> Double {
        let totalFeatures = FeatureID.allCases.count
        let completedCount = completedFeatures.count
        return totalFeatures > 0 ? Double(completedCount) / Double(totalFeatures) : 0.0
    }
    
    // MARK: - Private Methods
    
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

// MARK: - Guidance Content Provider
extension TooltipManager {
    
    /// Get localized title for a feature
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
    
    /// Get localized description for a feature
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
