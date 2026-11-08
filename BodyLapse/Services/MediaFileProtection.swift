import Foundation

/// 写真・動画・サムネイルのファイル保護を強める。
///
/// 既定 (初回のロック解除まで保護) のままだと、再起動のあと一度ロックを解除した端末は、
/// ロック中でもファイルを読み出せる。体の写真なので、ロック中は新しく開けない
/// `completeUnlessOpen` にする (開いていたファイルは、ロックの直後も読み書きを続けられる)。
///
/// 体重・メモ・目録などの JSON は対象にしない。読み直して書き戻す作りなので、
/// ロック中に読めないと空として上書きするおそれがある (データ整合性を優先する)。
enum MediaFileProtection {
    static let protection: FileProtectionType = .completeUnlessOpen
    static let writingOptions: Data.WritingOptions = .completeFileProtectionUnlessOpen

    /// 既存のファイルに一度だけ当てる。上げたら数字を増やす
    static let migrationVersion = 1
    static let migrationVersionKey = "MediaFileProtectionVersion"

    /// ファイル 1 つに当てる。保存・コピー・移動の直後に呼ぶ
    static func apply(to url: URL, fileManager: FileManager = .default) {
        do {
            try fileManager.setAttributes([.protectionKey: protection], ofItemAtPath: url.path)
        } catch {
            print("[MediaFileProtection] Failed to protect \(url.lastPathComponent): \(error)")
        }
    }

    /// フォルダとその中のすべてに当てる。フォルダに当てると、中に新しく作るファイルもこの保護になる
    static func applyRecursively(to directory: URL, fileManager: FileManager = .default) {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        apply(to: directory, fileManager: fileManager)
        guard let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: nil) else { return }
        for case let url as URL in enumerator {
            apply(to: url, fileManager: fileManager)
        }
    }

    /// 起動時に呼ぶ。まだ当てていなければ、写真・動画・サムネイルのフォルダに当てる
    static func migrateIfNeeded(
        directories: [URL],
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        guard defaults.integer(forKey: migrationVersionKey) < migrationVersion else { return }
        for directory in directories {
            applyRecursively(to: directory, fileManager: fileManager)
        }
        defaults.set(migrationVersion, forKey: migrationVersionKey)
    }
}
