import Foundation
import CloudKit

enum CloudBackupStoreError: Error, Equatable {
    /// 目録を読んだ後に、別の端末が目録を書き換えた
    case manifestChanged
    case notFound
}

/// バックアップの置き場。本番は CloudKit、テストはメモリ上の偽物に差し替える
protocol CloudBackupStore: AnyObject {
    /// 置き場 (ゾーン) を用意する。何度呼んでもよい
    func prepare() async throws
    func fetchSnapshot() async throws -> CloudBackupPlanner.CloudSnapshot
    /// 渡した名前のうち、クラウドにあるもの
    func existingMediaRecordNames(among names: [String]) async throws -> Set<String>
    func uploadMedia(_ items: [(recordName: String, fileURL: URL)]) async throws
    /// 目録を保存し、新しい recordChangeTag を返す。expectedTag が今のクラウドの tag と違えば manifestChanged を投げる
    func saveManifest(fileURL: URL, createdAt: Date, expectedTag: String?) async throws -> String
    /// 目録を destination へ落とし、その recordChangeTag を返す
    func downloadManifest(to destination: URL) async throws -> String
    /// 写真・動画を落とす。クラウドに無かったレコード名を返す
    func downloadMedia(_ items: [(recordName: String, destination: URL)]) async throws -> [String]
    func deleteMedia(recordNames: [String]) async throws
    func downloadLegacy(to destination: URL) async throws
    func deleteLegacy() async throws
}

/// CloudKit のプライベート DB に置く。本番のスキーマを変えないよう、既存のレコード型 `Backup` と
/// フィールド `bundle` (Asset)・`createdAt` (Date) だけを使う。新形式はカスタムゾーンに置く
final class CloudKitBackupStore: CloudBackupStore {
    static let recordType = "Backup"
    static let assetKey = "bundle"
    static let createdAtKey = "createdAt"
    static let zoneName = "BodyLapseBackup"
    static let manifestRecordName = "manifest"
    static let legacyRecordName = "latest-backup"

    private let database: CKDatabase
    private let zoneID = CKRecordZone.ID(zoneName: CloudKitBackupStore.zoneName, ownerName: CKCurrentUserDefaultName)
    private var zoneReady = false
    /// 最後に読んだ目録 (保存のときに変更の検出に使う)
    private var lastFetchedManifest: CKRecord?

    /// 1 回の操作に載せる件数 (CloudKit の上限 400 より十分小さく)
    private let uploadBatchSize = 8
    private let fetchBatchSize = 50
    private let deleteBatchSize = 200

    init(database: CKDatabase) {
        self.database = database
    }

    private var manifestID: CKRecord.ID {
        CKRecord.ID(recordName: Self.manifestRecordName, zoneID: zoneID)
    }

    private var legacyID: CKRecord.ID {
        CKRecord.ID(recordName: Self.legacyRecordName)
    }

