import Foundation

/// アプリの表示言語に合わせた日付の書式
enum AppDateFormat {
    private static var formatters: [String: DateFormatter] = [:]

    private static func formatter(style: DateFormatter.Style) -> DateFormatter {
        let language = LanguageManager.shared.currentLanguage
        let key = "\(language)-\(style.rawValue)"
        if let cached = formatters[key] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.dateStyle = style
        formatter.timeStyle = .none
        formatters[key] = formatter
        return formatter
    }

    /// 例: 2026/11/08、Nov 8, 2026
    static func medium(_ date: Date) -> String {
        formatter(style: .medium).string(from: date)
    }
}
