import SwiftUI

@MainActor
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()
    
    @Published var currentAppearance: UserSettings.AppearanceMode {
        didSet {
            UserSettingsManager.shared.settings.appearanceMode = currentAppearance
            applyAppearance()
        }
    }
    
    private init() {
        self.currentAppearance = UserSettingsManager.shared.settings.appearanceMode
        applyAppearance()
    }
    
    func applyAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }
        
        let userInterfaceStyle: UIUserInterfaceStyle
        
        switch currentAppearance {
        case .light:
            userInterfaceStyle = .light
        case .dark:
            userInterfaceStyle = .dark
        case .system:
            userInterfaceStyle = .unspecified
        }
        
        // シーン内の全ウィンドウに適用
        windowScene.windows.forEach { window in
            window.overrideUserInterfaceStyle = userInterfaceStyle
        }
    }
    
    // 設定が読み込まれたか外部から変更された場合に呼び出す
    func syncWithSettings() {
        currentAppearance = UserSettingsManager.shared.settings.appearanceMode
        applyAppearance()
    }
}