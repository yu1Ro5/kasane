import Foundation
import XCTest

@testable import KASANE

@MainActor
final class ReplayViewModelTests: XCTestCase {
    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    func testAvailableYearsIncludeCurrentAndOnlyPastYearsWithCompletedWorkouts() throws {
        let current = try completedWorkout(year: 2026)
        let recentPast = try completedWorkout(year: 2025)
        let olderPast = try completedWorkout(year: 2023)
        let duplicatePast = try completedWorkout(year: 2025)
        let incompletePast = WorkoutSession(startedAt: try date(year: 2024), endedAt: nil)
        let future = try completedWorkout(year: 2027)

        let years = ReplayViewModel.availableYears(
            workouts: [olderPast, future, duplicatePast, incompletePast, current, recentPast],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )

        XCTAssertEqual(years, [2026, 2025, 2023])
    }

    func testInitialSelectionIsCurrentYearEvenWhenOnlyPastWorkoutsExist() throws {
        let viewModel = ReplayViewModel(
            workouts: [try completedWorkout(year: 2024)],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )

        XCTAssertEqual(viewModel.availableYears, [2026, 2024])
        XCTAssertEqual(viewModel.selectedYear, 2026)
        XCTAssertEqual(viewModel.selectedPage, .intro)
        XCTAssertEqual(viewModel.stats.year, 2026)
    }

    func testCurrentYearWithoutCompletedWorkoutsProducesEmptyStats() throws {
        let incomplete = WorkoutSession(startedAt: try date(year: 2026), endedAt: nil)
        let viewModel = ReplayViewModel(
            workouts: [incomplete, try completedWorkout(year: 2025)],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )

        XCTAssertEqual(viewModel.selectedYear, 2026)
        XCTAssertEqual(viewModel.stats.workoutCount, 0)
        XCTAssertEqual(viewModel.availableYears, [2026, 2025])
    }

    func testChangingYearRecalculatesStatsAndReturnsToIntro() throws {
        let workouts = [
            try completedWorkout(year: 2026),
            try completedWorkout(year: 2025, month: 2),
            try completedWorkout(year: 2025, month: 8),
        ]
        let viewModel = ReplayViewModel(
            workouts: workouts,
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )
        viewModel.showPage(.growthAndPersonalRecords)

        viewModel.selectYear(2025)

        XCTAssertEqual(viewModel.selectedYear, 2025)
        XCTAssertEqual(viewModel.selectedPage, .intro)
        XCTAssertEqual(viewModel.stats.year, 2025)
        XCTAssertEqual(viewModel.stats.workoutCount, 2)
    }

    func testUpdatingHistoryRecalculatesSelectedYearAndFallsBackWhenYearDisappears() throws {
        let current = try completedWorkout(year: 2026)
        let past = try completedWorkout(year: 2025)
        let viewModel = ReplayViewModel(
            workouts: [current, past],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )
        viewModel.selectYear(2025)
        viewModel.showPage(.activity)

        viewModel.update(workouts: [current])

        XCTAssertEqual(viewModel.availableYears, [2026])
        XCTAssertEqual(viewModel.selectedYear, 2026)
        XCTAssertEqual(viewModel.selectedPage, .intro)
        XCTAssertEqual(viewModel.stats.workoutCount, 1)
    }

    func testAdvancingFromClosingReturnsToIntro() throws {
        let viewModel = ReplayViewModel(
            workouts: [try completedWorkout(year: 2026)],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )
        viewModel.showPage(.closing)

        viewModel.showNextPage()

        XCTAssertEqual(viewModel.selectedPage, .intro)
    }

    private func completedWorkout(
        year: Int,
        month: Int = 1,
        day: Int = 1
    ) throws -> WorkoutSession {
        let startedAt = try XCTUnwrap(
            utcCalendar.date(from: DateComponents(year: year, month: month, day: day))
        )
        return WorkoutSession(startedAt: startedAt, endedAt: startedAt.addingTimeInterval(60))
    }

    private func date(year: Int, month: Int = 1, day: Int = 1) throws -> Date {
        try XCTUnwrap(utcCalendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
