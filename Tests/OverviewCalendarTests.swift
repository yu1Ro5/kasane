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
                number > 17
                ? "未来の日付"
                : number == 17
                    ? "今日、トレーニングなし"
                    : count > 0 ? "トレーニング\(count)件" : "トレーニングなし"
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
            XCTAssertEqual(today.accessibilityValue, count == 0 ? "今日、トレーニングなし" : "今日、トレーニング\(count)件")
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
        XCTAssertEqual(single.accessibilityValue, "トレーニング1件")
        XCTAssertEqual(multiple.accessibilityValue, "トレーニング3件")
        XCTAssertEqual(single.accessibilityHint, "詳細を開く")
        XCTAssertEqual(multiple.accessibilityHint, "履歴を開く")
        XCTAssertEqual(yesterday.accessibilityHint, "")
    }

    func testCalendarRoutesAndHistoryFilteringShareLocalStartDays() throws {
        for zone in ["Asia/Tokyo", "America/Los_Angeles", "UTC"] {
            var calendar = utcCalendar
            calendar.timeZone = try XCTUnwrap(TimeZone(identifier: zone))
            // 月末の開始日を使い、終了は翌月になる。
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23)))
            let overnight = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(7200))
            let second = WorkoutSession(startedAt: start.addingTimeInterval(-3600), endedAt: start)
            let nextDay = WorkoutSession(
                startedAt: start.addingTimeInterval(7200), endedAt: start.addingTimeInterval(7800))
            let draft = WorkoutSession(startedAt: start)
            let all = [nextDay, overnight, second, draft]
            let october = OverviewStats(sessions: all, now: start, calendar: calendar)
            let day = calendar.startOfDay(for: start)
            XCTAssertEqual(october.dailyWorkoutCounts[day], 2)
            XCTAssertEqual(october.destination(for: start, calendar: calendar), .history(day))
            XCTAssertNil(october.destination(for: nextDay.startedAt, calendar: calendar))
            let november = OverviewStats(sessions: all, now: nextDay.startedAt, calendar: calendar)
            XCTAssertEqual(november.destination(for: nextDay.startedAt, calendar: calendar), .workoutDetail(nextDay.id))
            XCTAssertEqual(
                OverviewWorkoutLoader.sessions(all, on: start, calendar: calendar).map(\.id), [overnight.id, second.id])
            XCTAssertEqual(
                OverviewWorkoutLoader.sessions(all, on: nil, calendar: calendar).map(\.id),
                [nextDay.id, overnight.id, second.id])
            let empty = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: start))
            XCTAssertNil(october.destination(for: empty, calendar: calendar))
            XCTAssertTrue(OverviewWorkoutLoader.sessions(all, on: empty, calendar: calendar).isEmpty)
        }
    }

    func testCalendarDayFilteringAcrossDSTAndTimeZoneChanges() throws {
        var calendar = utcCalendar
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        for (month, day, hours) in [(3, 8, 23), (11, 1, 25)] {
            let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: month, day: day)))
            let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
            XCTAssertEqual(end.timeIntervalSince(start), Double(hours * 3600))
            let first = WorkoutSession(startedAt: start, endedAt: start.addingTimeInterval(60))
            let last = WorkoutSession(startedAt: end.addingTimeInterval(-60), endedAt: end)
            let boundary = WorkoutSession(startedAt: end, endedAt: end.addingTimeInterval(60))
            let all = [first, last, boundary]
            let stats = OverviewStats(sessions: all, now: start, calendar: calendar)
            XCTAssertEqual(stats.dailyWorkoutCounts[start], 2)
            XCTAssertEqual(stats.destination(for: start, calendar: calendar), .history(start))
            XCTAssertEqual(
                OverviewWorkoutLoader.sessions(all, on: start, calendar: calendar).map(\.id), [first.id, last.id])
            var tokyo = calendar
            tokyo.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
            let tokyoStats = OverviewStats(sessions: all, now: start, calendar: tokyo)
            let tokyoDay = tokyo.startOfDay(for: first.startedAt)
            XCTAssertEqual(tokyoStats.dailyWorkoutCounts[tokyoDay], 1)
            XCTAssertEqual(tokyoStats.destination(for: start, calendar: tokyo), .workoutDetail(first.id))
            XCTAssertEqual(OverviewWorkoutLoader.sessions(all, on: start, calendar: tokyo).map(\.id), [first.id])
        }
    }

}
