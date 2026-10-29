import Foundation
import XCTest

@testable import KASANE

@MainActor
final class ReplayFinishPresentationTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    func testBannerIsHiddenWithoutCompletedWorkout() throws {
        let incomplete = WorkoutSession(
            startedAt: try date(year: 2026, month: 4, day: 1),
            endedAt: nil
        )

        XCTAssertFalse(
            OverviewReplayBannerPresentation(
                workouts: [],
                referenceDate: try date(year: 2026, month: 10, day: 29),
                calendar: utcCalendar
            ).isVisible
        )
        XCTAssertFalse(
            OverviewReplayBannerPresentation(
                workouts: [incomplete],
                referenceDate: try date(year: 2026, month: 10, day: 29),
                calendar: utcCalendar
            ).isVisible
        )
    }

    func testPastCompletedWorkoutShowsBannerForCurrentYear() throws {
        let completedAt = try date(year: 2024, month: 6, day: 1)
        let pastWorkout = WorkoutSession(
            startedAt: completedAt,
            endedAt: completedAt.addingTimeInterval(600)
        )

        let presentation = OverviewReplayBannerPresentation(
            workouts: [pastWorkout],
            referenceDate: try date(year: 2026, month: 10, day: 29),
            calendar: utcCalendar
        )

        XCTAssertTrue(presentation.isVisible)
        XCTAssertEqual(presentation.year, 2026)
        XCTAssertEqual(presentation.title, "2026 KASANE Replay")
    }

    func testClosingUsesCurrentAndPastYearMessagesAndWorkoutCount() {
        let current = ReplayClosingPresentation(
            stats: makeStats(year: 2026, workoutCount: 42),
            currentYear: 2026
        )
        let past = ReplayClosingPresentation(
            stats: makeStats(year: 2024, workoutCount: 12),
            currentYear: 2026
        )

        XCTAssertEqual(current.year, 2026)
        XCTAssertEqual(current.message, "今年も、積み重ねた。")
        XCTAssertEqual(current.workoutCount, 42)
        XCTAssertEqual(past.year, 2024)
        XCTAssertEqual(past.message, "2024年も、積み重ねた。")
        XCTAssertEqual(past.workoutCount, 12)
    }

    private func makeStats(year: Int, workoutCount: Int) -> YearlyReplayStats {
        YearlyReplayStats(
            year: year,
            workoutCount: workoutCount,
            totalVolume: 0,
            totalDuration: 0,
            totalSetCount: 0,
            hasWorkoutLongerThanSixHours: false,
            mostTrained: nil,
            biggestGrowth: nil,
            personalRecordCount: 0
        )
    }

    private func date(year: Int, month: Int, day: Int) throws -> Date {
        try XCTUnwrap(
            utcCalendar.date(from: DateComponents(year: year, month: month, day: day))
        )
    }
}
