import Foundation
import SwiftData

struct SetEntryDraft: Equatable {
    var weight = ""
    var reps = ""

    var isEmpty: Bool {
        weight.isEmpty && reps.isEmpty
    }

    func values(decimalSeparator: String = Locale.current.decimalSeparator ?? ".") -> (weight: Double, reps: Int)? {
        let escapedSeparator = NSRegularExpression.escapedPattern(for: decimalSeparator)
        guard
            weight.range(of: "^[0-9]+(?:\(escapedSeparator)[0-9]{0,2})?$", options: .regularExpression)
                != nil,
            reps.range(of: "^[0-9]+$", options: .regularExpression) != nil
        else { return nil }

        let normalizedWeight = weight.replacingOccurrences(of: decimalSeparator, with: ".")
        guard
            let parsedWeight = Double(normalizedWeight), parsedWeight.isFinite, parsedWeight >= 0,
            let parsedReps = Int(reps), parsedReps > 0
        else { return nil }
        return (parsedWeight, parsedReps)
    }

    static func savedValues(
        from entry: SetEntry,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> SetEntryDraft {
        let asciiWeight = String(
            format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), entry.weightKg
        )
        .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)

        return SetEntryDraft(
            weight: asciiWeight.replacingOccurrences(of: ".", with: decimalSeparator),
            reps: String(entry.reps)
        )
    }

    func hasChanges(
        from entry: SetEntry,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> Bool {
        self != .savedValues(from: entry, decimalSeparator: decimalSeparator)
    }
}

/// セットの追加・修正・削除を検証し、変更を即時保存する。
@MainActor
struct WorkoutSetService {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func add(draft: SetEntryDraft, to exerciseEntry: ExerciseEntry) throws -> SetEntry {
        let setEntry = try insert(draft: draft, to: exerciseEntry)
        do {
            try context.save()
            return setEntry
        } catch {
            context.rollback()
            throw error
        }
    }

    /// 検証済みDraftからSetEntryを生成してコンテキストへ追加する。保存は呼び出し側が行う。
    func insert(draft: SetEntryDraft, to exerciseEntry: ExerciseEntry) throws -> SetEntry {
        guard let values = draft.values() else { throw WorkoutSetError.invalidValues }
        let order = (exerciseEntry.setEntries.map(\.order).max() ?? -1) + 1
        let setEntry = SetEntry(
            exerciseEntry: exerciseEntry,
            order: order,
            weightKg: values.weight,
            reps: values.reps,
            isWarmup: false
        )
        context.insert(setEntry)
        return setEntry
    }

    func update(_ setEntry: SetEntry, draft: SetEntryDraft) throws {
        guard let values = draft.values() else { throw WorkoutSetError.invalidValues }
        setEntry.weightKg = values.weight
        setEntry.reps = values.reps
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    func delete(_ setEntry: SetEntry, from exerciseEntry: ExerciseEntry) throws {
        context.delete(setEntry)
        let remaining = exerciseEntry.setEntries.filter { $0.id != setEntry.id }.sorted { $0.order < $1.order }
        for (order, entry) in remaining.enumerated() {
            entry.order = order
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

enum WorkoutSetError: LocalizedError, Equatable {
    case invalidValues

    var errorDescription: String? {
        "重量は0以上かつ小数点以下2桁まで、回数は1以上の整数で入力してください。"
    }
}
