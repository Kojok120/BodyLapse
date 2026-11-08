import SwiftUI
import UIKit

/// アプリスイッチャーやコントロールセンターを開いたとき、画面全体を目隠しで覆う。
///
/// SwiftUI の ZStack に置くと sheet や fullScreenCover はその上に出るため、ギャラリーで開いた写真が
/// スイッチャーに映っていた。専用の UIWindow をいちばん上の階層に出して、提示中の画面ごと覆う。
/// 画面の根元を差し替えても (言語の切り替えなど) 効き続けるよう、SwiftUI の階層の外で通知を購読する。
@MainActor
final class PrivacyShieldController {
    static let shared = PrivacyShieldController()

    private var shieldWindow: UIWindow?
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func start() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default
        // queue: nil で投稿したスレッド (メイン) で同期に実行する。スナップショットより前に覆うため
        observers.append(center.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: nil) { [weak self] notification in
            let scene = notification.object as? UIWindowScene
            MainActor.assumeIsolated { self?.showShield(in: scene) }
        })
        observers.append(center.addObserver(forName: UIScene.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] notification in
            let scene = notification.object as? UIWindowScene
            MainActor.assumeIsolated {
                self?.showShield(in: scene)
                AuthenticationService.shared.lockIfNeeded()
            }
        })
        observers.append(center.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: nil) { [weak self] _ in
            MainActor.assumeIsolated { self?.hideShield() }
        })
    }

    private func showShield(in scene: UIWindowScene?) {
        guard let scene = scene ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else {
            return
        }
        if shieldWindow == nil || shieldWindow?.windowScene !== scene {
            let window = UIWindow(windowScene: scene)
            window.windowLevel = .alert + 1
            let host = UIHostingController(rootView: PrivacyScreenView().ignoresSafeArea())
            host.view.backgroundColor = .clear
            window.rootViewController = host
            shieldWindow = window
        }
        shieldWindow?.isHidden = false
    }

    private func hideShield() {
        shieldWindow?.isHidden = true
    }
}
