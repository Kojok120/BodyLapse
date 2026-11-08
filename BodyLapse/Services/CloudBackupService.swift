import Foundation
import CloudKit
import Network

/// Pro限定のクラウドバックアップ（CloudKitプライベートDB）。
/// 写真・動画は 1 ファイル 1 レコードにして、まだ上げていない分だけを上げる。小さなデータは目録 1 件にまとめる。
/// 別の端末やまっさらな端末から黙って上書きしないよう、どのバックアップの続きかを端末に覚える (CloudBackupPlanner)。
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
    /// クラウドに別のバックアップがあり、自動バックアップを止めているとき、その理由
    @Published private(set) var pendingDecision: CloudBackupPlanner.Decision.Reason?
    /// まっさらな端末で、クラウドにバックアップがあると分かったとき (一度だけ復元を案内する)
    @Published var shouldSuggestRestore = false

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
    private static let localStateKey = "cloud_backup_local_state_v2"
    private static let restoreSuggestedKey = "cloud_backup_restore_suggested"

    /// 自動バックアップの最小間隔。厳密な24時間だと撮影時刻の日々の揺らぎで1日飛ぶため20時間。
    static let autoBackupMinInterval: TimeInterval = 20 * 60 * 60

    private let containerID = "iCloud.com.J.BodyLapse"
    private lazy var container = CKContainer(identifier: containerID)
    private lazy var store: CloudBackupStore = CloudKitBackupStore(database: container.privateCloudDatabase)
    private var engine: CloudBackupEngine { CloudBackupEngine(store: store) }

    /// 実行中か。最初の await より前に立て、撮影が続いても同時に複数走らせない
    private var isRunning = false

    private var localState: CloudBackupPlanner.LocalState {
        get {
            guard let data = UserDefaults.standard.data(forKey: Self.localStateKey),
                  let state = try? JSONDecoder().decode(CloudBackupPlanner.LocalState.self, from: data) else {
                return CloudBackupPlanner.LocalState()
            }
            return state
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: Self.localStateKey)
            }
        }
    }

    private init() {
        // 新規撮影後の自動バックアップ。savePhoto は userInfo["photo"] 付きで
        // PhotosUpdated を投げる（復元・再読込・取り込みは userInfo なし）ので、それだけに反応する。
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

    private var workDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("CloudBackupWork", isDirectory: true)
    }

    private var localEarliestPhotoDate: Date? {
        PhotoStorageService.shared.photos.map(\.captureDate).min()
    }

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
        if let backupError = error as? CloudBackupError {
            switch backupError {
            case .needsDecision:
                return "cloud.error.needs_decision".localized
            case .conflict:
                return "cloud.error.conflict".localized
            case .noBackup:
                return "cloud.error.no_backup".localized
            case .invalidBackup:
                return "cloud.error.invalid_backup".localized
            }
        }
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

    /// クラウドの状態を読み、最終バックアップの日時と、止めている理由を更新する
    func refreshStatus() async {
        guard await accountUnavailableMessage() == nil,
              let snapshot = try? await store.fetchSnapshot() else {
            return
        }
        lastBackupDate = snapshot.latestBackupDate
        let decision = CloudBackupPlanner.decide(
            cloud: snapshot,
            local: localState,
            localEarliestPhotoDate: localEarliestPhotoDate,
            force: false
        )
        if case .needsDecision(let reason) = decision {
            pendingDecision = reason
        } else {
            pendingDecision = nil
        }
    }

    /// Pro の人がまっさらな端末で使い始めたとき、クラウドにバックアップがあれば一度だけ復元を案内する
    func checkRestoreSuggestion() async {
        guard SubscriptionManagerService.shared.canAccessCloudBackup(),
              !UserDefaults.standard.bool(forKey: Self.restoreSuggestedKey) else { return }
        await refreshStatus()
        guard pendingDecision != nil else { return }
        UserDefaults.standard.set(true, forKey: Self.restoreSuggestedKey)
        shouldSuggestRestore = true
    }

    /// 現在のデータをクラウドへ上げる。replaceCloudBackup は「この端末の内容で置き換える」を選んだとき
    func backupNow(replaceCloudBackup: Bool = false) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        state = .working
        if let message = await accountUnavailableMessage() {
            state = .failure(message)
            Haptics.error()
            return
        }

        do {
            try await upload(force: replaceCloudBackup)
            state = .success
            Haptics.success()
        } catch CloudBackupError.needsDecision(let reason) {
            pendingDecision = reason
            state = .idle
        } catch {
            print("[CloudBackup] backup failed: \(error)")
            state = .failure(userMessage(for: error))
            Haptics.error()
        }
    }

    /// 書き出しと同じ中身を作り、差分を上げる共通処理
    private func upload(force: Bool) async throws {
        let options = ImportExportService.ExportOptions(
            includePhotos: true,
            includeVideos: includeVideos,
            // アプリの設定は端末ごとに持つ (復元でも取り込まない) ので、上げない
            includeSettings: false,
            includeWeightData: true,
            includeNotes: true,
            dateRange: nil,
            categories: nil
        )
        let entries = try await ImportExportService.shared.makeExportEntries(options: options)
        defer { try? FileManager.default.removeItem(at: workDirectory) }

        let outcome = try await engine.backup(
            entries: entries,
            local: localState,
            localEarliestPhotoDate: localEarliestPhotoDate,
            force: force,
            workDirectory: workDirectory,
            persist: { [weak self] state in self?.localState = state }
        )
        localState = outcome.state
        pendingDecision = nil
        lastBackupDate = Date()
        print("[CloudBackup] uploaded \(outcome.uploadedCount), deleted \(outcome.deletedCount)")
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
              !isRunning,
              state != .working else { return }
        // 待ちや問い合わせの前に印を立てる (この間に来た通知で二重に走らせない)
        isRunning = true
        defer { isRunning = false }

        // 撮影直後の保存・画面遷移と競合しないよう少し待ってから始める
        try? await Task.sleep(nanoseconds: 5_000_000_000)

        // 起動後まだクラウドの日時を取得していない場合は先に取得（不要な連続実行を防ぐ）
        if lastBackupDate == nil {
            await refreshStatus()
        }
        guard Self.shouldAutoBackup(now: Date(), lastBackup: lastBackupDate) else { return }

        // モバイル回線では実行しない（動画込みだと大きくなり得る）
        guard await !isNetworkExpensive() else { return }
        guard await accountUnavailableMessage() == nil else { return }

        state = .working
        do {
            try await upload(force: false)
        } catch CloudBackupError.needsDecision(let reason) {
            // クラウドに別のバックアップがある: 上書きせず、設定の画面で選んでもらう
            pendingDecision = reason
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
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        state = .working
        if let message = await accountUnavailableMessage() {
            state = .failure(message)
            Haptics.error()
            return
        }

        do {
            defer { try? FileManager.default.removeItem(at: workDirectory) }
            let outcome = try await engine.restore(local: localState, workDirectory: workDirectory)

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
            _ = try await ImportExportService.shared.importExtractedBundle(
                at: outcome.extractedDirectory,
                options: options,
                progress: { _ in }
            )
            localState = outcome.state
            pendingDecision = nil
            if outcome.missingMediaCount > 0 {
                print("[CloudBackup] \(outcome.missingMediaCount) media files were missing in the cloud")
            }

            // データ再読み込みを各画面へ通知
            // 体重同期が完了してから通知する（完了前にPhotosUpdatedを出すと一時的に体重が欠ける）
            PhotoStorageService.shared.reloadPhotosFromDisk(syncWeightData: false)
            await PhotoStorageService.shared.syncWeightData()
            NotificationCenter.default.post(name: Notification.Name("PhotosUpdated"), object: nil)

            await refreshStatus()
            state = .success
            Haptics.success()
        } catch {
            state = .failure(userMessage(for: error))
            Haptics.error()
        }
    }
}
