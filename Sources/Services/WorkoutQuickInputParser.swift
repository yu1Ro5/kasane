import Foundation
import FoundationModels

@MainActor
protocol WorkoutQuickInputParsing {
    func parse(
        _ text: String,
        availableExerciseNames: [String]
    ) async throws -> GeneratedWorkoutQuickInput
}

enum WorkoutQuickInputAvailability: Equatable {
    case available
    case appleIntelligenceNotEnabled
    case modelNotReady
    case deviceNotEligible
    case localeUnsupported

    var unavailableMessage: String? {
        switch self {
        case .available: nil
        case .appleIntelligenceNotEnabled:
            "Apple Intelligenceを有効にするとAI入力を利用できます。"
        case .modelNotReady:
            "Apple Intelligenceを準備中です。しばらくしてから再度お試しください。"
        case .deviceNotEligible:
            "この端末ではAI入力を利用できません。"
        case .localeUnsupported:
            "現在の言語ではAI入力を利用できません。"
        }
    }
}

struct AppleIntelligenceWorkoutQuickInputParser: WorkoutQuickInputParsing {
    static func availability(locale: Locale = .current) -> WorkoutQuickInputAvailability {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return model.supportsLocale(locale) ? .available : .localeUnsupported
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        @unknown default:
            return .deviceNotEligible
        }
    }

    func parse(
        _ text: String,
        availableExerciseNames: [String]
    ) async throws -> GeneratedWorkoutQuickInput {
        let availability = Self.availability()
        guard availability == .available else {
            throw WorkoutQuickInputParserError.unavailable(availability)
        }
        let names = availableExerciseNames.map { "- \($0)" }.joined(separator: "\n")
        let session = LanguageModelSession {
            """
            あなたは筋力トレーニング記録を構造化するパーサーです。
            ユーザーが実際に入力した情報だけを抽出してください。
            重量、回数、セット数を推測しないでください。
            「3セット」のようにセット数が指定された場合は、同じ条件のセットを指定された件数に展開してください。
            「最後だけ8回」「2セット目だけ32.5kg」などの差分表現を各セットへ反映してください。
            利用可能な種目名に明確に対応する種目がある場合、その正式名称を使用してください。
            明確に対応できない場合は、ユーザーが入力した種目名をそのまま返してください。
            重量はkgとして出力してください。「自重」は明示された0kgとして扱ってください。
            重量が明示されていない場合はweightKgをnilにしてください。
            回数が明示されていない場合はrepsをnilにしてください。
            ユーザーの入力に存在しない種目やセットを追加しないでください。
            """
        }
        let response = try await session.respond(
            to: """
                利用可能な種目名:
                \(names)

                ユーザー入力:
                \(text)
                """,
            generating: GeneratedWorkoutQuickInput.self
        )
        return response.content
    }
}

enum WorkoutQuickInputParserError: Error {
    case unavailable(WorkoutQuickInputAvailability)
}

struct FixtureWorkoutQuickInputParser: WorkoutQuickInputParsing {
    func parse(
        _ text: String,
        availableExerciseNames: [String]
    ) async throws -> GeneratedWorkoutQuickInput {
        GeneratedWorkoutQuickInput(exercises: [
            GeneratedWorkoutQuickInputExercise(
                exerciseName: "チェストプレス",
                sets: [
                    .init(weightKg: 30, reps: 10),
                    .init(weightKg: 30, reps: 10),
                    .init(weightKg: 30, reps: 8),
                ]
            ),
            GeneratedWorkoutQuickInputExercise(
                exerciseName: "ラットプルダウン",
                sets: [
                    .init(weightKg: 18, reps: 12),
                    .init(weightKg: 18, reps: 12),
                    .init(weightKg: 18, reps: 12),
                ]
            ),
        ])
    }
}
