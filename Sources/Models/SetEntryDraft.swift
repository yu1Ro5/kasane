import Foundation

/// 保存前のセット入力を表す値。
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
