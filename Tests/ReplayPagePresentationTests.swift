import Foundation
import XCTest

@testable import KASANE

final class ReplayPagePresentationTests: XCTestCase {
    func testVolumeUsesKilogramsGroupingAndNeverDisplaysNonFiniteValues() {
        XCTAssertEqual(ReplayActivityPresentation.volumeText(214_520), "214,520kg")
        XCTAssertEqual(ReplayActivityPresentation.volumeText(1_234.56), "1,234.6kg")
        XCTAssertEqual(ReplayActivityPresentation.volumeText(.nan), "0kg")
        XCTAssertEqual(ReplayActivityPresentation.volumeText(.infinity), "0kg")
        XCTAssertEqual(ReplayActivityPresentation.volumeText(-.infinity), "0kg")
    }

    func testDurationUsesTotalSecondsAndOmitsZeroComponents() {
        XCTAssertEqual(ReplayActivityPresentation.durationText(42 * 60 * 60 + 30 * 60), "42時間30分")
        XCTAssertEqual(ReplayActivityPresentation.durationText(45 * 60), "45分")
        XCTAssertEqual(ReplayActivityPresentation.durationText(42 * 60 * 60), "42時間")
        XCTAssertEqual(ReplayActivityPresentation.durationText(0), "0分")
        XCTAssertEqual(ReplayActivityPresentation.durationText(59), "0分")
    }

    func testActivityFormatsZeroAndGroupedSetCount() {
        let zero = ReplayActivityPresentation(stats: makeStats())
        let grouped = ReplayActivityPresentation(stats: makeStats(totalSetCount: 1_248))

        XCTAssertEqual(zero.totalVolumeText, "0kg")
        XCTAssertEqual(zero.totalDurationText, "0分")
        XCTAssertEqual(zero.totalSetCountText, "0セット")
        XCTAssertEqual(grouped.totalSetCountText, "1,248セット")
    }

    func testLongWorkoutWarningDependsOnlyOnAggregatedFlag() {
        XCTAssertNil(ReplayActivityPresentation(stats: makeStats()).warningMessage)
        XCTAssertEqual(
            ReplayActivityPresentation(
                stats: makeStats(totalDuration: 20 * 60 * 60, hasLongWorkout: true)
            ).warningMessage,
            ReplayActivityPresentation.longWorkoutMessage
        )
        XCTAssertNil(
            ReplayActivityPresentation(
                stats: makeStats(totalDuration: 20 * 60 * 60, hasLongWorkout: false)
            ).warningMessage
        )
    }

    func testMostTrainedUsesAggregatedSnapshotNameAndWorkoutCount() {
        let mostTrained = YearlyReplayStats.MostTrained(
            exerciseID: UUID(),
            exerciseName: "保存時のベンチプレス",
            workoutCount: 24,
            setCount: 96
        )

        let presentation = ReplayMostTrainedPresentation(
            stats: makeStats(mostTrained: mostTrained)
        )

        XCTAssertEqual(presentation.title, "2026年にいちばん取り組んだ種目")
        XCTAssertEqual(presentation.exerciseName, "保存時のベンチプレス")
        XCTAssertEqual(presentation.workoutCountText, "24回のワークアウト")
    }

    func testMostTrainedKeepsUnavailableStateWhenAggregationHasNoResult() {
        let presentation = ReplayMostTrainedPresentation(stats: makeStats())

        XCTAssertNil(presentation.exerciseName)
        XCTAssertNil(presentation.workoutCountText)
        XCTAssertEqual(
            ReplayMostTrainedPresentation.unavailableMessage,
            "種目別に振り返れる記録がまだありません"
        )
    }

    private func makeStats(
        totalVolume: Double = 0,
        totalDuration: TimeInterval = 0,
        totalSetCount: Int = 0,
        hasLongWorkout: Bool = false,
        mostTrained: YearlyReplayStats.MostTrained? = nil
    ) -> YearlyReplayStats {
        YearlyReplayStats(
            year: 2026,
            workoutCount: 1,
            totalVolume: totalVolume,
            totalDuration: totalDuration,
            totalSetCount: totalSetCount,
            hasWorkoutLongerThanSixHours: hasLongWorkout,
            mostTrained: mostTrained,
            biggestGrowth: nil,
            personalRecordCount: 0
        )
    }
}
