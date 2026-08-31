import Foundation

/// 保存前のセット入力を表す値。
struct SetEntryDraft: Equatable {
    /// 重量
    var weight = ""
    /// 回数
    var reps = ""

    /// 空の場合、trueを返す。
    var isEmpty: Bool {
        weight.isEmpty && reps.isEmpty
    }

    /// 値を取得する。
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

    /// 保存された値からDraftを作成する。
    static func savedValues(
        from entry: SetEntry,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> SetEntryDraft {
        let asciiWeight = WorkoutSetDisplayFormatter.weightValue(entry.weightKg)

        return SetEntryDraft(
            weight: asciiWeight.replacingOccurrences(of: ".", with: decimalSeparator),
            reps: String(entry.reps)
        )
    }

    /// 保存された値と異なる場合、trueを返す。
    func hasChanges(
        from entry: SetEntry,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> Bool {
        self != .savedValues(from: entry, decimalSeparator: decimalSeparator)
    }
}
