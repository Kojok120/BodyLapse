import Foundation

actor WeightStorageService {
    static let shared = WeightStorageService()
    
    private let documentsDirectory: URL
    private let weightsDirectory: URL
    private let weightsFile: URL
    
    private init() {
        // Get documents directory
        documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        
        // Create weights directory
        weightsDirectory = documentsDirectory.appendingPathComponent("WeightData")
        weightsFile = weightsDirectory.appendingPathComponent("entries.json")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(
            at: weightsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - Load Entries
    func loadEntries() throws -> [WeightEntry] {
        guard FileManager.default.fileExists(atPath: weightsFile.path) else {
            return []
        }
        
        let data = try Data(contentsOf: weightsFile)
        let entries = try JSONDecoder().decode([WeightEntry].self, from: data)
        return entries.sorted { $0.date > $1.date }
    }
    
    // MARK: - Save Entry
    func saveEntry(_ entry: WeightEntry) throws {
        var entries = try loadEntries()
        
        // Check if there's already an entry for this date
        if let existingIndex = entries.firstIndex(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: entry.date) 
        }) {
            // Replace existing entry
            entries[existingIndex] = entry
        } else {
            // Add new entry
            entries.append(entry)
        }
        
        // Sort and save
        entries.sort { $0.date > $1.date }
        try saveEntries(entries)
    }
    
    // MARK: - Delete Entry
    func deleteEntry(_ entry: WeightEntry) throws {
        var entries = try loadEntries()
        entries.removeAll { $0.id == entry.id }
        try saveEntries(entries)
    }
    
    // MARK: - Update Entry
    func updateEntry(_ entry: WeightEntry) throws {
        var entries = try loadEntries()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw WeightStorageError.entryNotFound
        }
        entries[index] = entry
        try saveEntries(entries)
    }
    
    // MARK: - Get Entry for Date
    func getEntry(for date: Date) throws -> WeightEntry? {
        let entries = try loadEntries()
        return entries.first { 
            Calendar.current.isDate($0.date, inSameDayAs: date) 
        }
    }
    
    // MARK: - Get Entries in Date Range
    func getEntries(from startDate: Date, to endDate: Date) throws -> [WeightEntry] {
        let entries = try loadEntries()
        return entries.filter { entry in
            entry.date >= startDate && entry.date <= endDate
        }
    }
    
    // MARK: - Private Methods
    private func saveEntries(_ entries: [WeightEntry]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entries)
        try data.write(to: weightsFile, options: .atomic)
    }
    
    // MARK: - Export/Import
    func exportData() throws -> Data {
        guard FileManager.default.fileExists(atPath: weightsFile.path) else {
            return Data()
        }
        return try Data(contentsOf: weightsFile)
    }
    
    func importData(_ data: Data) throws {
        // Validate the data
        let _ = try JSONDecoder().decode([WeightEntry].self, from: data)
        
        // Save the data
        try data.write(to: weightsFile, options: .atomic)
    }
    
    // MARK: - Statistics
    func getStatistics() throws -> WeightStatistics {
        let entries = try loadEntries()
        
        guard !entries.isEmpty else {
            return WeightStatistics(
                totalEntries: 0,
                averageWeight: nil,
                minWeight: nil,
                maxWeight: nil,
                averageBodyFat: nil,
                firstEntryDate: nil,
                lastEntryDate: nil
            )
        }
        
        let weights = entries.map { $0.weight }
        let bodyFats = entries.compactMap { $0.bodyFatPercentage }
        
        return WeightStatistics(
            totalEntries: entries.count,
            averageWeight: weights.reduce(0, +) / Double(weights.count),
            minWeight: weights.min(),
            maxWeight: weights.max(),
            averageBodyFat: bodyFats.isEmpty ? nil : bodyFats.reduce(0, +) / Double(bodyFats.count),
            firstEntryDate: entries.last?.date,
            lastEntryDate: entries.first?.date
        )
    }
}

// MARK: - Error Types
enum WeightStorageError: LocalizedError {
    case entryNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .entryNotFound:
            return "Weight entry not found"
        case .invalidData:
            return "Invalid data format"
        }
    }
}

// MARK: - Statistics Model
struct WeightStatistics {
    let totalEntries: Int
    let averageWeight: Double?
    let minWeight: Double?
    let maxWeight: Double?
    let averageBodyFat: Double?
    let firstEntryDate: Date?
    let lastEntryDate: Date?
}