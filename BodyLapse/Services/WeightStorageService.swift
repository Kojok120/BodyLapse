import Foundation

actor WeightStorageService {
    static let shared = WeightStorageService()
    
    private let documentsDirectory: URL
    private let weightsDirectory: URL
    private let weightsFile: URL
    
    private init() {
        // ドキュメントディレクトリを取得
        guard let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            // これは発生しないはずだが、フォールバックとして一時ディレクトリを使用
            documentsDirectory = FileManager.default.temporaryDirectory
            weightsDirectory = documentsDirectory.appendingPathComponent("WeightData")
            weightsFile = weightsDirectory.appendingPathComponent("entries.json")
            return
        }
        documentsDirectory = documentsDir
        
        // 体重ディレクトリを作成
        weightsDirectory = documentsDirectory.appendingPathComponent("WeightData")
        weightsFile = weightsDirectory.appendingPathComponent("entries.json")
        
        // 必要に応じてディレクトリを作成
        try? FileManager.default.createDirectory(
            at: weightsDirectory,
            withIntermediateDirectories: true
        )
    }
    
    // MARK: - エントリ読み込み
    func loadEntries() throws -> [WeightEntry] {
        print("[WeightStorage] Loading entries from: \(weightsFile.path)")
        
        guard FileManager.default.fileExists(atPath: weightsFile.path) else {
            print("[WeightStorage] No weights file exists yet")
            return []
        }
        
        let data = try Data(contentsOf: weightsFile)
        print("[WeightStorage] File size: \(data.count) bytes")
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = try decoder.decode([WeightEntry].self, from: data)
        
        print("[WeightStorage] Loaded \(entries.count) entries")
        return entries.sorted { $0.date > $1.date }
    }
    
    // MARK: - エントリ保存
    func saveEntry(_ entry: WeightEntry) throws {
        print("[WeightStorage] Saving entry for date: \(entry.date), weight: \(entry.weight)")
        var entries = try loadEntries()
        
        // この日付に既存のエントリがあるか確認
        if let existingIndex = entries.firstIndex(where: { 
            Calendar.current.isDate($0.date, inSameDayAs: entry.date) 
        }) {
            // 既存のエントリを置換
            entries[existingIndex] = entry
        } else {
            // 新しいエントリを追加
            entries.append(entry)
        }
        
        // ソートして保存
        entries.sort { $0.date > $1.date }
        try saveEntries(entries)
        print("[WeightStorage] Total entries after save: \(entries.count)")
    }
    
    // MARK: - エントリ削除
    func deleteEntry(_ entry: WeightEntry) throws {
        var entries = try loadEntries()
        entries.removeAll { $0.id == entry.id }
        try saveEntries(entries)
    }
    
    // MARK: - エントリ更新
    func updateEntry(_ entry: WeightEntry) throws {
        var entries = try loadEntries()
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else {
            throw WeightStorageError.entryNotFound
        }
        entries[index] = entry
        try saveEntries(entries)
    }
    
    // MARK: - 日付別エントリ取得
    func getEntry(for date: Date) throws -> WeightEntry? {
        let entries = try loadEntries()
        return entries.first { 
            Calendar.current.isDate($0.date, inSameDayAs: date) 
        }
    }
    
    // MARK: - 日付範囲内のエントリ取得
    func getEntries(from startDate: Date, to endDate: Date) throws -> [WeightEntry] {
        let entries = try loadEntries()
        let calendar = Calendar.current
        let normalizedStart = calendar.startOfDay(for: startDate)
        let normalizedEnd = calendar.startOfDay(for: endDate)
        return entries.filter { entry in
            let entryDay = calendar.startOfDay(for: entry.date)
            return entryDay >= normalizedStart && entryDay <= normalizedEnd
        }
    }
    
    // MARK: - プライベートメソッド
    private func saveEntries(_ entries: [WeightEntry]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(entries)
        try data.write(to: weightsFile, options: .atomic)
        print("[WeightStorage] Saved \(entries.count) entries to file")
    }
    
    // MARK: - エクスポート/インポート
    func exportData() throws -> Data {
        guard FileManager.default.fileExists(atPath: weightsFile.path) else {
            return Data()
        }
        return try Data(contentsOf: weightsFile)
    }
    
    func importData(_ data: Data) throws {
        // データを検証
        let _ = try JSONDecoder().decode([WeightEntry].self, from: data)
        
        // データを保存
        try data.write(to: weightsFile, options: .atomic)
    }
    
    // MARK: - 統計
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

// MARK: - エラータイプ
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

// MARK: - 統計モデル
struct WeightStatistics {
    let totalEntries: Int
    let averageWeight: Double?
    let minWeight: Double?
    let maxWeight: Double?
    let averageBodyFat: Double?
    let firstEntryDate: Date?
    let lastEntryDate: Date?
}
