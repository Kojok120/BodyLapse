import UIKit

/// 画面を重ねて出すときの、いちばん上の UIViewController を探す。
/// 目隠し用の UIWindow (PrivacyShieldController) は飛ばし、アプリの画面の窓から探す。
enum PresentingViewController {
    @MainActor
    static func top() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = scene?.windows.first(where: { $0.windowLevel == .normal && !$0.isHidden }),
              var top = window.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
