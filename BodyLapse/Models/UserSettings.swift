import Foundation

struct UserSettings: Codable {
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var showBodyGuidelines: Bool = true
    var isPremium: Bool = false
    var weightUnit: WeightUnit = .kg
    
    // Onboarding
    var hasCompletedOnboarding: Bool = false
    var targetWeight: Double?
    var targetBodyFatPercentage: Double?
    
    // Security
    var isAppLockEnabled: Bool = false
    var appLockMethod: AppLockMethod = .biometric
    var appPasscode: String?
    
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
    private var storeManager: StoreManager?
    
    init() {
        if let data = userDefaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(UserSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = UserSettings.default
        }
        
        // Initialize StoreKit after init
        Task { @MainActor in
            self.storeManager = StoreManager.shared
            await self.syncPremiumStatus()
            
            // Observe premium status changes
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(premiumStatusChanged),
                name: .premiumStatusChanged,
                object: nil
            )
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
    
    func syncPremiumStatus() async {
        guard let storeManager = storeManager else { return }
        await storeManager.loadProducts()
        settings.isPremium = storeManager.isPremium
    }
    
    @objc private func premiumStatusChanged() {
        Task { @MainActor in
            await syncPremiumStatus()
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