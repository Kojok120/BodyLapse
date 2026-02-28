import Foundation
import SwiftUI

class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            // バンドルを強制更新
            Bundle.setLanguage(currentLanguage)
            
            // アプリに更新を通知
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
        // ユーザーが言語設定を行ったか確認
        if let savedLanguage = UserDefaults.standard.string(forKey: "AppLanguage"),
           supportedLanguages.contains(savedLanguage) {
            self.currentLanguage = savedLanguage
        } else {
            // サポートされている場合はシステム言語を使用、それ以外は英語をデフォルトに使用
            let preferredLanguage = Locale.preferredLanguages.first?.components(separatedBy: "-").first ?? "en"
            self.currentLanguage = supportedLanguages.contains(preferredLanguage) ? preferredLanguage : "en"
            
            // 初期言語を保存
            UserDefaults.standard.set(currentLanguage, forKey: "AppLanguage")
            UserDefaults.standard.set([currentLanguage], forKey: "AppleLanguages")
        }
        
        // 言語を適用
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

// 動的言語切り替えをサポートする拡張
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

// ローカライゼーションをオーバーライドするカスタムBundleクラス
private class AnyLanguageBundle: Bundle {
    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = Bundle.languageBundle {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

// 言語変更の通知
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
}

// ローカライズ文字列のヘルパー
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