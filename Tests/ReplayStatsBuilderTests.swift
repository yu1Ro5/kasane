import XCTest

@testable import KASANE

@MainActor
final class ReplayStatsBuilderTests: XCTestCase {
    private struct SetFixture {
        let weight: Double
        let reps: Int
        let isWarmup: Bool

        init(_ weight: Double, _ reps: Int, isWarmup: Bool = false) {
            self.weight = weight
            self.reps = reps
            self.isWarmup = isWarmup
        }
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    func testEmptyHistoryAndIncompleteWorkoutProduceEmptyStats() throws {
        let incomplete = WorkoutSession(startedAt: try date(2025, 6, 1), endedAt: nil)

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [incomplete],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.year, 2025)
        XCTAssertEqual(stats.workoutCount, 0)
        XCTAssertEqual(stats.totalVolume, 0)
        XCTAssertEqual(stats.totalDuration, 0)
        XCTAssertEqual(stats.totalSetCount, 0)
        XCTAssertFalse(stats.hasWorkoutLongerThanSixHours)
        XCTAssertNil(stats.mostTrained)
        XCTAssertNil(stats.biggestGrowth)
        XCTAssertEqual(stats.personalRecordCount, 0)
    }

    func testSingleWorkoutAggregatesActivityWithoutInventingGrowthOrPR() throws {
        let exercise = Exercise(name: "保存時の種目名", primaryBodyPart: .chest)
        let workout = makeWorkout(start: try date(2025, 2, 3), duration: 45)
        addEntry(
            to: workout,
            exercise: exercise,
            sets: [SetFixture(10, 5), SetFixture(0, 3, isWarmup: true), SetFixture(100, 0)]
        )
        exercise.name = "変更後の種目名"

        let stats = ReplayStatsBuilder.build(year: 2025, workouts: [workout], calendar: utcCalendar)

        XCTAssertEqual(stats.workoutCount, 1)
        XCTAssertEqual(stats.totalVolume, 50)
        XCTAssertEqual(stats.totalDuration, 45)
        XCTAssertEqual(stats.totalSetCount, 2)
        XCTAssertEqual(stats.mostTrained?.exerciseName, "保存時の種目名")
        XCTAssertEqual(stats.mostTrained?.workoutCount, 1)
        XCTAssertNil(stats.biggestGrowth)
        XCTAssertEqual(stats.personalRecordCount, 0)
    }

    func testYearUsesStartedAtHalfOpenBoundaryCurrentTimeZoneAndKeepsCrossYearDuration() throws {
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let beforeBoundary = makeWorkout(
            start: try date(2024, 12, 31, 23, 59, calendar: losAngeles),
            duration: 120
        )
        let atBoundary = makeWorkout(
            start: try date(2025, 1, 1, 0, 0, calendar: losAngeles),
            duration: 60
        )
        let leapDay = makeWorkout(
            start: try date(2024, 2, 29, 12, 0, calendar: losAngeles),
            duration: 30
        )

        let localStats = ReplayStatsBuilder.build(
            year: 2024,
            workouts: [atBoundary, beforeBoundary, leapDay],
            calendar: losAngeles
        )
        let utcStats = ReplayStatsBuilder.build(
            year: 2024,
            workouts: [atBoundary, beforeBoundary, leapDay],
            calendar: utcCalendar
        )

        XCTAssertEqual(localStats.workoutCount, 2)
        XCTAssertEqual(localStats.totalDuration, 150)
        XCTAssertEqual(utcStats.workoutCount, 1)
        XCTAssertEqual(
            ReplayStatsBuilder.build(
                year: 2025,
                workouts: [atBoundary, beforeBoundary, leapDay],
                calendar: losAngeles
            ).workoutCount,
            1
        )
    }

