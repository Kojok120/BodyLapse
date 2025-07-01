import Foundation

struct UserSettings: Codable {
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var showBodyGuidelines: Bool = true
    var weightUnit: WeightUnit = .kg
    var healthKitEnabled: Bool = false
    
    // Onboarding
    var hasCompletedOnboarding: Bool = false
    
    // Security
    var isAppLockEnabled: Bool = false
    var appLockMethod: AppLockMethod = .biometric
    var appPasscode: String?
    
    // Debug settings
    #if DEBUG
    var debugAllowPastDatePhotos: Bool = false
    #endif
    
    enum WeightUnit: String, Codable, CaseIterable {
        case kg = "Kilograms"
        case lbs = "Pounds"
        
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
        // Handle reminder settings change
        if oldValue.reminderEnabled != settings.reminderEnabled ||
           oldValue.reminderTime != settings.reminderTime {
            NotificationService.shared.scheduleOrUpdateDailyReminder(
                at: settings.reminderTime,
                enabled: settings.reminderEnabled
            )
        }
    }
}

extension Notification.Name {
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}