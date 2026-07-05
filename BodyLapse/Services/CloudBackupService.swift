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

    /// iCloudアカウントが利用可能ならnil、不可なら理由メッセージを返す。
    private func accountUnavailableMessage() async -> String? {
        do {
            switch try await container.accountStatus() {
            case .available:
                return nil
            case .noAccount:
                return "cloud.error.no_account".localized
            case .restricted:
                return "cloud.error.restricted".localized
            case .couldNotDetermine, .temporarilyUnavailable:
                return "cloud.error.unavailable".localized
            @unknown default:
                return "cloud.error.unavailable".localized
            }
        } catch {
            return userMessage(for: error)
        }
    }

    /// CloudKitのエラーをユーザー向けの具体的な文言に変換する。
    private func userMessage(for error: Error) -> String {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .notAuthenticated:
                return "cloud.error.no_account".localized
            case .networkUnavailable, .networkFailure:
                return "cloud.error.network".localized
            case .quotaExceeded:
                return "cloud.error.quota".localized
            case .unknownItem:
                return "cloud.error.no_backup".localized
            default:
                break
            }
        }
        return "cloud.error.generic".localized
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
        if let message = await accountUnavailableMessage() {
            state = .failure(message)
            Haptics.error()
            return
        }

        do {
            let bundleURL = try await exportBundle()
            defer { try? FileManager.default.removeItem(at: bundleURL) }

            let record = CKRecord(recordType: recordType, recordID: recordID)
            record[assetKey] = CKAsset(fileURL: bundleURL)
            record[createdAtKey] = Date()

            // 既存レコードを上書き保存。
            // private DB のデフォルトゾーンは atomic 非対応なので atomically: false。
            let saveResults = try await database.modifyRecords(
                saving: [record],
                deleting: [],
                savePolicy: .allKeys,
                atomically: false
            ).saveResults

            // 個別レコードの保存結果を検証（部分失敗を「完了」と誤判定しないため）
            if case .failure(let recordError)? = saveResults[record.recordID] {
                throw recordError
            }

            await refreshLastBackupDate()
            state = .success
            Haptics.success()
        } catch {
            print("[CloudBackup] backup failed: \(error)")
            state = .failure(userMessage(for: error))
            Haptics.error()
        }
    }

    /// クラウドの最新バックアップから復元する。
    func restoreFromCloud() async {
        state = .working
        if let message = await accountUnavailableMessage() {
            state = .failure(message)
            Haptics.error()
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
            // 体重同期が完了してから通知する（完了前にPhotosUpdatedを出すと一時的に体重が欠ける）
            PhotoStorageService.shared.reloadPhotosFromDisk(syncWeightData: false)
            await PhotoStorageService.shared.syncWeightData()
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)

            state = .success
            Haptics.success()
        } catch {
            state = .failure(userMessage(for: error))
            Haptics.error()
        }
    }

    // MARK: - 既存のエクスポート/インポートをasyncでラップ

    private func exportBundle() async throws -> URL {
        // クラウドバックアップは容量の大きい動画を除外する。
        // 動画は写真から再生成できる派生物であり、iCloudクォータ超過(quotaExceeded)を避けるため
        // かけがえのないデータ（写真・体重・メモ・設定・カテゴリ）のみをバックアップする。
        let options = ImportExportService.ExportOptions(
            includePhotos: true,
            includeVideos: false,
            includeSettings: true,
            includeWeightData: true,
            includeNotes: true,
            dateRange: nil,
            categories: nil
        )
        return try await withCheckedThrowingContinuation { continuation in
            ImportExportService.shared.exportData(
                options: options,
                progress: { _ in }
            ) { result in
                continuation.resume(with: result)
            }
        }
    }

    private func importBundle(from url: URL) async throws -> ImportExportService.ImportSummary {
        // 「クラウドから復元」はバックアップを正とする操作なので .replace で上書きする
        // （.skip だと既存データのある端末で同日データが取り込まれず部分復元になる）。
        // 端末ローカルの設定/セキュリティは保持するため importSettings は false。
        let options = ImportExportService.ImportOptions(
            mergeStrategy: .replace,
            importPhotos: true,
            importVideos: true,
            importSettings: false,
            importWeightData: true,
            importNotes: true
        )
        return try await withCheckedThrowingContinuation { continuation in
            ImportExportService.shared.importData(
                from: url,
                options: options,
                progress: { _ in }
            ) { result in
                continuation.resume(with: result)
            }
        }
    }
}
