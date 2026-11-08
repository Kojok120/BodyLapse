import Foundation

/// ヘルスケアの記録を日ごとにまとめ、アプリの記録へ何を書くかを決める純関数
enum HealthKitImportPlanner {
    struct Sample: Equatable {
        let date: Date
        let value: Double
    }

    struct DailyMeasurement: Equatable {
        let day: Date
        let weightKg: Double
        let bodyFatPercentage: Double?
        /// その日の体重・体脂肪率のうち、いちばん新しい記録の時刻
        let latestSampleDate: Date
    }

    /// 日ごとに最新の体重と体脂肪率をまとめる。体重の無い日は作らない
    static func dailyMeasurements(weights: [Sample], bodyFats: [Sample], calendar: Calendar = .current) -> [DailyMeasurement] {
        func latestByDay(_ samples: [Sample]) -> [Date: Sample] {
            var result: [Date: Sample] = [:]
            for sample in samples {
                let day = calendar.startOfDay(for: sample.date)
                if let current = result[day], current.date >= sample.date {
                    continue
                }
                result[day] = sample
            }
            return result
        }

        let weightByDay = latestByDay(weights)
        let bodyFatByDay = latestByDay(bodyFats)
        return weightByDay.map { day, weight in
            let bodyFat = bodyFatByDay[day]
            return DailyMeasurement(
                day: day,
                weightKg: weight.value,
                bodyFatPercentage: bodyFat?.value,
                latestSampleDate: max(weight.date, bodyFat?.date ?? weight.date)
            )
        }
        .sorted { $0.day < $1.day }
    }

    /// アプリの記録へ書く分。アプリで後から直した日と、アプリで消した日は、それより新しい記録がヘルスケアに無い限り書かない
    static func entriesToWrite(
        measurements: [DailyMeasurement],
        existing: [WeightEntry],
        deletedDays: [String: Date],
        dayKey: (Date) -> String,
        calendar: Calendar = .current
    ) -> [WeightEntry] {
        var existingByDay: [Date: WeightEntry] = [:]
        for entry in existing {
            existingByDay[calendar.startOfDay(for: entry.date)] = entry
        }

        return measurements.compactMap { measurement in
            if let deletedAt = deletedDays[dayKey(measurement.day)], measurement.latestSampleDate <= deletedAt {
                return nil
            }
            if let current = existingByDay[measurement.day] {
                guard measurement.latestSampleDate > current.createdAt else { return nil }
                if current.weight == measurement.weightKg && current.bodyFatPercentage == measurement.bodyFatPercentage {
                    return nil
                }
                return WeightEntry(
                    id: current.id,
                    date: measurement.day,
                    weight: measurement.weightKg,
                    bodyFatPercentage: measurement.bodyFatPercentage,
                    linkedPhotoID: current.linkedPhotoID
                )
            }
            return WeightEntry(
                date: measurement.day,
                weight: measurement.weightKg,
                bodyFatPercentage: measurement.bodyFatPercentage
            )
        }
    }
}
