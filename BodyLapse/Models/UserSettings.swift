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
    // appPasscode removed - now stored securely in Keychain via AuthenticationService
    
    // App Rating
    var hasRatedApp: Bool = false
    
    // Video Generation
    var showDateInVideo: Bool = true
    
    // Reminder Settings
    var isReminderEnabled: Bool = false
    var reminderHour: Int = 19  // Default to 7 PM (Note: missed photo check is at 9 PM)
    var reminderMinute: Int = 0
    
    // Appearance
    var appearanceMode: AppearanceMode = .system
    
    // Face Blur Settings
    var faceBlurMethod: FaceBlurMethod = .strongBlur
    
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
    
    enum FaceBlurMethod: String, Codable, CaseIterable {
        case strongBlur = "strongBlur"
        case blackout = "blackout"
        
        var displayName: String {
            switch self {
            case .strongBlur:
                return "settings.face_blur_strong".localized
            case .blackout:
                return "settings.face_blur_blackout".localized
            }
        }
        
        var toServiceMethod: FaceBlurService.BlurMethod {
            switch self {
            case .strongBlur:
                return .strongBlur
            case .blackout:
                return .blackout
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
            
            // Migrate password from old UserSettings to AuthenticationService
            migratePasswordIfNeeded()
        } else {
            self.settings = UserSettings.default
        }
    }
    
    private func migratePasswordIfNeeded() {
        // Check if there's an old password stored in UserDefaults that needs migration
        // This handles users upgrading from the old version
        if let oldData = userDefaults.data(forKey: settingsKey),
           let jsonObject = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any],
           let oldPasscode = jsonObject["appPasscode"] as? String,
           !oldPasscode.isEmpty {
            
            // Migrate to AuthenticationService
            if AuthenticationService.shared.setPassword(oldPasscode) {
                AuthenticationService.shared.isAuthenticationEnabled = settings.isAppLockEnabled
                if settings.appLockMethod == .biometric {
                    AuthenticationService.shared.isBiometricEnabled = true
                }
                
                // Remove the old password from UserDefaults by re-saving settings
                save()
            }
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