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
            最終的なセット配列を展開せず、セット数、共通値、特定セットの差分という意味情報を返してください。
            「3セット」はsetCount=3とし、explicitSetsに3要素を生成しないでください。
            「最後だけ8回」はsetNumber=setCountのoverride、「最初だけ」はsetNumber=1のoverrideにしてください。
            各セットが個別に列挙された場合だけexplicitSetsを使用してください。
            種目名はユーザーの入力どおりに返し、正式名称への解決は行わないでください。
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
                setCount: 3,
                defaultWeightKg: 30,
                defaultReps: 10,
                overrides: [.init(setNumber: 3, weightKg: nil, reps: 8)],
                explicitSets: []
            ),
            GeneratedWorkoutQuickInputExercise(
                exerciseName: "ラットプルダウン",
                setCount: 3,
                defaultWeightKg: 18,
                defaultReps: 12,
                overrides: [],
                explicitSets: []
            ),
        ])
    }
}
