import Foundation
import XCTest

@testable import KASANE

@MainActor
final class OverviewCalendarTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    private func makeDashboardSession(
        year: Int, month: Int, day: Int, duration: TimeInterval, calendar: Calendar
    ) throws -> WorkoutSession {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day)))
        return WorkoutSession(startedAt: date, endedAt: date.addingTimeInterval(duration))
    }

    func testCalendarTrainingDaysUseUniqueCompletedLocalDates() throws {
        var calendar = utcCalendar
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let reference = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17)))
        let sessions = try [3, 4, 10, 11, 12, 12].map {
            try makeDashboardSession(year: 2026, month: 10, day: $0, duration: 600, calendar: calendar)
        }
        let draft = try makeDashboardSession(year: 2026, month: 10, day: 5, duration: 600, calendar: calendar)
        draft.endedAt = nil
        let stats = OverviewStats(sessions: sessions + [draft], now: reference, calendar: calendar)
        XCTAssertEqual(stats.trainingDayCount, 5)
        XCTAssertEqual(stats.workoutCount, 6)
        for number in 1...31 {
            let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: number)))
            let count = stats.dailyWorkoutCounts[calendar.startOfDay(for: date), default: 0]
            let day = OverviewCalendarDay(date: date, count: count, referenceDate: reference, calendar: calendar)
            XCTAssertEqual(day.text, number < 17 && count == 0 ? "・" : String(number))
            XCTAssertEqual(day.isToday, number == 17)
            XCTAssertEqual(day.isFuture, number > 17)
            XCTAssertFalse(day.accessibilityLabel.contains("・"))
            let expectedState =
                number > 17 ? "未来の日付" : number == 17 ? "今日、トレーニングなし"
                : count > 0 ? "トレーニングあり" : "トレーニングなし"
            XCTAssertEqual(day.accessibilityValue, expectedState)
        }
        let previous = try XCTUnwrap(calendar.date(byAdding: .month, value: -1, to: reference))
        XCTAssertEqual(OverviewStats(sessions: sessions, now: previous, calendar: calendar).trainingDayCount, 0)
        XCTAssertEqual(OverviewStats(sessions: [], now: reference, calendar: calendar).trainingDayCount, 0)
    }

    func testCalendarTodayPriorityAndDayRollover() throws {
        let calendar = utcCalendar
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 17)))
        for count in [0, 1, 3] {
            let today = OverviewCalendarDay(date: date, count: count, referenceDate: date, calendar: calendar)
            XCTAssertTrue(today.isToday)
            XCTAssertEqual(today.text, "17")
            XCTAssertEqual(today.accessibilityValue, count == 0 ? "今日、トレーニングなし" : "今日、トレーニングあり")
        }
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: date))
        let yesterday = OverviewCalendarDay(date: date, count: 0, referenceDate: tomorrow, calendar: calendar)
        XCTAssertFalse(yesterday.isToday)
        XCTAssertEqual(yesterday.text, "・")
        let future = OverviewCalendarDay(date: tomorrow, count: 3, referenceDate: date, calendar: calendar)
        XCTAssertTrue(future.isFuture)
        XCTAssertEqual(future.text, "18")
        let single = OverviewCalendarDay(date: date, count: 1, referenceDate: tomorrow, calendar: calendar)
        let multiple = OverviewCalendarDay(date: date, count: 3, referenceDate: tomorrow, calendar: calendar)
        XCTAssertEqual(single.text, multiple.text)
        XCTAssertEqual(single.accessibilityValue, multiple.accessibilityValue)
    }

}
