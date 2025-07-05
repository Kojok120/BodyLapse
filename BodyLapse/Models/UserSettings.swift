import Foundation

struct UserSettings: Codable {
    var showBodyGuidelines: Bool = true
    var weightUnit: WeightUnit = .kg
    var healthKitEnabled: Bool = false
    
    // Onboarding
    var hasCompletedOnboarding: Bool = false
    
    // Security
    var isAppLockEnabled: Bool = false
    var appLockMethod: AppLockMethod = .biometric
    var appPasscode: String?
    
    // App Rating
    var hasRatedApp: Bool = false
    
    // Video Generation
    var showDateInVideo: Bool = true
    
    // Appearance
    var appearanceMode: AppearanceMode = .system
    
    // Debug settings
    #if DEBUG
    var debugAllowPastDatePhotos: Bool = false
    #endif
    
    enum WeightUnit: String, Codable, CaseIterable {
        case kg = "kg"
        case lbs = "lbs"
        
        var symbol: String {
            switch self {
            case .kg: return "kg"
            case .lbs: return "lbs"
            }
        }
    }
    
    enum AppLockMethod: String, Codable {
        case biometric = "Face ID / Touch ID"
        case passcode = "Passcode"
    }
    
    enum AppearanceMode: String, Codable, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light:
                return "settings.appearance_light".localized
            case .dark:
                return "settings.appearance_dark".localized
            case .system:
                return "settings.appearance_system".localized
            }
        }
    }
}

extension UserSettings {
    static let `default` = UserSettings()
}

@MainActor
class UserSettingsManager: ObservableObject {
    static let shared = UserSettingsManager()
    @Published var settings: UserSettings {
        didSet {
            save()
            handleSettingsChange(oldValue: oldValue)
        }
    }
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "BodyLapseUserSettings"
    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = UserSettings.default
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    private func handleSettingsChange(oldValue: UserSettings) {
        // Handle settings changes if needed
        if oldValue.appearanceMode != settings.appearanceMode {
            AppearanceManager.shared.syncWithSettings()
        }
    }
}

extension Notification.Name {
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}