import Foundation

/// 概要の「種目の記録」カードで表示する、種目ごとの全期間集計結果。
struct ExerciseOverviewCardContent: Identifiable, Equatable {
    /// 種目の永続ID。将来の詳細画面への接続にも使用する。
    let exerciseID: UUID
    /// 現在の種目表示名。
    let exerciseName: String
    /// 種目アイコンを決める主対象部位。
    let bodyPart: BodyPart
    /// 最後に完了したワークアウトの終了日時。
    let latestCompletedAt: Date
    /// 全期間での最大重量。
    let currentBestWeightKg: Double
    /// 古い順に並ぶ、直近最大5ワークアウトの最大重量。
    let recentMaxWeightPoints: [ExerciseOverviewPoint]
    /// 最新ワークアウトが過去最高を上回った場合だけ真になる。
    let isLatestPersonalRecord: Bool

    var id: UUID { exerciseID }

    /// 全有効セットが自重の場合、重量グラフを表示しない。
    var showsWeightSparkline: Bool { currentBestWeightKg > 0 }

    /// 種目カードを1要素として公開するためのVoiceOver読み上げ文。
    var accessibilityDescription: String {
        var components = [
            exerciseName,
            "現在のベスト \(spokenBestWeight)",
            "最終実施日 \(latestCompletedAt.formatted(.dateTime.month().day()))",
        ]
        if isLatestPersonalRecord { components.append("自己ベスト") }
        guard showsWeightSparkline else { return components.joined(separator: "、") }

        components.append("直近の重量推移")
        components.append(
            contentsOf: recentMaxWeightPoints.map {
                "\($0.completedAt.formatted(.dateTime.month().day())) \(spokenWeight($0.maxWeightKg))"
            }
        )
        return components.joined(separator: "、")
    }

    private var spokenBestWeight: String {
        showsWeightSparkline ? spokenWeight(currentBestWeightKg) : "自重"
    }

    private func spokenWeight(_ weightKg: Double) -> String {
        "\(WorkoutSetDisplayFormatter.editableWeightValue(weightKg))キログラム"
    }
}

/// 1回のワークアウトにおける種目の最大重量。
struct ExerciseOverviewPoint: Identifiable, Equatable {
    /// ワークアウトID。同時刻の記録も一意に識別する。
    let workoutID: UUID
    /// ワークアウトの完了日時。
    let completedAt: Date
    /// そのワークアウトでの最大重量。
    let maxWeightKg: Double

    var id: UUID { workoutID }
}

/// 完了済みワークアウト履歴から、概要の種目カードを決定論的に組み立てる。
enum ExerciseOverviewCardBuilder {
    /// 有効セットを持つ種目をExercise IDごとに集計し、最終実施日の降順で返す。
    static func build(sessions: [WorkoutSession]) -> [ExerciseOverviewCardContent] {
        build(entries: sessions.flatMap(\.exerciseEntries))
    }

    /// 先読み済みのExerciseEntryから、種目カードを決定論的に組み立てる。
    static func build(entries: [ExerciseEntry]) -> [ExerciseOverviewCardContent] {
        var records: [UUID: ExerciseRecord] = [:]

        for entry in entries {
            guard
                let session = entry.workoutSession,
                let completedAt = session.endedAt,
                let exercise = entry.exercise
            else { continue }
            let validSets = entry.setEntries.filter(isValid)
            guard let maximum = validSets.map(\.weightKg).max() else { continue }

            var record =
                records[exercise.id]
                ?? ExerciseRecord(
                    exerciseName: exercise.name,
                    bodyPart: exercise.bodyPart,
                    points: [:]
                )
            let point = ExerciseOverviewPoint(
                workoutID: session.id,
                completedAt: completedAt,
                maxWeightKg: maximum
            )
            if let existing = record.points[session.id] {
                record.points[session.id] = preferred(point, over: existing)
            } else {
                record.points[session.id] = point
            }
            records[exercise.id] = record
        }

        return records.map { exerciseID, record in
            let points = record.points.values.sorted(by: pointOrder)
            let latest = points[points.count - 1]
            let currentBest = points.map(\.maxWeightKg).max() ?? 0
            let precedingBest = points.dropLast().map(\.maxWeightKg).max()
            return ExerciseOverviewCardContent(
                exerciseID: exerciseID,
                exerciseName: record.exerciseName,
                bodyPart: record.bodyPart,
                latestCompletedAt: latest.completedAt,
                currentBestWeightKg: currentBest,
                recentMaxWeightPoints: Array(points.suffix(5)),
                isLatestPersonalRecord: precedingBest.map { latest.maxWeightKg > $0 } ?? false
            )
        }
        .sorted { lhs, rhs in
            if lhs.latestCompletedAt != rhs.latestCompletedAt {
                return lhs.latestCompletedAt > rhs.latestCompletedAt
            }
            if lhs.exerciseName != rhs.exerciseName { return lhs.exerciseName < rhs.exerciseName }
            return lhs.exerciseID.uuidString < rhs.exerciseID.uuidString
        }
    }

    private struct ExerciseRecord {
        let exerciseName: String
        let bodyPart: BodyPart
        var points: [UUID: ExerciseOverviewPoint]
    }

    /// 保存済みWorkoutの意味を持つ、重量と回数が妥当なセットだけを採用する。
    private static func isValid(_ set: SetEntry) -> Bool {
        set.weightKg.isFinite && set.weightKg >= 0 && set.reps > 0
    }

    private static func preferred(
        _ candidate: ExerciseOverviewPoint,
        over existing: ExerciseOverviewPoint
    ) -> ExerciseOverviewPoint {
        candidate.maxWeightKg > existing.maxWeightKg ? candidate : existing
    }

    private static func pointOrder(_ lhs: ExerciseOverviewPoint, _ rhs: ExerciseOverviewPoint) -> Bool {
        if lhs.completedAt != rhs.completedAt { return lhs.completedAt < rhs.completedAt }
        return lhs.workoutID.uuidString < rhs.workoutID.uuidString
    }
}
