import Foundation
import Testing
@testable import BodyLapse

struct WeightChartDataTests {

    private func entry(dayOffset: Int, weight: Double, bodyFat: Double? = nil) -> WeightEntry {
        let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: Date(timeIntervalSince1970: 1_750_000_000))!
        return WeightEntry(date: date, weight: weight, bodyFatPercentage: bodyFat)
    }

    @Test
    func testPointsAreSortedAndZeroWeightIsExcluded() {
        let entries = [
            entry(dayOffset: 2, weight: 70),
            entry(dayOffset: 0, weight: 72, bodyFat: 20),
            entry(dayOffset: 1, weight: 0, bodyFat: 19)
        ]
        let data = WeightChartData(entries: entries, unit: .kg)

        #expect(data.weightPoints.map(\.value) == [72, 70])
        #expect(data.bodyFatPoints.map(\.value) == [20, 19])
        #expect(data.weightPoints.map(\.date) == data.weightPoints.map(\.date).sorted())
    }

    @Test
    func testWeightPointsUseDisplayUnit() throws {
        let data = WeightChartData(entries: [entry(dayOffset: 0, weight: 100)], unit: .lbs)
        let value = try #require(data.weightPoints.first?.value)
        #expect(abs(value - 220.462) < 0.001)
    }

    @Test
    func testPaddedRange() {
        #expect(WeightChartData.paddedRange(for: [], default: 70...80) == 70...80)
        #expect(WeightChartData.paddedRange(for: [60], default: 70...80) == 55...65)
        #expect(WeightChartData.paddedRange(for: [60, 62], default: 70...80) == 56...66)
        let wide = WeightChartData.paddedRange(for: [60, 80], default: 70...80)
        #expect(abs(wide.lowerBound - 58) < 0.0001)
        #expect(abs(wide.upperBound - 82) < 0.0001)
    }

    @Test
    func testNormalized() {
        #expect(WeightChartData.normalized(75, in: 70...80) == 0.5)
        #expect(WeightChartData.normalized(70, in: 70...80) == 0)
        #expect(WeightChartData.normalized(5, in: 5...5) == 0.5)
    }
}
