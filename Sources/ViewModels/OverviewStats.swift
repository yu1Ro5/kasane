import Foundation

/// 完了済みWorkoutの履歴から、選択月のダッシュボード表示を一度に算出する。
struct OverviewStats {
    struct Highlight: Identifiable, Equatable {
        enum Kind { case personalRecord, improvement }

        let kind: Kind
        let exerciseID: UUID
        let exerciseName: String
        let weight: Double
        let improvement: Double
        let date: Date

        var id: String { "\(exerciseID.uuidString)-\(date.timeIntervalSince1970)-\(kind)" }
    }

    let month: Date
    let workoutCount: Int
    let duration: TimeInterval
    let totalVolume: Double
    let dailyWorkoutCounts: [Date: Int]
    let streak: Int
    let personalRecord: Highlight?
    let improvement: Highlight?

    init(
        sessions: [WorkoutSession],
        now: Date,
        referenceDate: Date? = nil,
        calendar: Calendar
    ) {
        let interval = calendar.dateInterval(of: .month, for: now)
        month = interval?.start ?? now
        let completed = sessions.filter { $0.endedAt != nil }
        let included = completed.filter {
            guard let interval else { return false }
            return $0.startedAt >= interval.start && $0.startedAt < interval.end
        }

        workoutCount = included.count
        duration = included.reduce(0) {
            $0 + max($1.endedAt?.timeIntervalSince($1.startedAt) ?? 0, 0)
        }
        totalVolume = included.reduce(0) { total, session in
            total
                + session.exerciseEntries.flatMap(\.setEntries).reduce(0) {
                    $0 + max($1.weightKg, 0) * Double(max($1.reps, 0))
                }
        }
        dailyWorkoutCounts = Dictionary(grouping: included) {
            calendar.startOfDay(for: $0.startedAt)
        }.mapValues(\.count)
        streak = Self.weeklyStreak(
            sessions: completed,
            selectedMonth: now,
            referenceDate: referenceDate ?? now,
            calendar: calendar
        )
        let highlights = Self.highlights(
            sessions: completed,
            monthInterval: interval,
            calendar: calendar
        )
        personalRecord = highlights.personalRecord
        improvement = highlights.improvement
    }

    var durationText: String {
        if duration > 0 && duration < 60 { return "1分未満" }
        let minutes = Int(duration / 60)
        return minutes >= 60 ? "\(minutes / 60)時間\(minutes % 60)分" : "\(minutes)分"
    }

    var totalVolumeText: String {
        if totalVolume >= 1_000 {
            return (totalVolume / 1_000).formatted(.number.precision(.fractionLength(1))) + "t"
        }
        return totalVolume.formatted(.number.precision(.fractionLength(0...1))) + "kg"
    }

    static func weeklyStreak(
        sessions: [WorkoutSession],
        selectedMonth: Date,
        referenceDate: Date,
        calendar: Calendar
    ) -> Int {
        guard let month = calendar.dateInterval(of: .month, for: selectedMonth) else { return 0 }
        let currentMonth = calendar.isDate(selectedMonth, equalTo: referenceDate, toGranularity: .month)
        let cutoff = currentMonth ? referenceDate : month.end.addingTimeInterval(-1)
        let activeWeeks = Set(
            sessions.compactMap { session -> Date? in
                guard session.endedAt != nil, session.startedAt <= cutoff else { return nil }
                return calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start
            })
        guard var week = calendar.dateInterval(of: .weekOfYear, for: cutoff)?.start else { return 0 }
        if !activeWeeks.contains(week),
            let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week)
        {
            week = previous
        }
        var count = 0
        while activeWeeks.contains(week) {
            count += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else {
                break
            }
            week = previous
        }
        return count
    }

    private static func highlights(
        sessions: [WorkoutSession],
        monthInterval: DateInterval?,
        calendar: Calendar
    ) -> (personalRecord: Highlight?, improvement: Highlight?) {
        guard let monthInterval else { return (nil, nil) }
        var allTimeBest: [UUID: Double] = [:]
        var previousWorkoutBest: [UUID: Double] = [:]
        var records: [Highlight] = []
        var improvements: [Highlight] = []

        let ordered = sessions.filter { $0.endedAt != nil }.sorted {
            if $0.startedAt != $1.startedAt { return $0.startedAt < $1.startedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        for session in ordered {
            var workoutBest: [UUID: (name: String, weight: Double)] = [:]
            for entry in session.exerciseEntries {
                guard let exerciseID = entry.exercise?.id,
                    let maximum = entry.setEntries.map(\.weightKg).max()
                else { continue }
                let existing = workoutBest[exerciseID]?.weight ?? -.infinity
                if maximum > existing {
                    workoutBest[exerciseID] = (entry.exerciseNameSnapshot, maximum)
                }
            }
            for (exerciseID, value) in workoutBest {
                let previous = previousWorkoutBest[exerciseID]
                let best = allTimeBest[exerciseID]
                if monthInterval.contains(session.startedAt), let previous {
                    if let best, value.weight > best {
                        records.append(
                            Highlight(
                                kind: .personalRecord,
                                exerciseID: exerciseID,
                                exerciseName: value.name,
                                weight: value.weight,
                                improvement: value.weight - best,
                                date: session.startedAt
                            ))
                    } else if value.weight > previous {
                        improvements.append(
                            Highlight(
                                kind: .improvement,
                                exerciseID: exerciseID,
                                exerciseName: value.name,
                                weight: value.weight,
                                improvement: value.weight - previous,
                                date: session.startedAt
                            ))
                    }
                }
                allTimeBest[exerciseID] = max(best ?? -.infinity, value.weight)
                previousWorkoutBest[exerciseID] = value.weight
            }
        }
        let record = records.max { $0.date < $1.date }
        let improvement = improvements.filter {
            guard let record else { return true }
            return $0.exerciseID != record.exerciseID || !calendar.isDate($0.date, inSameDayAs: record.date)
        }.max { $0.date < $1.date }
        return (record, improvement)
    }
}
