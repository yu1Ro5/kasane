import Foundation

enum WorkoutSetDisplayFormatter {
    struct WeightParts: Equatable {
        let integer: String
        let fraction: String?
    }

    static func setNumber(_ number: Int) -> String {
        String(number)
    }

    static func weightValue(_ weightKg: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), weightKg)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }

    static func weight(_ weightKg: Double) -> String {
        "\(weightValue(weightKg)) kg"
    }

    static func weightParts(_ weightKg: Double) -> WeightParts {
        let components = weightValue(weightKg).split(separator: ".", maxSplits: 1)
        return WeightParts(
            integer: String(components[0]),
            fraction: components.count == 2 ? String(components[1]) : nil
        )
    }

    static func reps(_ reps: Int) -> String {
        String(reps)
    }
}
