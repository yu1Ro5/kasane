import Foundation

enum WorkoutSetDisplayFormatter {
    static func setNumber(_ number: Int) -> String {
        String(number)
    }

    static func editableWeightValue(_ weightKg: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), weightKg)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    static func displayWeight(_ weightKg: Double) -> String {
        String(
            format: "%.2f kg",
            locale: Locale(identifier: "en_US_POSIX"),
            weightKg
        )
    }

    static func reps(_ reps: Int) -> String {
        String(reps)
    }

    /// 一覧セル向けに、保存済みセットを短く要約する。
    static func summary(prefix: String, setEntries: [SetEntry]) -> String {
        guard let first = setEntries.first else { return "\(prefix) 入力中" }
        let allSetsMatch = setEntries.allSatisfy {
            $0.weightKg == first.weightKg && $0.reps == first.reps
        }
        guard allSetsMatch else { return "\(prefix) \(setEntries.count)セット" }
        return "\(prefix) \(displayWeight(first.weightKg)) × \(first.reps) × \(setEntries.count)"
    }
}
