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
        
        // Apply to all windows in the scene
        windowScene.windows.forEach { window in
            window.overrideUserInterfaceStyle = userInterfaceStyle
        }
    }
    
    // Call this when settings are loaded or changed externally
    func syncWithSettings() {
        currentAppearance = UserSettingsManager.shared.settings.appearanceMode
        applyAppearance()
    }
}