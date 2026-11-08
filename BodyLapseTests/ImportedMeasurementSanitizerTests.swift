import Foundation
import Testing
@testable import BodyLapse

struct ImportedMeasurementSanitizerTests {

    @Test(arguments: [Double.nan, .infinity, -.infinity, 0, -1])
    func testWeightRejectsNonFiniteAndNonPositive(value: Double) {
        #expect(ImportedMeasurementSanitizer.weight(value) == nil)
    }

    @Test
    func testWeightKeepsValuesOutsideTheInputRange() {
        // 入力欄の範囲 (10〜500 kg) の外でも、有限の正の値なら昔の記録として残す
        #expect(ImportedMeasurementSanitizer.weight(8.4) == 8.4)
        #expect(ImportedMeasurementSanitizer.weight(65.5) == 65.5)
        #expect(ImportedMeasurementSanitizer.weight(nil) == nil)
    }

    @Test
    func testBodyFatRange() {
        #expect(ImportedMeasurementSanitizer.bodyFat(18.2) == 18.2)
        #expect(ImportedMeasurementSanitizer.bodyFat(0) == 0)
        #expect(ImportedMeasurementSanitizer.bodyFat(100) == 100)
        #expect(ImportedMeasurementSanitizer.bodyFat(100.1) == nil)
        #expect(ImportedMeasurementSanitizer.bodyFat(.nan) == nil)
        #expect(ImportedMeasurementSanitizer.bodyFat(-.infinity) == nil)
    }

    @Test
    func testWeightEntriesDropsBrokenWeightAndClearsBrokenBodyFat() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let good = WeightEntry(date: date, weight: 70, bodyFatPercentage: 15)
        let brokenWeight = WeightEntry(date: date, weight: .nan, bodyFatPercentage: 15)
        let brokenFat = WeightEntry(date: date, weight: 71, bodyFatPercentage: .infinity, linkedPhotoID: "p1")

        let result = ImportedMeasurementSanitizer.weightEntries([good, brokenWeight, brokenFat])

        #expect(result.count == 2)
        #expect(result[0] == good)
        #expect(result[1].id == brokenFat.id)
        #expect(result[1].weight == 71)
        #expect(result[1].bodyFatPercentage == nil)
        #expect(result[1].linkedPhotoID == "p1")
        #expect(result[1].createdAt == brokenFat.createdAt)
    }
}
