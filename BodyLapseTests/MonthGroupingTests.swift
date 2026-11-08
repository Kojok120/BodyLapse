import Foundation
import Testing
@testable import BodyLapse

struct MonthGroupingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    @Test
    func testGroupsByMonthAndKeepsOrderInsideMonth() {
        let items = [date(2026, 11, 8), date(2026, 11, 1), date(2026, 10, 31, hour: 23), date(2025, 11, 20)]
        let groups = MonthGrouping.group(items, date: { $0 }, newestFirst: true, calendar: calendar)

        #expect(groups.map { calendar.component(.month, from: $0.month) } == [11, 10, 11])
        #expect(groups.map { calendar.component(.year, from: $0.month) } == [2026, 2026, 2025])
        #expect(groups[0].items == [date(2026, 11, 8), date(2026, 11, 1)])
        #expect(groups[1].items == [date(2026, 10, 31, hour: 23)])
    }

    @Test
    func testOldestFirstSortsMonthsAscending() {
        let items = [date(2026, 1, 5), date(2025, 12, 5), date(2026, 3, 5)]
        let groups = MonthGrouping.group(items, date: { $0 }, newestFirst: false, calendar: calendar)
        #expect(groups.map { calendar.component(.month, from: $0.month) } == [12, 1, 3])
        #expect(Set(groups.map(\.id)).count == 3)
    }

    @Test
    func testEmpty() {
        #expect(MonthGrouping.group([Date](), date: { $0 }, newestFirst: true).isEmpty)
    }
}