    func testInvalidNumbersAreExcludedWhileValidSetsAndRecordedLongDurationRemain() throws {
        let exercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let longWorkout = makeWorkout(start: try date(2025, 3, 1), duration: 7 * 60 * 60)
        addEntry(
            to: longWorkout,
            exercise: exercise,
            sets: [
                SetFixture(2, 3),
                SetFixture(-10, 5),
                SetFixture(.nan, 2),
                SetFixture(.infinity, 2),
                SetFixture(.greatestFiniteMagnitude, 2),
                SetFixture(100, 0),
            ]
        )
        let reversedDates = WorkoutSession(
            startedAt: try date(2025, 4, 1),
            endedAt: try date(2025, 3, 31)
        )

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [longWorkout, reversedDates],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.totalVolume, 6)
        XCTAssertEqual(stats.totalSetCount, 5)
        XCTAssertEqual(stats.totalDuration, 7 * 60 * 60)
        XCTAssertTrue(stats.hasWorkoutLongerThanSixHours)
    }

    func testDurationIsSummedInSecondsBeforeAnyMinuteConversion() throws {
        let first = makeWorkout(start: try date(2025, 1, 1), duration: 40)
        let second = makeWorkout(start: try date(2025, 1, 2), duration: 40)
        let exactlySixHours = makeWorkout(start: try date(2025, 1, 3), duration: 6 * 60 * 60)

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [first, second, exactlySixHours],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.totalDuration, 6 * 60 * 60 + 80)
        XCTAssertFalse(stats.hasWorkoutLongerThanSixHours)
    }

    func testMostTrainedCountsUniqueWorkoutsAndUsesSetCountTieBreakerAcrossDuplicateEntries() throws {
        let first = Exercise(name: "種目A", primaryBodyPart: .other)
        let second = Exercise(name: "種目B", primaryBodyPart: .other)
        let firstWorkout = makeWorkout(start: try date(2025, 1, 1))
        addEntry(to: firstWorkout, exercise: first, sets: [SetFixture(10, 1)])
        addEntry(to: firstWorkout, exercise: first, sets: [SetFixture(10, 1)])
        addEntry(
            to: firstWorkout,
            exercise: second,
            sets: [SetFixture(10, 1), SetFixture(10, 1), SetFixture(10, 1)]
        )
        let detached = addEntry(
            to: firstWorkout,
            exercise: Exercise(name: "参照なし", primaryBodyPart: .other),
            sets: [SetFixture(2, 2)]
        )
        detached.exercise = nil
        let secondWorkout = makeWorkout(start: try date(2025, 2, 1))
        addEntry(to: secondWorkout, exercise: first, sets: [SetFixture(10, 1)])
        addEntry(to: secondWorkout, exercise: second, sets: [SetFixture(10, 1)])

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [firstWorkout, secondWorkout],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.mostTrained?.exerciseID, second.id)
        XCTAssertEqual(stats.mostTrained?.workoutCount, 2)
        XCTAssertEqual(stats.mostTrained?.setCount, 4)
        XCTAssertEqual(stats.totalSetCount, 8)
        XCTAssertEqual(stats.totalVolume, 74)
    }

    func testMostTrainedUsesExerciseIDForCompleteTie() throws {
        let lowerID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higherID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let lower = Exercise(id: lowerID, name: "Low", primaryBodyPart: .other)
        let higher = Exercise(id: higherID, name: "High", primaryBodyPart: .other)
        let workout = makeWorkout(start: try date(2025, 1, 1))
        addEntry(to: workout, exercise: higher, sets: [SetFixture(1, 1)])
        addEntry(to: workout, exercise: lower, sets: [SetFixture(1, 1)])

        let stats = ReplayStatsBuilder.build(year: 2025, workouts: [workout], calendar: utcCalendar)

        XCTAssertEqual(stats.mostTrained?.exerciseID, lowerID)
    }

    func testBiggestGrowthUsesEpleyWorkoutMaximumAndRejectsInvalidSets() throws {
        let exercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let baseline = makeWorkout(start: try date(2025, 1, 1))
        addEntry(
            to: baseline,
            exercise: exercise,
            sets: [SetFixture(100, 1), SetFixture(500, 10, isWarmup: true)]
        )
        let middle = makeWorkout(start: try date(2025, 2, 1))
        addEntry(
            to: middle,
            exercise: exercise,
            sets: [
                SetFixture(90, 10),
                SetFixture(1_000, 16),
                SetFixture(0, 10),
                SetFixture(.nan, 10),
            ]
        )
        addEntry(to: middle, exercise: exercise, sets: [SetFixture(100, 5)])
        let peak = makeWorkout(start: try date(2025, 3, 1))
        let peakEntry = addEntry(to: peak, exercise: exercise, sets: [SetFixture(95, 10)])
        peakEntry.exerciseNameSnapshot = "ピーク時の種目名"

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [middle, peak, baseline],
            calendar: utcCalendar
        )
        let growth = try XCTUnwrap(stats.biggestGrowth)

        XCTAssertEqual(growth.exerciseName, "ピーク時の種目名")
        XCTAssertEqual(growth.baselineEstimatedOneRepMax, 100, accuracy: 0.000_001)
        XCTAssertEqual(growth.peakEstimatedOneRepMax, 95 * (1 + 10.0 / 30), accuracy: 0.000_001)
        XCTAssertEqual(growth.growthRate, 26.666_666_666_7, accuracy: 0.000_001)
    }

    func testBiggestGrowthTieUsesAbsoluteGrowthThenExerciseID() throws {
        let lowerID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higherID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let small = Exercise(id: lowerID, name: "Small", primaryBodyPart: .other)
        let large = Exercise(id: higherID, name: "Large", primaryBodyPart: .other)
        let baseline = makeWorkout(start: try date(2025, 1, 1))
        addEntry(to: baseline, exercise: small, sets: [SetFixture(100, 1)])
        addEntry(to: baseline, exercise: large, sets: [SetFixture(200, 1)])
        let peak = makeWorkout(start: try date(2025, 2, 1))
        addEntry(to: peak, exercise: small, sets: [SetFixture(120, 1)])
        addEntry(to: peak, exercise: large, sets: [SetFixture(240, 1)])

        var stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [baseline, peak],
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.biggestGrowth?.exerciseID, higherID)

        for entry in baseline.exerciseEntries where entry.exercise?.id == higherID {
            entry.setEntries[0].weightKg = 100
        }
        for entry in peak.exerciseEntries where entry.exercise?.id == higherID {
            entry.setEntries[0].weightKg = 120
        }
        stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [baseline, peak],
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.biggestGrowth?.exerciseID, lowerID)
    }

    func testSameTimestampGrowthBaselineUsesWorkoutIDOrder() throws {
        let lowerID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higherID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let exercise = Exercise(name: "デッドリフト", primaryBodyPart: .back)
        let startedAt = try date(2025, 1, 1)
        let lower = makeWorkout(id: lowerID, start: startedAt)
        addEntry(to: lower, exercise: exercise, sets: [SetFixture(100, 1)])
        let higher = makeWorkout(id: higherID, start: startedAt)
        addEntry(to: higher, exercise: exercise, sets: [SetFixture(150, 1)])

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [higher, lower],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.biggestGrowth?.baselineEstimatedOneRepMax, 100)
        XCTAssertEqual(stats.biggestGrowth?.peakEstimatedOneRepMax, 150)
    }

    func testAnnualPRCountUsesDetectorWithPastYearsAndDeduplicatesSameExercisePerWorkout() throws {
        let exercise = Exercise(name: "スクワット", primaryBodyPart: .legs)
        let otherEstablished = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let firstEver = Exercise(name: "初回種目", primaryBodyPart: .other)
        let historical = makeWorkout(start: try date(2024, 12, 1))
        addEntry(to: historical, exercise: exercise, sets: [SetFixture(100, 5)])
        addEntry(to: historical, exercise: otherEstablished, sets: [SetFixture(50, 5)])
        let firstUpdate = makeWorkout(start: try date(2025, 1, 1))
        addEntry(to: firstUpdate, exercise: exercise, sets: [SetFixture(110, 5)])
        addEntry(to: firstUpdate, exercise: exercise, sets: [SetFixture(120, 5)])
        addEntry(to: firstUpdate, exercise: otherEstablished, sets: [SetFixture(60, 5)])
        addEntry(to: firstUpdate, exercise: firstEver, sets: [SetFixture(50, 5)])
        let equal = makeWorkout(start: try date(2025, 2, 1))
        addEntry(to: equal, exercise: exercise, sets: [SetFixture(120, 5)])
        let secondUpdate = makeWorkout(start: try date(2025, 3, 1))
        addEntry(to: secondUpdate, exercise: exercise, sets: [SetFixture(130, 5)])

        let stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [firstUpdate, equal, historical, secondUpdate],
            calendar: utcCalendar
        )

        XCTAssertEqual(stats.personalRecordCount, 3)
    }

    func testRebuildingReflectsWorkoutEditsAndDeletion() throws {
        let exercise = Exercise(name: "ベンチプレス", primaryBodyPart: .chest)
        let baseline = makeWorkout(start: try date(2025, 1, 1))
        addEntry(to: baseline, exercise: exercise, sets: [SetFixture(100, 1)])
        let peak = makeWorkout(start: try date(2025, 2, 1))
        let peakEntry = addEntry(to: peak, exercise: exercise, sets: [SetFixture(120, 1)])

        var stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [baseline, peak],
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.totalVolume, 220)
        XCTAssertEqual(stats.biggestGrowth?.growthRate, 20)

        peakEntry.setEntries[0].weightKg = 130
        stats = ReplayStatsBuilder.build(
            year: 2025,
            workouts: [baseline, peak],
            calendar: utcCalendar
        )
        XCTAssertEqual(stats.totalVolume, 230)
        XCTAssertEqual(stats.biggestGrowth?.growthRate, 30)

        stats = ReplayStatsBuilder.build(year: 2025, workouts: [baseline], calendar: utcCalendar)
        XCTAssertEqual(stats.workoutCount, 1)
        XCTAssertEqual(stats.totalVolume, 100)
        XCTAssertNil(stats.biggestGrowth)
    }

    @discardableResult
    private func addEntry(
        to workout: WorkoutSession,
        exercise: Exercise,
        sets: [SetFixture]
    ) -> ExerciseEntry {
        let entry = ExerciseEntry(
            workoutSession: workout,
            exercise: exercise,
            order: workout.exerciseEntries.count
        )
        workout.exerciseEntries.append(entry)
        for (order, fixture) in sets.enumerated() {
            entry.setEntries.append(
                SetEntry(
                    exerciseEntry: entry,
                    order: order,
                    weightKg: fixture.weight,
                    reps: fixture.reps,
                    isWarmup: fixture.isWarmup
                )
            )
        }
        return entry
    }

    private func makeWorkout(
        id: UUID = UUID(),
        start: Date,
        duration: TimeInterval = 10 * 60
    ) -> WorkoutSession {
        WorkoutSession(id: id, startedAt: start, endedAt: start.addingTimeInterval(duration))
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 12,
        _ minute: Int = 0,
        calendar: Calendar? = nil
    ) throws -> Date {
        let calendar = calendar ?? utcCalendar
        return try XCTUnwrap(
            calendar.date(
                from: DateComponents(
                    year: year,
                    month: month,
                    day: day,
                    hour: hour,
                    minute: minute
                )
            )
        )
    }
}