    private func mediaID(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    func prepare() async throws {
        guard !zoneReady else { return }
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        zoneReady = true
    }

    /// 1 件読む。無ければ nil (ゾーンが無いときも nil)
    private func fetchRecord(_ id: CKRecord.ID, desiredKeys: [CKRecord.FieldKey]?) async throws -> CKRecord? {
        do {
            let results = try await database.records(for: [id], desiredKeys: desiredKeys)
            switch results[id] {
            case .success(let record):
                return record
            case .failure(let error):
                if Self.isMissing(error) { return nil }
                throw error
            case nil:
                return nil
            }
        } catch {
            if Self.isMissing(error) { return nil }
            throw error
        }
    }

    private static func isMissing(_ error: Error) -> Bool {
        guard let ckError = error as? CKError else { return false }
        return ckError.code == .unknownItem || ckError.code == .zoneNotFound
    }

    func fetchSnapshot() async throws -> CloudBackupPlanner.CloudSnapshot {
        let manifest = try await fetchRecord(manifestID, desiredKeys: [Self.createdAtKey])
        lastFetchedManifest = manifest
        let legacy = try await fetchRecord(legacyID, desiredKeys: [Self.createdAtKey])
        return CloudBackupPlanner.CloudSnapshot(
            manifestTag: manifest?.recordChangeTag,
            manifestCreatedAt: manifest?[Self.createdAtKey] as? Date,
            legacyBackupDate: legacy.map { ($0[Self.createdAtKey] as? Date) ?? Date.distantPast }
        )
    }

    func existingMediaRecordNames(among names: [String]) async throws -> Set<String> {
        var existing = Set<String>()
        for batch in names.chunked(into: fetchBatchSize) {
            let ids = batch.map(mediaID)
            do {
                let results = try await database.records(for: ids, desiredKeys: [Self.createdAtKey])
                for (id, result) in results {
                    if case .success = result {
                        existing.insert(id.recordName)
                    }
                }
            } catch {
                if Self.isMissing(error) { continue }
                throw error
            }
        }
        return existing
    }

    func uploadMedia(_ items: [(recordName: String, fileURL: URL)]) async throws {
        for batch in items.chunked(into: uploadBatchSize) {
            let records = batch.map { item -> CKRecord in
                let record = CKRecord(recordType: Self.recordType, recordID: mediaID(item.recordName))
                record[Self.assetKey] = CKAsset(fileURL: item.fileURL)
                record[Self.createdAtKey] = Date()
                return record
            }
            let results = try await database.modifyRecords(
                saving: records,
                deleting: [],
                savePolicy: .allKeys,
                atomically: false
            ).saveResults
            for record in records {
                if case .failure(let error)? = results[record.recordID] {
                    throw error
                }
            }
        }
    }

    func saveManifest(fileURL: URL, createdAt: Date, expectedTag: String?) async throws -> String {
        let record: CKRecord
        if let expectedTag {
            var server = lastFetchedManifest
            if server?.recordChangeTag != expectedTag {
                server = try await fetchRecord(manifestID, desiredKeys: [Self.createdAtKey])
            }
            guard let server, server.recordChangeTag == expectedTag else {
                throw CloudBackupStoreError.manifestChanged
            }
            record = server
        } else {
            record = CKRecord(recordType: Self.recordType, recordID: manifestID)
        }
        record[Self.assetKey] = CKAsset(fileURL: fileURL)
        record[Self.createdAtKey] = createdAt

        do {
            let results = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .ifServerRecordUnchanged,
                atomically: true
            ).saveResults
            switch results[record.recordID] {
            case .success(let saved):
                lastFetchedManifest = saved
                return saved.recordChangeTag ?? ""
            case .failure(let error):
                throw Self.mapSaveError(error)
            case nil:
                throw CloudBackupStoreError.notFound
            }
        } catch let error as CloudBackupStoreError {
            throw error
        } catch {
            throw Self.mapSaveError(error)
        }
    }

    private static func mapSaveError(_ error: Error) -> Error {
        if let ckError = error as? CKError, ckError.code == .serverRecordChanged {
            return CloudBackupStoreError.manifestChanged
        }
        return error
    }

    func downloadManifest(to destination: URL) async throws -> String {
        guard let record = try await fetchRecord(manifestID, desiredKeys: nil),
              let asset = record[Self.assetKey] as? CKAsset,
              let assetURL = asset.fileURL else {
            throw CloudBackupStoreError.notFound
        }
        try Self.copyReplacing(from: assetURL, to: destination)
        lastFetchedManifest = record
        return record.recordChangeTag ?? ""
    }

    func downloadMedia(_ items: [(recordName: String, destination: URL)]) async throws -> [String] {
        var missing: [String] = []
        for batch in items.chunked(into: fetchBatchSize) {
            let ids = batch.map { mediaID($0.recordName) }
            let results = try await database.records(for: ids, desiredKeys: [Self.assetKey])
            for item in batch {
                switch results[mediaID(item.recordName)] {
                case .success(let record):
                    guard let asset = record[Self.assetKey] as? CKAsset, let url = asset.fileURL else {
                        missing.append(item.recordName)
                        continue
                    }
                    try Self.copyReplacing(from: url, to: item.destination)
                case .failure(let error):
                    if Self.isMissing(error) {
                        missing.append(item.recordName)
                    } else {
                        throw error
                    }
                case nil:
                    missing.append(item.recordName)
                }
            }
        }
        return missing
    }

    func deleteMedia(recordNames: [String]) async throws {
        for batch in recordNames.chunked(into: deleteBatchSize) {
            _ = try await database.modifyRecords(
                saving: [],
                deleting: batch.map(mediaID),
                savePolicy: .allKeys,
                atomically: false
            )
        }
    }

    func downloadLegacy(to destination: URL) async throws {
        guard let record = try await fetchRecord(legacyID, desiredKeys: nil),
              let asset = record[Self.assetKey] as? CKAsset,
              let assetURL = asset.fileURL else {
            throw CloudBackupStoreError.notFound
        }
        try Self.copyReplacing(from: assetURL, to: destination)
    }

    func deleteLegacy() async throws {
        _ = try await database.modifyRecords(saving: [], deleting: [legacyID], savePolicy: .allKeys, atomically: false)
    }

    private static func copyReplacing(from source: URL, to destination: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        // CKAsset のファイルは一時的なので、取り込みが終わるまで残る場所へ写す
        try fileManager.copyItem(at: source, to: destination)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
