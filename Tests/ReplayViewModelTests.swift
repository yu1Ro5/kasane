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

    func testChangingYearUpdatesActivityAndMostTrainedValues() throws {
        let currentExercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let pastExercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let currentWorkout = try completedWorkout(year: 2026)
        let pastWorkout = try completedWorkout(year: 2025)
        addEntry(to: currentWorkout, exercise: currentExercise, weight: 80, reps: 5)
        addEntry(to: pastWorkout, exercise: pastExercise, weight: 100, reps: 10)
        let viewModel = ReplayViewModel(
            workouts: [currentWorkout, pastWorkout],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )

        let currentActivity = ReplayActivityPresentation(stats: viewModel.stats)
        let currentMostTrained = ReplayMostTrainedPresentation(stats: viewModel.stats)
        viewModel.selectYear(2025)
        let pastActivity = ReplayActivityPresentation(stats: viewModel.stats)
        let pastMostTrained = ReplayMostTrainedPresentation(stats: viewModel.stats)

        XCTAssertEqual(currentActivity.totalVolumeText, "400kg")
        XCTAssertEqual(currentMostTrained.exerciseName, "スクワット")
        XCTAssertEqual(pastActivity.totalVolumeText, "1,000kg")
        XCTAssertEqual(pastMostTrained.exerciseName, "ベンチプレス")
    }

    func testChangingYearUpdatesGrowthAndPersonalRecordValues() throws {
        let exercise = Exercise(name: "チェストプレス", primaryBodyPart: .chest)
        let pastBaseline = try completedWorkout(year: 2025, month: 1)
        let pastPeak = try completedWorkout(year: 2025, month: 6)
        let currentBaseline = try completedWorkout(year: 2026, month: 1)
        let currentPeak = try completedWorkout(year: 2026, month: 6)
        addEntry(to: pastBaseline, exercise: exercise, weight: 50, reps: 1)
        addEntry(to: pastPeak, exercise: exercise, weight: 60, reps: 1)
        addEntry(to: currentBaseline, exercise: exercise, weight: 70, reps: 1)
        addEntry(to: currentPeak, exercise: exercise, weight: 90, reps: 1)
        let viewModel = ReplayViewModel(
            workouts: [currentPeak, pastPeak, currentBaseline, pastBaseline],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )

        let current = ReplayGrowthPresentation(stats: viewModel.stats)
        viewModel.selectYear(2025)
        let past = ReplayGrowthPresentation(stats: viewModel.stats)

        XCTAssertEqual(current.growth?.growthRateText, "+28.6%")
        XCTAssertEqual(current.growth?.estimatedOneRepMaxRangeText, "70.0kg → 90.0kg")
        XCTAssertEqual(current.personalRecordCountText, "2回")
        XCTAssertEqual(past.growth?.growthRateText, "+20.0%")
        XCTAssertEqual(past.growth?.estimatedOneRepMaxRangeText, "50.0kg → 60.0kg")
        XCTAssertEqual(past.personalRecordCountText, "1回")
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

    func testAllFivePagesAdvanceInOrderAndRestartKeepsSelectedYear() throws {
        let viewModel = ReplayViewModel(
            workouts: [
                try completedWorkout(year: 2026),
                try completedWorkout(year: 2025),
            ],
            referenceDate: try date(year: 2026, month: 10, day: 27),
            calendar: utcCalendar
        )
        viewModel.selectYear(2025)

        XCTAssertEqual(
            ReplayPage.allCases,
            [.intro, .activity, .mostTrained, .growthAndPersonalRecords, .closing]
        )
        for expectedPage in ReplayPage.allCases.dropFirst() {
            viewModel.showNextPage()
            XCTAssertEqual(viewModel.selectedPage, expectedPage)
        }

        viewModel.restart()

        XCTAssertEqual(viewModel.selectedPage, .intro)
        XCTAssertEqual(viewModel.selectedYear, 2025)
        XCTAssertEqual(viewModel.stats.year, 2025)
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

    private func addEntry(
        to workout: WorkoutSession,
        exercise: Exercise,
        weight: Double,
        reps: Int
    ) {
        let entry = ExerciseEntry(
            workoutSession: workout,
            exercise: exercise,
            order: workout.exerciseEntries.count
        )
        entry.setEntries.append(
            SetEntry(
                exerciseEntry: entry,
                order: 0,
                weightKg: weight,
                reps: reps
            )
        )
        workout.exerciseEntries.append(entry)
    }

    private func date(year: Int, month: Int = 1, day: Int = 1) throws -> Date {
        try XCTUnwrap(utcCalendar.date(from: DateComponents(year: year, month: month, day: day)))
    }
}
