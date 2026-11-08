import Foundation
import Testing
@testable import BodyLapse

struct CalendarDateRangeTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    @Test
    func testMakeDatesEndsTodayAndIsAscending() {
        let end = calendar.date(from: DateComponents(year: 2026, month: 3, day: 2, hour: 15))!
        let dates = CalendarDateRange.makeDates(days: 3, endingOn: end, calendar: calendar)
        #expect(dates.count == 3)
        #expect(dates.map { calendar.component(.day, from: $0) } == [28, 1, 2])
        #expect(dates.allSatisfy { calendar.startOfDay(for: $0) == $0 })
        #expect(CalendarDateRange.makeDates(days: 0, endingOn: end, calendar: calendar).isEmpty)
    }

    @Test
    func testIndexUsesDayOffset() {
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 8))!
        let dates = CalendarDateRange.makeDates(days: 1825, endingOn: end, calendar: calendar)
        let target = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 21))!
        let index = CalendarDateRange.index(of: target, in: dates, calendar: calendar)
        #expect(index == dates.firstIndex { calendar.isDate($0, inSameDayAs: target) })
        #expect(CalendarDateRange.index(of: end, in: dates, calendar: calendar) == 1824)
        let outside = calendar.date(byAdding: .day, value: 1, to: end)!
        #expect(CalendarDateRange.index(of: outside, in: dates, calendar: calendar) == nil)
    }

    @Test @MainActor
    func testDatesIsReusedForSameDayAndLength() {
        let first = CalendarDateRange.dates(days: 30)
        let second = CalendarDateRange.dates(days: 30)
        #expect(first == second)
        #expect(CalendarDateRange.dates(days: 7).count == 7)
    }
}
