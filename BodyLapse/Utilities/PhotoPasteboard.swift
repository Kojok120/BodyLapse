import UIKit
import UniformTypeIdentifiers

/// 体の写真をペーストボードに置く。
/// 同じ Apple ID のほかの端末 (ユニバーサルクリップボード) には渡さず、時間がたてば消える。
enum PhotoPasteboard {
    static let lifetime: TimeInterval = 10 * 60

    /// 保存してある JPEG をそのまま置く (縮小したサムネイルや再エンコードの画質にしない)。
    @discardableResult
    static func copy(_ photo: Photo, pasteboard: UIPasteboard = .general, now: Date = Date()) -> Bool {
        guard let url = PhotoStorageService.shared.storedFileURL(for: photo),
              let data = try? Data(contentsOf: url) else {
            return false
        }
        pasteboard.setItems([[UTType.jpeg.identifier: data]], options: options(now: now))
        return true
    }

    static func options(now: Date) -> [UIPasteboard.OptionsKey: Any] {
        [.localOnly: true, .expirationDate: now.addingTimeInterval(lifetime)]
    }
}
