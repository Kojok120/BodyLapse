import UIKit

/// アプリ全体で一貫した触覚フィードバックを提供する共通ヘルパー。
/// 重要な操作（保存・生成完了・エラーなど）に統一した手触りを与える。
///
/// `UIFeedbackGenerator` 系はメインスレッドからの使用が必須のため、
/// 呼び出し元のスレッドに関わらず内部で必ずメインスレッドで実行する。
enum Haptics {
    /// 成功（写真保存・体重確定・動画生成完了など）
    static func success() {
        runOnMain {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        }
    }

    /// 警告（入力不備・処理中断など）
    static func warning() {
        runOnMain {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        }
    }

    /// 失敗（保存失敗・致命的エラーなど）
    static func error() {
        runOnMain {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.error)
        }
    }

    /// 軽い衝撃（ボタンタップ・ページ切替など）
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        runOnMain {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        }
    }

    /// 選択変更
    static func selection() {
        runOnMain {
            let generator = UISelectionFeedbackGenerator()
            generator.prepare()
            generator.selectionChanged()
        }
    }

    /// メインスレッドで実行する（既にメインなら同期、そうでなければ非同期ディスパッチ）。
    private static func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
