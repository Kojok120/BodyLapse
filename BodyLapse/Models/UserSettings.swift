import Foundation

struct UserSettings: Codable {
    var showBodyGuidelines: Bool = true
    var weightUnit: WeightUnit = .kg
    var healthKitEnabled: Bool = false
    
    // オンボーディング
    var hasCompletedOnboarding: Bool = false
    
    // セキュリティ
    var isAppLockEnabled: Bool = false
    var appLockMethod: AppLockMethod = .biometric
    // appPasscodeを削除 - AuthenticationService経由でKeychainに安全に保存するように変更
    
    // アプリ評価
    var hasRatedApp: Bool = false
    
    // 動画生成
    var showDateInVideo: Bool = true
    
    // リマインダー設定
    var isReminderEnabled: Bool = false
    var reminderHour: Int = 19  // デフォルトは19時（注: 未撮影チェックは21時）
    var reminderMinute: Int = 0
    
    // 外観
    var appearanceMode: AppearanceMode = .system
    
    // 顔ぼかし設定
    var faceBlurMethod: FaceBlurMethod = .strongBlur
    
    // デバッグ設定
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
            
            // 旧UserSettingsからAuthenticationServiceへのパスワード移行
            migratePasswordIfNeeded()
        } else {
            self.settings = UserSettings.default
        }
    }
    
    private func migratePasswordIfNeeded() {
        // UserDefaultsに移行が必要な旧パスワードが保存されているか確認
        // 旧バージョンからアップグレードするユーザーへの対応
        if let oldData = userDefaults.data(forKey: settingsKey),
           let jsonObject = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any],
           let oldPasscode = jsonObject["appPasscode"] as? String,
           !oldPasscode.isEmpty {
            
            // AuthenticationServiceへ移行
            if AuthenticationService.shared.setPassword(oldPasscode) {
                AuthenticationService.shared.isAuthenticationEnabled = settings.isAppLockEnabled
                if settings.appLockMethod == .biometric {
                    AuthenticationService.shared.isBiometricEnabled = true
                }
                
                // 設定を再保存してUserDefaultsから旧パスワードを削除
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
        // 必要に応じて設定変更を処理
        if oldValue.appearanceMode != settings.appearanceMode {
            AppearanceManager.shared.syncWithSettings()
        }
    }
}

extension Notification.Name {
    static let premiumStatusChanged = Notification.Name("premiumStatusChanged")
}