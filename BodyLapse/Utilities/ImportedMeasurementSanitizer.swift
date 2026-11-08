import Foundation

/// 取り込むファイルの体重・体脂肪率を、アプリで扱える値に揃える純関数群。
///
/// 書き出しは NaN や Infinity も文字列で書けるので、細工したファイルや壊れたファイルから入ると
/// チャートの範囲の計算で落ちる。体重は有限の正の値だけを、体脂肪率は 0〜100 だけを受け付ける。
/// 取り込みの範囲は入力欄 (`MeasurementInput`) より広く取る。昔の版で入った値を捨てないため。
enum ImportedMeasurementSanitizer {
    static func weight(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value > 0 else { return nil }
        return value
    }

    static func bodyFat(_ value: Double?) -> Double? {
        guard let value, value.isFinite, (0...100).contains(value) else { return nil }
        return value
    }

    /// 体重が使えない記録は落とす。体脂肪率だけが使えないときは、体脂肪率を外して残す
    static func weightEntries(_ entries: [WeightEntry]) -> [WeightEntry] {
        entries.compactMap { entry in
            guard let weight = weight(entry.weight) else { return nil }
            let bodyFat = bodyFat(entry.bodyFatPercentage)
            if weight == entry.weight && bodyFat == entry.bodyFatPercentage {
                return entry
            }
            return WeightEntry(
                id: entry.id,
                date: entry.date,
                weight: weight,
                bodyFatPercentage: bodyFat,
                linkedPhotoID: entry.linkedPhotoID,
                createdAt: entry.createdAt
            )
        }
    }
}
