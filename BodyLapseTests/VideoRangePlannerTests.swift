import Foundation
import Testing
@testable import BodyLapse

struct VideoRangePlannerTests {

    private let calendar = Calendar.current
    private let today = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 20))!

    private func photo(daysAgo: Int, hour: Int = 9, category: String = "default") -> Photo {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: today))!
        return Photo(captureDate: calendar.date(byAdding: .hour, value: hour, to: day)!, fileName: "\(daysAgo).jpg", categoryId: category)
    }

    @Test
    func testDefaultRangeStartsAtFirstPhoto() {
        let photos = [photo(daysAgo: 3), photo(daysAgo: 120), photo(daysAgo: 400, category: "side")]
        let range = VideoRangePlanner.defaultRange(photos: photos, categoryIds: ["default"], today: today, calendar: calendar)
        #expect(range.lowerBound == calendar.startOfDay(for: photos[1].captureDate))
        #expect(range.upperBound == calendar.startOfDay(for: today))
    }

    @Test
    func testDefaultRangeWithoutPhotosIsToday() {
        let range = VideoRangePlanner.defaultRange(photos: [], categoryIds: [], today: today, calendar: calendar)
        #expect(range.lowerBound == range.upperBound)
    }

    @Test
    func testCountIncludesPhotoTakenOnEndDay() {
        // 終了日が今日の 0:00 でも、今日の夜に撮った写真を数える
        let photos = [photo(daysAgo: 0, hour: 19), photo(daysAgo: 6), photo(daysAgo: 7), photo(daysAgo: 1, category: "side")]
        let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: today))!
        let count = VideoRangePlanner.photoCount(photos: photos, from: start, to: calendar.startOfDay(for: today), categoryIds: ["default"], calendar: calendar)
        #expect(count == 2)
    }
}

struct FreeTrialTextTests {

    @Test
    func testSevenDaysReadsAsOneWeek() {
        #expect(FreeTrialText.text(value: 7, unit: .day) == FreeTrialText.text(value: 1, unit: .week))
        #expect(FreeTrialText.text(value: 3, unit: .day) != FreeTrialText.text(value: 1, unit: .week))
    }
}
