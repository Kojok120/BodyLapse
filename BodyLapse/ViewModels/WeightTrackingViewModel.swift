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
    @Published var isLoading = false
    
    private let storage = WeightStorageService.shared
    private let userSettings = UserSettingsManager()
    
    var weightUnit: UserSettings.WeightUnit {
        userSettings.settings.weightUnit
    }
    
    // MARK: - Computed Properties
    var currentWeight: Double? {
        weightEntries.sorted { $0.date > $1.date }.first?.weight
    }
    
    var formattedCurrentWeight: String {
        guard let weight = currentWeight else { return "--" }
        let displayWeight = weightUnit == .kg ? weight : weight * 2.20462
        return String(format: "%.1f", displayWeight)
    }
    
    var currentBodyFat: Double? {
        weightEntries
            .sorted { $0.date > $1.date }
            .first { $0.bodyFatPercentage != nil }?
            .bodyFatPercentage
    }
    
    var hasBodyFatData: Bool {
        weightEntries.contains { $0.bodyFatPercentage != nil }
    }
    
    var recentEntries: [WeightEntry] {
        weightEntries.sorted { $0.date > $1.date }
    }
    
    // MARK: - Trend Calculation
    enum Trend {
        case up(Double)
        case down(Double)
        case stable
        case unknown
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.circle.fill"
            case .down: return "arrow.down.circle.fill"
            case .stable: return "equal.circle.fill"
            case .unknown: return "questionmark.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .red
            case .down: return .green
            case .stable: return .blue
            case .unknown: return .gray
            }
        }
        
        var text: String {
            switch self {
            case .up(let change):
                return "+\(String(format: "%.1f", change))%"
            case .down(let change):
                return "-\(String(format: "%.1f", change))%"
            case .stable:
                return "0%"
            case .unknown:
                return "--"
            }
        }
    }
    
    var weightTrend: Trend {
        calculateTrendForWeight()
    }
    
    var bodyFatTrend: Trend {
        calculateTrendForBodyFat()
    }
    
    private func calculateTrendForWeight() -> Trend {
        let sortedEntries = weightEntries.sorted { $0.date > $1.date }
        
        guard sortedEntries.count >= 2 else { return .unknown }
        
        let current = sortedEntries[0].weight
        let previous = sortedEntries[1].weight
        
        let change = ((current - previous) / previous) * 100
        
        if abs(change) < 0.5 {
            return .stable
        } else if change > 0 {
            return .up(abs(change))
        } else {
            return .down(abs(change))
        }
    }
    
    private func calculateTrendForBodyFat() -> Trend {
        let sortedEntries = weightEntries
            .filter { $0.bodyFatPercentage != nil }
            .sorted { $0.date > $1.date }
        
        guard sortedEntries.count >= 2,
              let current = sortedEntries[0].bodyFatPercentage,
              let previous = sortedEntries[1].bodyFatPercentage else { return .unknown }
        
        let change = ((current - previous) / previous) * 100
        
        if abs(change) < 0.5 {
            return .stable
        } else if change > 0 {
            return .up(abs(change))
        } else {
            return .down(abs(change))
        }
    }
    
    private func calculateTrend(for keyPath: KeyPath<WeightEntry, Double?>) -> Trend {
        let sortedEntries = weightEntries.sorted { $0.date > $1.date }
        
        guard sortedEntries.count >= 2 else { return .unknown }
        
        var current: Double?
        var previous: Double?
        
        // Find the most recent value
        for entry in sortedEntries {
            if let value = entry[keyPath: keyPath] {
                current = value
                break
            }
        }
        
        // Find the previous value
        var foundCurrent = false
        for entry in sortedEntries {
            if let value = entry[keyPath: keyPath] {
                if foundCurrent {
                    previous = value
                    break
                } else if value == current {
                    foundCurrent = true
                }
            }
        }
        
        guard let currentValue = current, let previousValue = previous else { return .unknown }
        
        let change = ((currentValue - previousValue) / previousValue) * 100
        
        if abs(change) < 0.5 {
            return .stable
        } else if change > 0 {
            return .up(abs(change))
        } else {
            return .down(abs(change))
        }
    }
    
    // MARK: - Filtering
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
        
        // Listen for HealthKit sync notifications
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
    
    // MARK: - Data Management
    func loadEntries() {
        print("[WeightViewModel] Starting to load entries")
        isLoading = true
        Task {
            do {
                let entries = try await storage.loadEntries()
                print("[WeightViewModel] Loaded \(entries.count) entries from storage")
                await MainActor.run {
                    self.weightEntries = entries
                    self.isLoading = false
                    print("[WeightViewModel] Updated weightEntries, count: \(self.weightEntries.count)")
                }
            } catch {
                print("[WeightViewModel] Failed to load weight entries: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    func addEntry(
        weight: Double,
        bodyFat: Double?,
        date: Date,
        linkedPhotoID: String?
    ) {
        print("[WeightViewModel] Adding entry - weight: \(weight), bodyFat: \(bodyFat ?? 0), date: \(date)")
        let entry = WeightEntry(
            date: date,
            weight: weight,
            bodyFatPercentage: bodyFat,
            linkedPhotoID: linkedPhotoID
        )
        
        Task {
            do {
                try await storage.saveEntry(entry)
                await MainActor.run {
                    self.weightEntries.append(entry)
                    self.weightEntries.sort { $0.date > $1.date }
                    print("[WeightViewModel] Entry added successfully, total entries: \(self.weightEntries.count)")
                }
            } catch {
                print("[WeightViewModel] Failed to save weight entry: \(error)")
            }
        }
    }
    
    func deleteEntry(_ entry: WeightEntry) {
        Task {
            do {
                try await storage.deleteEntry(entry)
                await MainActor.run {
                    self.weightEntries.removeAll { $0.id == entry.id }
                }
            } catch {
                print("Failed to delete weight entry: \(error)")
            }
        }
    }
}