import Foundation
import CloudKit
import Network

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

    /// バックアップに動画を含めるか（デフォルトON）。
    /// 動画は容量が大きく iCloud クォータを圧迫し得るため、
    /// 空き容量が足りないユーザー向けにオフにする逃げ道を残す。
    @Published var includeVideos: Bool = UserDefaults.standard.object(forKey: includeVideosKey) as? Bool ?? true {
        didSet { UserDefaults.standard.set(includeVideos, forKey: Self.includeVideosKey) }
    }
    private static let includeVideosKey = "cloud_backup_include_videos"

    /// 自動バックアップ（デフォルトON）。新しい写真の保存後、1日1回・Wi-Fi接続時のみ静かに実行する。
    @Published var autoBackupEnabled: Bool = UserDefaults.standard.object(forKey: autoBackupKey) as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoBackupEnabled, forKey: Self.autoBackupKey) }
    }
    private static let autoBackupKey = "cloud_backup_auto_enabled"

    /// 自動バックアップの最小間隔。厳密な24時間だと撮影時刻の日々の揺らぎで1日飛ぶため20時間。
    static let autoBackupMinInterval: TimeInterval = 20 * 60 * 60

    private let containerID = "iCloud.com.J.BodyLapse"
    private let recordType = "Backup"
    private let recordName = "latest-backup"
    private let assetKey = "bundle"
    private let createdAtKey = "createdAt"

    private lazy var container = CKContainer(identifier: containerID)
    private var database: CKDatabase { container.privateCloudDatabase }
    private var recordID: CKRecord.ID { CKRecord.ID(recordName: recordName) }

    private init() {
        // 新規撮影後の自動バックアップ。savePhoto は userInfo["photo"] 付きで
        // PhotosUpdated を投げる（復元・再読込は userInfo なし）ので、それだけに反応する。
        NotificationCenter.default.addObserver(
            forName: Notification.Name("PhotosUpdated"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard notification.userInfo?["photo"] != nil else { return }
            Task { @MainActor [weak self] in
                await self?.autoBackupIfNeeded()
            }
        }
    }

    /// アプリ起動時に呼び、シングルトンを生成して通知購読を開始させる。
    func activate() {}

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
            try await uploadCurrentData()
            state = .success
            Haptics.success()
        } catch {
            print("[CloudBackup] backup failed: \(error)")
            state = .failure(userMessage(for: error))
            Haptics.error()
        }
    }

    /// 現在のデータをエクスポートしてクラウドへアップロードする共通処理。
    private func uploadCurrentData() async throws {
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
    }

    // MARK: - 自動バックアップ

    /// 前回バックアップから十分な時間が経過しているか（純粋関数・ユニットテスト対象）。
    nonisolated static func shouldAutoBackup(now: Date, lastBackup: Date?) -> Bool {
        guard let lastBackup else { return true }
        return now.timeIntervalSince(lastBackup) >= autoBackupMinInterval
    }

    /// 新規撮影後に呼ばれる。Pro・設定ON・間隔・Wi-Fi・アカウントの条件を
    /// すべて満たす場合のみ、アラートやハプティクスなしで静かにバックアップする。
    func autoBackupIfNeeded() async {
        guard autoBackupEnabled,
              SubscriptionManagerService.shared.canAccessCloudBackup(),
              state != .working else { return }

        // 撮影直後の保存・画面遷移と競合しないよう少し待ってから始める
        try? await Task.sleep(nanoseconds: 5_000_000_000)
        guard state != .working else { return }

        // 起動後まだクラウドの日時を取得していない場合は先に取得（不要な連続実行を防ぐ）
        if lastBackupDate == nil {
            await refreshLastBackupDate()
        }
        guard Self.shouldAutoBackup(now: Date(), lastBackup: lastBackupDate) else { return }

        // モバイル回線では実行しない（動画込みのバンドルは大きくなり得る）
        guard await !isNetworkExpensive() else { return }
        guard await accountUnavailableMessage() == nil else { return }

        state = .working
        do {
            try await uploadCurrentData()
        } catch {
            // 自動実行では撮影フローを邪魔しない：失敗はログのみ（次の撮影時に再試行される）
            print("[CloudBackup] auto backup failed: \(error)")
        }
        state = .idle
    }

    /// 現在のネットワーク経路が従量制（モバイル回線など）かどうか。
    private nonisolated func isNetworkExpensive() async -> Bool {
        await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            var resumed = false
            monitor.pathUpdateHandler = { path in
                // ハンドラは指定キュー上で直列に呼ばれるため、フラグで一度きりの resume を保証
                guard !resumed else { return }
                resumed = true
                monitor.cancel()
                continuation.resume(returning: path.isExpensive)
            }
            monitor.start(queue: DispatchQueue(label: "com.bodylapse.cloudbackup.network"))
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
        // 動画は容量が大きく iCloud クォータ超過(quotaExceeded)の主因になるため、
        // ユーザーがトグルで除外できるようにしている（既定は含める）。
        let options = ImportExportService.ExportOptions(
            includePhotos: true,
            includeVideos: includeVideos,
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
