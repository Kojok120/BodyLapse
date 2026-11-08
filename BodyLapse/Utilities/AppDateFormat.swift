import Foundation

/// アプリの表示言語に合わせた日付の書式。
/// 画面ごとに dateFormat を直書きすると、言語に合わない並び (「11月 8, 2026」など) になるので、ここに集める
enum AppDateFormat {
    private static var formatters: [String: DateFormatter] = [:]
    private static let lock = NSLock()

    private static func formatter(key: String, configure: (DateFormatter) -> Void) -> DateFormatter {
        let language = LanguageManager.shared.currentLanguage
        let cacheKey = "\(language)-\(key)"
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[cacheKey] {
            return cached
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        configure(formatter)
        formatters[cacheKey] = formatter
        return formatter
    }

    private static func string(_ date: Date, template: String) -> String {
        formatter(key: "t-\(template)") { $0.setLocalizedDateFormatFromTemplate(template) }.string(from: date)
    }

    /// 例: 2026/11/08、Nov 8, 2026
    static func medium(_ date: Date) -> String {
        formatter(key: "medium") {
            $0.dateStyle = .medium
            $0.timeStyle = .none
        }.string(from: date)
    }

    /// 例: 2026年11月8日、November 8, 2026
    static func long(_ date: Date) -> String {
        formatter(key: "long") {
            $0.dateStyle = .long
            $0.timeStyle = .none
        }.string(from: date)
    }

    /// 例: 2026/11/08 9:41、Nov 8, 2026 at 9:41 AM
    static func mediumDateTime(_ date: Date) -> String {
        formatter(key: "medium-short") {
            $0.dateStyle = .medium
            $0.timeStyle = .short
        }.string(from: date)
    }

    /// 例: 2026年11月、November 2026
    static func monthYear(_ date: Date) -> String {
        string(date, template: "yMMMM")
    }

    /// 例: 11月、November
    static func month(_ date: Date) -> String {
        string(date, template: "MMMM")
    }

    /// 例: 2026年、2026
    static func year(_ date: Date) -> String {
        string(date, template: "y")
    }

    /// 例: 11/8
    static func monthDay(_ date: Date) -> String {
        string(date, template: "Md")
    }

    /// 例: 8日、8
    static func day(_ date: Date) -> String {
        string(date, template: "d")
    }
}
