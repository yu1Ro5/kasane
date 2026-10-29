import Foundation
import Observation

enum ReplayPage: Int, CaseIterable, Identifiable {
    case intro
    case activity
    case mostTrained
    case growthAndPersonalRecords
    case closing

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .intro: "Intro"
        case .activity: "Activity"
        case .mostTrained: "Most Trained"
        case .growthAndPersonalRecords: "Growth & PR"
        case .closing: "Closing"
        }
    }
}

@MainActor
@Observable
final class ReplayViewModel {
    private let calendar: Calendar
    private let referenceDate: Date
    private var workouts: [WorkoutSession]

    private(set) var availableYears: [Int]
    private(set) var selectedYear: Int
    private(set) var stats: YearlyReplayStats
    private(set) var selectedPage: ReplayPage = .intro

    init(
        workouts: [WorkoutSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        self.referenceDate = referenceDate
        self.workouts = workouts

        let currentYear = calendar.component(.year, from: referenceDate)
        availableYears = Self.availableYears(
            workouts: workouts,
            referenceDate: referenceDate,
            calendar: calendar
        )
        selectedYear = currentYear
        stats = ReplayStatsBuilder.build(
            year: currentYear,
            workouts: workouts,
            calendar: calendar
        )
    }

    var pagePosition: Int {
        selectedPage.rawValue + 1
    }

    var currentYear: Int {
        calendar.component(.year, from: referenceDate)
    }

    var canGoBack: Bool {
        selectedPage != .intro
    }

    func selectYear(_ year: Int) {
        guard availableYears.contains(year), year != selectedYear else { return }
        selectedYear = year
        selectedPage = .intro
        recalculateStats()
    }

    func showPage(_ page: ReplayPage) {
        selectedPage = page
    }

    func showPreviousPage() {
        guard let previous = ReplayPage(rawValue: selectedPage.rawValue - 1) else { return }
        selectedPage = previous
    }

    func showNextPage() {
        selectedPage = ReplayPage(rawValue: selectedPage.rawValue + 1) ?? .intro
    }

    func restart() {
        selectedPage = .intro
    }

    func update(workouts: [WorkoutSession]) {
        self.workouts = workouts
        let updatedYears = Self.availableYears(
            workouts: workouts,
            referenceDate: referenceDate,
            calendar: calendar
        )
        availableYears = updatedYears

        if !updatedYears.contains(selectedYear) {
            selectedYear = calendar.component(.year, from: referenceDate)
            selectedPage = .intro
        }
        recalculateStats()
    }

    static func availableYears(
        workouts: [WorkoutSession],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> [Int] {
        let currentYear = calendar.component(.year, from: referenceDate)
        var years: Set<Int> = [currentYear]

        for workout in workouts where workout.endedAt != nil {
            let workoutYear = calendar.component(.year, from: workout.startedAt)
            if workoutYear < currentYear {
                years.insert(workoutYear)
            }
        }

        return years.sorted(by: >)
    }

    private func recalculateStats() {
        stats = ReplayStatsBuilder.build(
            year: selectedYear,
            workouts: workouts,
            calendar: calendar
        )
    }
}
