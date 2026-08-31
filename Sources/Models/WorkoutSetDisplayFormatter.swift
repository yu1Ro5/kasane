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
}
