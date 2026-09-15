import Foundation
import FoundationModels
import Observation

@MainActor
@Observable
final class WorkoutQuickInputViewModel {
    static let maximumCharacterCount = 500

    var text = ""
    var draft: WorkoutQuickInputDraft?
    var isAnalyzing = false
    var isApplying = false
    var errorMessage: String?

    private let parser: any WorkoutQuickInputParsing
    private let resolver: WorkoutQuickInputResolver

    init(
        parser: any WorkoutQuickInputParsing = AppleIntelligenceWorkoutQuickInputParser(),
        resolver: WorkoutQuickInputResolver = WorkoutQuickInputResolver()
    ) {
        self.parser = parser
        self.resolver = resolver
    }

    var characterCount: Int { text.count }

    var canAnalyze: Bool {
        !isAnalyzing && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && characterCount <= Self.maximumCharacterCount
    }

    var validationMessage: String? {
        guard let draft else { return nil }
        if draft.exercises.isEmpty { return "解析できる種目がありません。テキストを修正してください。" }
        if draft.exercises.contains(where: { $0.exerciseID == nil }) {
            return "未解決の種目があります。既存の種目を選択してください。"
        }
        let ids = draft.exercises.compactMap(\.exerciseID)
        if Set(ids).count != ids.count { return "同じ種目が複数含まれています。1つにまとめてください。" }
        if draft.exercises.contains(where: { $0.sets.isEmpty }) {
            return "セットがない種目を削除するか、テキストを修正してください。"
        }
        if draft.exercises.flatMap(\.sets).contains(where: { $0.values.values() == nil }) {
            return "重量と回数を確認してください。重量は0以上で小数点以下2桁まで、回数は1以上です。"
        }
        return nil
    }

    var isReviewValid: Bool { draft != nil && validationMessage == nil }

    func analyze(availableExercises: [Exercise]) async {
        guard canAnalyze else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            let generated = try await parser.parse(
                text,
                availableExerciseNames: availableExercises.filter(\.isSelectable).map(\.name)
            )
            draft = resolver.resolve(generated, against: availableExercises)
        } catch let error as LanguageModelSession.GenerationError {
            errorMessage = Self.message(for: error)
        } catch WorkoutQuickInputParserError.unavailable(let availability) {
            errorMessage = availability.unavailableMessage ?? "この端末ではAI入力を利用できません。"
        } catch {
            errorMessage = "うまく読み取れませんでした。内容を確認して再度お試しください。"
        }
    }

    func editText() {
        draft = nil
        errorMessage = nil
    }

    func removeExercise(id: UUID) {
        draft?.exercises.removeAll { $0.id == id }
    }

    func removeSet(id: UUID, from exerciseID: UUID) {
        guard let index = draft?.exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        draft?.exercises[index].sets.removeAll { $0.id == id }
    }

    private static func message(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .exceededContextWindowSize:
            "入力が長すぎます。短くして再度お試しください。"
        case .guardrailViolation, .refusal:
            "この内容はAI入力で読み取れませんでした。"
        case .unsupportedLanguageOrLocale:
            "現在の言語ではAI入力を利用できません。"
        default:
            "うまく読み取れませんでした。内容を確認して再度お試しください。"
        }
    }
}
