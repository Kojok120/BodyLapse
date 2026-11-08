import Foundation

actor WeightStorageService {
    static let shared = WeightStorageService()

    enum MergeStrategy {
        case skipExisting
        case replaceExisting
    }
    
    private let documentsDirectory: URL
    private let weightsDirectory: URL
    private let weightsFile: URL
    /// アプリで消した日と消した時刻。ヘルスケアの同期で消した値を書き戻さないために使う
    private var deletedDaysFile: URL {
        weightsDirectory.appendingPathComponent("deleted_days.json")
    }

    /// 日の識別子 (端末の暦とタイムゾーンでの yyyy-MM-dd)
    nonisolated static func dayKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
    
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
        try clearDeletionMark(for: entry.date)
        print("[WeightStorage] Total entries after save: \(entries.count)")
    }
    
    // MARK: - エントリ削除
    /// 指定日の記録をすべて消す (同じ日に複数あっても残さない)。
    func deleteEntries(on date: Date, deletedAt: Date = Date()) throws {
        var entries = try loadEntries()
        let before = entries.count
        entries.removeAll { Calendar.current.isDate($0.date, inSameDayAs: date) }
        if entries.count != before {
            try saveEntries(entries)
        }
        var deleted = try deletedDays()
        deleted[Self.dayKey(for: date)] = deletedAt
        try saveDeletedDays(deleted)
    }

    /// アプリで消した日 (yyyy-MM-dd) と消した時刻
    func deletedDays() throws -> [String: Date] {
        guard FileManager.default.fileExists(atPath: deletedDaysFile.path) else { return [:] }
        let data = try Data(contentsOf: deletedDaysFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([String: Date].self, from: data)
    }

    private func saveDeletedDays(_ days: [String: Date]) throws {
        try FileManager.default.createDirectory(at: weightsDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(days).write(to: deletedDaysFile, options: .atomic)
    }

    private func clearDeletionMark(for date: Date) throws {
        var deleted = try deletedDays()
        guard deleted.removeValue(forKey: Self.dayKey(for: date)) != nil else { return }
        try saveDeletedDays(deleted)
    }
    
    // MARK: - 日付別エントリ取得
    func getEntry(for date: Date) throws -> WeightEntry? {
        let entries = try loadEntries()
        return entries.first { 
            Calendar.current.isDate($0.date, inSameDayAs: date) 
        }
    }

    // MARK: - バッチマージ
    func mergeEntries(_ incomingEntries: [WeightEntry], strategy: MergeStrategy) throws -> Int {
        guard !incomingEntries.isEmpty else { return 0 }

        var entries = try loadEntries()
        let calendar = Calendar.current

        var indexByDay: [Date: Int] = [:]
        for (index, existingEntry) in entries.enumerated() {
            let day = calendar.startOfDay(for: existingEntry.date)
            if indexByDay[day] == nil {
                indexByDay[day] = index
            }
        }

        var importedCount = 0

        for entry in incomingEntries {
            let entryDay = calendar.startOfDay(for: entry.date)

            switch strategy {
            case .skipExisting:
                guard indexByDay[entryDay] == nil else { continue }
                entries.append(entry)
                indexByDay[entryDay] = entries.count - 1
                importedCount += 1

            case .replaceExisting:
                if let existingIndex = indexByDay[entryDay] {
                    entries[existingIndex] = entry
                } else {
                    entries.append(entry)
                    indexByDay[entryDay] = entries.count - 1
                }
                importedCount += 1
            }
        }

        if importedCount > 0 {
            entries.sort { $0.date > $1.date }
            try saveEntries(entries)
        }

        return importedCount
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
        // ディレクトリが（データ消去などで）失われていても保存できるようにする
        try FileManager.default.createDirectory(
            at: weightsDirectory,
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(entries)
        try data.write(to: weightsFile, options: .atomic)
        print("[WeightStorage] Saved \(entries.count) entries to file")
    }
}

// MARK: - エラータイプ
enum WeightStorageError: LocalizedError {
    case entryNotFound
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .entryNotFound:
            return "error.weight.not_found".localized
        case .invalidData:
            return "error.weight.invalid_data".localized
        }
    }
}
