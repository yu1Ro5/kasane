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

enum WorkoutQuickInputAnalysisError: Error, Equatable {
    case modelUnavailable
    case decodingFailure(debugContext: String?)
    case assetsUnavailable(debugContext: String?)
    case rateLimited(debugContext: String?)
    case contextWindowExceeded(debugContext: String?)
    case refused(debugContext: String?)
    case unsupportedLanguageOrLocale(debugContext: String?)
    case concurrentRequest(debugContext: String?)
    case unsupportedGuide(debugContext: String?)
    case invalidGeneratedStructure(WorkoutQuickInputSetExpansionError)
    case unknown

    var userMessage: String {
        switch self {
        case .modelUnavailable:
            "この端末ではAI入力を利用できません。"
        case .decodingFailure:
            "AIの解析結果を読み取れませんでした。もう一度お試しください。"
        case .assetsUnavailable:
            "Apple Intelligenceを準備中です。しばらくしてから再度お試しください。"
        case .rateLimited, .concurrentRequest:
            "AIを一時的に利用できません。少し待ってから再度お試しください。"
        case .contextWindowExceeded:
            "入力が長すぎます。短くして再度お試しください。"
        case .refused:
            "この内容はAI入力で読み取れませんでした。"
        case .unsupportedLanguageOrLocale:
            "現在の言語ではAI入力を利用できません。"
        case .unsupportedGuide, .invalidGeneratedStructure:
            "AIの解析結果に不整合がありました。もう一度お試しください。"
        case .unknown:
            "うまく読み取れませんでした。内容を確認して再度お試しください。"
        }
    }

    var classification: String {
        switch self {
        case .modelUnavailable: "modelUnavailable"
        case .decodingFailure: "decodingFailure"
        case .assetsUnavailable: "assetsUnavailable"
        case .rateLimited: "rateLimited"
        case .contextWindowExceeded: "contextWindowExceeded"
        case .refused: "refused"
        case .unsupportedLanguageOrLocale: "unsupportedLanguageOrLocale"
        case .concurrentRequest: "concurrentRequest"
        case .unsupportedGuide: "unsupportedGuide"
        case .invalidGeneratedStructure: "invalidGeneratedStructure"
        case .unknown: "unknown"
        }
    }

    var debugContext: String? {
        switch self {
        case .decodingFailure(let context),
            .assetsUnavailable(let context),
            .rateLimited(let context),
            .contextWindowExceeded(let context),
            .refused(let context),
            .unsupportedLanguageOrLocale(let context),
            .concurrentRequest(let context),
            .unsupportedGuide(let context):
            context
        default:
            nil
        }
    }

    var setExpansionError: WorkoutQuickInputSetExpansionError? {
        guard case .invalidGeneratedStructure(let error) = self else { return nil }
        return error
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
            throw Self.analysisError(for: availability)
        }
        let names = availableExerciseNames.map { "- \($0)" }.joined(separator: "\n")
        let session = LanguageModelSession {
            """
            あなたは筋力トレーニング記録を構造化するパーサーです。
            ユーザーが実際に入力した情報だけを抽出し、重量、回数、セット数を推測しないでください。
            共通条件とセット数はrepeated、各セットが個別に列挙された場合だけexplicitを使用してください。
            特定セットだけの差分はrepeatedのoverrideにしてください。
            種目名は入力どおりに返し、正式名称への解決は行わないでください。
            重量はkgとし、「自重」は0kgとして扱ってください。
            入力にない種目やセットを追加しないでください。
            """
        }
        do {
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
        } catch let error as LanguageModelSession.GenerationError {
            throw Self.analysisError(for: error)
        }
    }

    private static func analysisError(
        for availability: WorkoutQuickInputAvailability
    ) -> WorkoutQuickInputAnalysisError {
        switch availability {
        case .modelNotReady:
            .assetsUnavailable(debugContext: nil)
        case .localeUnsupported:
            .unsupportedLanguageOrLocale(debugContext: nil)
        case .available, .appleIntelligenceNotEnabled, .deviceNotEligible:
            .modelUnavailable
        }
    }

    private static func analysisError(
        for error: LanguageModelSession.GenerationError
    ) -> WorkoutQuickInputAnalysisError {
        switch error {
        case .decodingFailure(let context):
            .decodingFailure(debugContext: context.debugDescription)
        case .assetsUnavailable(let context):
            .assetsUnavailable(debugContext: context.debugDescription)
        case .rateLimited(let context):
            .rateLimited(debugContext: context.debugDescription)
        case .exceededContextWindowSize(let context):
            .contextWindowExceeded(debugContext: context.debugDescription)
        case .guardrailViolation(let context):
            .refused(debugContext: context.debugDescription)
        case .refusal(_, let context):
            .refused(debugContext: context.debugDescription)
        case .unsupportedLanguageOrLocale(let context):
            .unsupportedLanguageOrLocale(debugContext: context.debugDescription)
        case .concurrentRequests(let context):
            .concurrentRequest(debugContext: context.debugDescription)
        case .unsupportedGuide(let context):
            .unsupportedGuide(debugContext: context.debugDescription)
        @unknown default:
            .unknown
        }
    }
}

struct FixtureWorkoutQuickInputParser: WorkoutQuickInputParsing {
    func parse(
        _ text: String,
        availableExerciseNames: [String]
    ) async throws -> GeneratedWorkoutQuickInput {
        GeneratedWorkoutQuickInput(exercises: [
            GeneratedWorkoutQuickInputExercise(
                exerciseName: "チェストプレス",
                setPattern: .repeated(
                    .init(
                        setCount: 3,
                        defaultWeightKg: 30,
                        defaultReps: 10,
                        overrides: [.init(setNumber: 3, weightKg: nil, reps: 8)]
                    )
                )
            ),
            GeneratedWorkoutQuickInputExercise(
                exerciseName: "ラットプルダウン",
                setPattern: .repeated(
                    .init(
                        setCount: 3,
                        defaultWeightKg: 18,
                        defaultReps: 12,
                        overrides: []
                    )
                )
            ),
        ])
    }
}

struct FailingFixtureWorkoutQuickInputParser: WorkoutQuickInputParsing {
    func parse(
        _ text: String,
        availableExerciseNames: [String]
    ) async throws -> GeneratedWorkoutQuickInput {
        throw WorkoutQuickInputAnalysisError.rateLimited(debugContext: nil)
    }
}
