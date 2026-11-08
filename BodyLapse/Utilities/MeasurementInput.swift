import Foundation

/// 体重・体脂肪率の入力文字列を解釈・整形する純関数群。
///
/// 端末の地域設定によってテンキーの小数点が「,」になる (es-ES など)。
/// `Double("65,5")` は nil になるため、ここで「.」と「,」のどちらも小数点として受け付ける。
/// 解釈できない値や現実的でない値は nil を返し、呼び出し側は保存させない。
enum MeasurementInput {
    static let poundsPerKilogram = 2.20462

    /// 受け付ける体重の範囲 (kg)。lbs で入力しても kg に直してからこの範囲で判定する。
    static let weightRangeKg: ClosedRange<Double> = 10...500
    /// 受け付ける体脂肪率の範囲 (%)。
    static let bodyFatRange: ClosedRange<Double> = 1...80

    /// 小数を 1 つだけ含む数値文字列を Double にする。小数点は「.」「,」のどちらでもよい。
    /// 全角の数字・記号も受け付ける。空文字・桁区切り・符号・指数表記・非有限値は nil。
    static func parseDecimal(_ text: String) -> Double? {
        let halfWidth = text.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? text
        let trimmed = halfWidth.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        let allowed = Set("0123456789.")
        guard normalized.allSatisfy({ allowed.contains($0) }),
              normalized.filter({ $0 == "." }).count <= 1,
              normalized.contains(where: { $0.isNumber }) else {
            return nil
        }

        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }

    /// 体重の入力を kg に直して返す。範囲外・解釈できない値は nil。
    static func weightKg(from text: String, unit: UserSettings.WeightUnit) -> Double? {
        guard let value = parseDecimal(text) else { return nil }
        let kg = unit == .kg ? value : value / poundsPerKilogram
        return weightRangeKg.contains(kg) ? kg : nil
    }

    /// 体脂肪率の入力を返す。範囲外・解釈できない値は nil。
    static func bodyFat(from text: String) -> Double? {
        guard let value = parseDecimal(text) else { return nil }
        return bodyFatRange.contains(value) ? value : nil
    }

    /// kg の値を表示単位に直す。
    static func displayWeight(kg: Double, unit: UserSettings.WeightUnit) -> Double {
        unit == .kg ? kg : kg * poundsPerKilogram
    }

    /// 入力欄に入れる文字列。テンキーと同じ小数点を使うよう、端末の地域設定で小数 1 桁に整形する。
    static func inputText(_ value: Double, locale: Locale = .current) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(1))
                .grouping(.never)
                .locale(locale)
        )
    }
}
