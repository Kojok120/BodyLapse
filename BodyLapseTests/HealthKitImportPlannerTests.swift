import Foundation
import Testing
@testable import BodyLapse

struct HealthKitImportPlannerTests {

    private let calendar = Calendar.current
    private let day1 = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 1))!

    private func at(_ day: Date, hour: Int) -> Date {
        calendar.date(byAdding: .hour, value: hour, to: day)!
    }

    private var day2: Date { calendar.date(byAdding: .day, value: 1, to: day1)! }

    @Test
    func testDailyMeasurementsUseLatestSamplePerDay() {
        let weights = [
            HealthKitImportPlanner.Sample(date: at(day1, hour: 7), value: 70),
            HealthKitImportPlanner.Sample(date: at(day1, hour: 21), value: 70.6),
            HealthKitImportPlanner.Sample(date: at(day2, hour: 8), value: 69.8)
        ]
        let bodyFats = [
            HealthKitImportPlanner.Sample(date: at(day1, hour: 22), value: 18.2),
            HealthKitImportPlanner.Sample(date: at(day1, hour: 6), value: 19.0)
        ]
        let daily = HealthKitImportPlanner.dailyMeasurements(weights: weights, bodyFats: bodyFats, calendar: calendar)
        #expect(daily.count == 2)
        #expect(daily[0].weightKg == 70.6)
        #expect(daily[0].bodyFatPercentage == 18.2)
        #expect(daily[0].latestSampleDate == at(day1, hour: 22))
        #expect(daily[1].bodyFatPercentage == nil)
    }

    @Test
    func testBodyFatWithoutWeightIsIgnored() {
        let daily = HealthKitImportPlanner.dailyMeasurements(
            weights: [],
            bodyFats: [HealthKitImportPlanner.Sample(date: at(day1, hour: 7), value: 18)],
            calendar: calendar
        )
        #expect(daily.isEmpty)
    }

    private func measurement(_ day: Date, weight: Double, sampleHour: Int) -> HealthKitImportPlanner.DailyMeasurement {
        HealthKitImportPlanner.DailyMeasurement(day: day, weightKg: weight, bodyFatPercentage: nil, latestSampleDate: at(day, hour: sampleHour))
    }

    @Test
    func testNewDayIsAdded() {
        let result = HealthKitImportPlanner.entriesToWrite(
            measurements: [measurement(day1, weight: 70, sampleHour: 7)],
            existing: [],
            deletedDays: [:],
            dayKey: WeightStorageService.dayKey(for:),
            calendar: calendar
        )
        #expect(result.map(\.weight) == [70])
    }

    @Test
    func testAppEditNewerThanSampleIsKept() {
        let edited = WeightEntry(date: day1, weight: 71, createdAt: at(day1, hour: 12))
        let result = HealthKitImportPlanner.entriesToWrite(
            measurements: [measurement(day1, weight: 70, sampleHour: 7)],
            existing: [edited],
            deletedDays: [:],
            dayKey: WeightStorageService.dayKey(for:),
            calendar: calendar
        )
        #expect(result.isEmpty)
    }

    @Test
    func testNewerSampleReplacesAndKeepsIdentity() {
        let old = WeightEntry(date: day1, weight: 71, linkedPhotoID: "photo", createdAt: at(day1, hour: 6))
        let result = HealthKitImportPlanner.entriesToWrite(
            measurements: [measurement(day1, weight: 70, sampleHour: 7)],
            existing: [old],
            deletedDays: [:],
            dayKey: WeightStorageService.dayKey(for:),
            calendar: calendar
        )
        #expect(result.count == 1)
        #expect(result.first?.id == old.id)
        #expect(result.first?.linkedPhotoID == "photo")
        #expect(result.first?.weight == 70)
    }

    @Test
    func testDeletedDayIsNotRestoredUnlessNewSampleArrives() {
        let deletedDays = [WeightStorageService.dayKey(for: day1): at(day1, hour: 12)]
        let older = HealthKitImportPlanner.entriesToWrite(
            measurements: [measurement(day1, weight: 70, sampleHour: 7)],
            existing: [],
            deletedDays: deletedDays,
            dayKey: WeightStorageService.dayKey(for:),
            calendar: calendar
        )
        #expect(older.isEmpty)

        let newer = HealthKitImportPlanner.entriesToWrite(
            measurements: [measurement(day1, weight: 69.5, sampleHour: 20)],
            existing: [],
            deletedDays: deletedDays,
            dayKey: WeightStorageService.dayKey(for:),
            calendar: calendar
        )
        #expect(newer.map(\.weight) == [69.5])
    }
}
