import Foundation
import CryptoKit

/// iCloud バックアップで「上げてよいか」「何を上げて何を消すか」を決める純関数
enum CloudBackupPlanner {
    /// 目録の形式。変えたら上げる
    static let indexFormatVersion = 2
    /// 目録の zip の中に置く、写真・動画の一覧のファイル名
    static let indexFileName = "cloud_backup_index.json"

    /// クラウドに 1 件ずつ置く写真・動画
    struct MediaItem: Codable, Equatable, Hashable {
        /// 書き出しの zip の中でのパス (例: photos/default/UUID.jpg)
        let path: String
        let recordName: String
        let size: Int64
    }

    /// 目録の zip に入れる一覧
    struct Index: Codable, Equatable {
        let formatVersion: Int
        let createdAt: Date
        let media: [MediaItem]
    }

    /// クラウドの今の状態 (目録の中身は読まずに分かる範囲)
    struct CloudSnapshot: Equatable {
        /// 新形式の目録の recordChangeTag。無ければ nil
        var manifestTag: String?
        /// 新形式の目録を保存した日時
        var manifestCreatedAt: Date?
        /// 旧形式 (1 つの zip) のバックアップの日時。無ければ nil
        var legacyBackupDate: Date?

        /// いちばん新しいバックアップの日時 (画面の「最終バックアップ」)
        var latestBackupDate: Date? {
            manifestCreatedAt ?? legacyBackupDate
        }

        var hasBackup: Bool {
            manifestTag != nil || legacyBackupDate != nil
        }
    }

    /// この端末が覚えていること (UserDefaults に置く)
    struct LocalState: Codable, Equatable {
        /// 自分が保存した、または復元した目録の recordChangeTag
        var manifestTag: String?
        /// その目録が指している写真・動画
        var media: [MediaItem] = []
        /// 目録の保存より前に上げ終えた写真・動画 (途中で止まっても上げ直さない)
        var uploadedRecordNames: Set<String> = []
        /// 復元または上書きを選んで、続きとして扱うと決めた旧形式のバックアップの日時
        var acknowledgedLegacyBackupDate: Date?
    }

    enum Decision: Equatable {
        case proceed
        /// クラウドに別の端末 (またはこの端末の以前) のバックアップがあり、黙って上書きすると消えてしまう
        case needsDecision(Reason)

        enum Reason: Equatable {
            /// 新形式の目録を最後に保存したのはこの端末ではない
            case otherBackup
            /// 旧形式のバックアップがあり、この端末がその続きだと分からない
            case legacyBackup
        }
    }

    /// クラウドへ上げてよいか。force は「この端末の内容で置き換える」を選んだとき
    static func decide(
        cloud: CloudSnapshot,
        local: LocalState,
        localEarliestPhotoDate: Date?,
        force: Bool
    ) -> Decision {
        if force { return .proceed }

        if let cloudTag = cloud.manifestTag {
            return local.manifestTag == cloudTag ? .proceed : .needsDecision(.otherBackup)
        }

        // 新形式の目録が無い
        guard let legacyDate = cloud.legacyBackupDate else {
            return .proceed // 初めてのバックアップ (または以前のものが消された)
        }
        if local.acknowledgedLegacyBackupDate == legacyDate {
            return .proceed
        }
        // 旧形式の日時より前の写真が端末にある = 同じ端末で使い続けている
        if let earliest = localEarliestPhotoDate, earliest < legacyDate {
            return .proceed
        }
        return .needsDecision(.legacyBackup)
    }

    /// 写真・動画のパスからレコード名を決める (同じパスはいつも同じ名前。ファイル名は UUID なので中身も同じ)
    static func recordName(forMediaPath path: String) -> String {
        let digest = SHA256.hash(data: Data(path.utf8))
        return "m-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    /// まだ上げていない写真・動画
    static func mediaToUpload(current: [MediaItem], alreadyUploaded: Set<String>) -> [MediaItem] {
        current.filter { !alreadyUploaded.contains($0.recordName) }
    }

    /// 新しい目録が指さなくなった写真・動画のレコード (目録の保存が成功してから消す)
    static func recordsToDelete(previous: [MediaItem], current: [MediaItem]) -> [String] {
        let keep = Set(current.map(\.recordName))
        return Array(Set(previous.map(\.recordName)).subtracting(keep)).sorted()
    }
}
