import Foundation
import CloudKit

/// Pro限定のクラウドバックアップ（CloudKitプライベートDB）。
/// 既存のエクスポート/インポート（.bodylapseバンドル）を1つのCKAssetとして
/// ユーザー自身のiCloudに保存・復元する。サーバ運用不要・データはユーザーのiCloud内。
@MainActor
class CloudBackupService: ObservableObject {
    static let shared = CloudBackupService()

    enum BackupState: Equatable {
        case idle
        case working
        case success
        case failure(String)
    }

    @Published var state: BackupState = .idle
    @Published var lastBackupDate: Date?

    private let containerID = "iCloud.com.J.BodyLapse"
    private let recordType = "Backup"
    private let recordName = "latest-backup"
    private let assetKey = "bundle"
    private let createdAtKey = "createdAt"

    private lazy var container = CKContainer(identifier: containerID)
    private var database: CKDatabase { container.privateCloudDatabase }
    private var recordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }

    private init() {}

    /// iCloudアカウントが利用可能か（サインイン済みか）。
    func isAccountAvailable() async -> Bool {
        do {
            return try await container.accountStatus() == .available
        } catch {
            return false
        }
    }

    /// 直近のバックアップ日時を取得して `lastBackupDate` を更新する。
    func refreshLastBackupDate() async {
        do {
            let record = try await database.record(for: recordID)
            lastBackupDate = record[createdAtKey] as? Date
        } catch {
            // レコードが無い/取得失敗時はnilのまま（初回など）
            lastBackupDate = nil
        }
    }

    /// 現在のデータをエクスポートしてクラウドにバックアップする。
    func backupNow() async {
        state = .working
        guard await isAccountAvailable() else {
            state = .failure("cloud.error.no_account".localized)
            return
        }

        do {
            let bundleURL = try await exportBundle()
            defer { try? FileManager.default.removeItem(at: bundleURL) }

            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[assetKey] = CKAsset(fileURL: bundleURL)
            record[createdAtKey] = Date()

            // 既存レコードを上書き保存
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)

            await refreshLastBackupDate()
            state = .success
            Haptics.success()
        } catch {
            state = .failure(error.localizedDescription)
            Haptics.error()
        }
    }

    /// クラウドの最新バックアップから復元する。
    func restoreFromCloud() async {
        state = .working
        guard await isAccountAvailable() else {
            state = .failure("cloud.error.no_account".localized)
            return
        }

        do {
            let record = try await database.record(for: recordID)
            guard let asset = record[assetKey] as? CKAsset, let assetURL = asset.fileURL else {
                state = .failure("cloud.error.no_backup".localized)
                return
            }

            // CKAssetのファイルは一時的なので、安全な場所へコピーしてからインポート
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("CloudRestore_\(UUID().uuidString).bodylapse")
            try FileManager.default.copyItem(at: assetURL, to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }

            _ = try await importBundle(from: tempURL)

            // データ再読み込みを各画面へ通知
            PhotoStorageService.shared.reloadPhotosFromDisk()
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)

            state = .success
            Haptics.success()
        } catch {
            state = .failure(error.localizedDescription)
            Haptics.error()
        }
    }

    // MARK: - 既存のエクスポート/インポートをasyncでラップ

    private func exportBundle() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            ImportExportService.shared.exportData(
                options: .all,
                progress: { _ in }
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func importBundle(from url: URL) async throws -> ImportExportService.ImportSummary {
        try await withCheckedThrowingContinuation { continuation in
            ImportExportService.shared.importData(
                from: url,
                options: .default,
                progress: { _ in }
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
}
