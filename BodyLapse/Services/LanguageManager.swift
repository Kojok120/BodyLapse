import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            // Force update bundle
            Bundle.setLanguage(currentLanguage)
            
            // Notify app to refresh
            NotificationCenter.default.post(name: .languageChanged, object: nil)
        }
    }
    
    let supportedLanguages = [
        "en", // English
        "ja", // Japanese
        "ko", // Korean
        "es"  // Spanish
    ]
    
    let languageNames: [String: String] = [
        "en": "English",
        "ja": "日本語",
        "ko": "한국어",
        "es": "Español"
    ]
    
    private init() {
        // Check if user has set a language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           supportedLanguages.contains(savedLanguage) {
            self.currentLanguage = savedLanguage
        } else {
            // Use system language if supported, otherwise default to English
            let preferredLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
            self.currentLanguage = supportedLanguages.contains(preferredLanguage) ? preferredLanguage : "en"
            
            // Save the initial language
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
        }
        
        // Apply the language
        Bundle.setLanguage(currentLanguage)
    }
    
    func setLanguage(_ languageCode: String) {
        guard supportedLanguages.contains(languageCode) else { return }
        currentLanguage = languageCode
    }
    
    func getLanguageName(for code: String) -> String {
        return languageNames[code] ?? code
    }
}

// Extension to support dynamic language switching
extension Bundle {
    static var languageBundle: Bundle!
    
    static func setLanguage(_ language: String) {
        defer {
            object_setClass(Bundle.main, AnyLanguageBundle.self)
        }
        
        languageBundle = Bundle.main
        
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            self.languageBundle = bundle
        } else {
            languageBundle = Bundle.main
        }
    }
}

// Custom Bundle class to override localization
private class AnyLanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = Bundle.languageBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

// Notification for language change
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// Helper for localized strings
extension String {
    var localized: String {
        if let bundle = Bundle.languageBundle {
            return bundle.localizedString(forKey: self, value: self, table: nil)
        }
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        let localizedString = self.localized
        return String(format: localizedString, arguments: arguments)
    }
}