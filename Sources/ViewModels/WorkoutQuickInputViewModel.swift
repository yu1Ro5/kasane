import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class WorkoutQuickInputViewModel {
    static let maximumCharacterCount = 500
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.yu1Ro5.kasane",
        category: "WorkoutQuickInput"
    )

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
        let inputCharacterCount = text.count
        let availableExerciseCount = availableExercises.filter(\.isSelectable).count
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            let generated = try await parser.parse(
                text,
                availableExerciseNames: availableExercises.filter(\.isSelectable).map(\.name)
            )
            draft = try resolver.resolve(generated, against: availableExercises)
        } catch let error as WorkoutQuickInputAnalysisError {
            handle(
                error,
                inputCharacterCount: inputCharacterCount,
                availableExerciseCount: availableExerciseCount
            )
        } catch let error as WorkoutQuickInputSetExpansionError {
            handle(
                .invalidGeneratedStructure(error),
                inputCharacterCount: inputCharacterCount,
                availableExerciseCount: availableExerciseCount
            )
        } catch {
            handle(
                .unknown,
                inputCharacterCount: inputCharacterCount,
                availableExerciseCount: availableExerciseCount
            )
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

    private func handle(
        _ error: WorkoutQuickInputAnalysisError,
        inputCharacterCount: Int,
        availableExerciseCount: Int
    ) {
        errorMessage = error.userMessage
        let debugContext = error.debugContext ?? "none"
        let setExpansionError = error.setExpansionError.map { String(describing: $0) } ?? "none"
        Self.logger.error(
            "AI Quick Input failed classification=\(error.classification, privacy: .public) inputCharacterCount=\(inputCharacterCount, privacy: .public) availableExerciseCount=\(availableExerciseCount, privacy: .public) debugContext=\(debugContext, privacy: .public) setExpansionError=\(setExpansionError, privacy: .public)"
        )
    }
}
