import Foundation

struct UserSettings: Codable {
    var reminderEnabled: Bool = false
    var reminderTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var autoFaceBlur: Bool = true
    var showBodyGuidelines: Bool = true
    var isPremium: Bool = false
    var weightUnit: WeightUnit = .kg
    
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
}

extension UserSettings {
    static let `default` = UserSettings()
}

class UserSettingsManager: ObservableObject {
    @Published var settings: UserSettings {
        didSet {
            save()
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
}