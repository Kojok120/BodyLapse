import Foundation
import Testing
@testable import BodyLapse

struct TimePeriodTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 20))!
    }

    private func daysAgo(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: today)!
    }

    @Test
    func testExpandedKeepsPeriodWhenDateIsInside() {
        #expect(TimePeriod.expanded(.week, toInclude: daysAgo(6), today: today, calendar: calendar) == .week)
        #expect(TimePeriod.expanded(.year, toInclude: daysAgo(3), today: today, calendar: calendar) == .year)
    }

    @Test
    func testExpandedPicksSmallestPeriodThatFits() {
        #expect(TimePeriod.expanded(.week, toInclude: daysAgo(7), today: today, calendar: calendar) == .month)
        #expect(TimePeriod.expanded(.week, toInclude: daysAgo(40), today: today, calendar: calendar) == .threeMonths)
        #expect(TimePeriod.expanded(.month, toInclude: daysAgo(400), today: today, calendar: calendar) == .twoYears)
        #expect(TimePeriod.expanded(.week, toInclude: daysAgo(4000), today: today, calendar: calendar) == .fiveYears)
    }

    @Test
    func testEarliestSelectableDate() {
        let weekStart = calendar.startOfDay(for: daysAgo(6))
        // 記録が無い・期間の中だけ → 今の期間の始まり
        #expect(TimePeriod.earliestSelectableDate(earliestRecord: nil, current: .week, today: today, calendar: calendar) == weekStart)
        #expect(TimePeriod.earliestSelectableDate(earliestRecord: daysAgo(2), current: .week, today: today, calendar: calendar) == weekStart)
        // 期間より前の記録 → その日まで
        #expect(TimePeriod.earliestSelectableDate(earliestRecord: daysAgo(100), current: .week, today: today, calendar: calendar)
                == calendar.startOfDay(for: daysAgo(100)))
        // 5 年より前は 5 年まで
        #expect(TimePeriod.earliestSelectableDate(earliestRecord: daysAgo(3000), current: .week, today: today, calendar: calendar)
                == calendar.startOfDay(for: daysAgo(1824)))
    }
}
