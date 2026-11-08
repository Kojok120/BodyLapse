import Foundation
import SwiftUI

enum WeightTimeRange: String, CaseIterable {
    case week = "Week"
    case month = "Month"
    case threeMonths = "3 Months"
    case year = "Year"
    case all = "All"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        case .year: return 365
        case .all: return Int.max
        }
    }
}

@MainActor
class WeightTrackingViewModel: ObservableObject {
    @Published var weightEntries: [WeightEntry] = []
    
    private let storage = WeightStorageService.shared
    
    // MARK: - フィルタリング
    func filteredEntries(for timeRange: WeightTimeRange) -> [WeightEntry] {
        guard timeRange != .all else { return weightEntries }
        
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -timeRange.days,
            to: Date()
        ) ?? Date()
        
        return weightEntries.filter { $0.date >= cutoffDate }
    }
    
    init() {
        loadEntries()
        
        // HealthKit同期通知を監視
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(healthKitDataSynced),
            name: Notification.Name("HealthKitDataSynced"),
            object: nil
        )
    }
    
    @objc private func healthKitDataSynced() {
        loadEntries()
    }
    
    // MARK: - データ管理
    func loadEntries() {
        print("[WeightViewModel] Starting to load entries")
        Task {
            do {
                let entries = try await storage.loadEntries()
                print("[WeightViewModel] Loaded \(entries.count) entries from storage")
                await MainActor.run {
                    self.weightEntries = entries
                    print("[WeightViewModel] Updated weightEntries, count: \(self.weightEntries.count)")
                }
            } catch {
                print("[WeightViewModel] Failed to load weight entries: \(error)")
            }
        }
    }
}