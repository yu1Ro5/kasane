import Foundation
import Observation
import SwiftData

/// Shared draft and validation for exercise forms. No model is inserted until save.
@MainActor @Observable
final class ExerciseFormViewModel {
    static let maximumNameLength = 80
    var name: String
    var bodyPart: BodyPart
    var errorMessage: String?
    private let initialName: String
    private let initialBodyPart: BodyPart

    init(name: String = "", bodyPart: BodyPart = .other) {
        self.name = name
        self.bodyPart = bodyPart
        initialName = name
        initialBodyPart = bodyPart
    }

    var hasChanges: Bool { name != initialName || bodyPart != initialBodyPart }
    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    func validationMessage(existingNames: [String]) -> String? {
        if trimmedName.isEmpty { return "種目名を入力してください。" }
        if trimmedName.count > Self.maximumNameLength { return "種目名は80文字以内で入力してください。" }
        let key = Self.nameKey(trimmedName)
        if existingNames.contains(where: { Self.nameKey($0) == key }) {
            return "同じ名前の種目が登録されています。別の名前を入力してください。"
        }
        return nil
    }

    @discardableResult
    func save(in container: ModelContainer, persist: ((ModelContext) throws -> Void)? = nil) -> Bool {
        // A dedicated context keeps a failed save from rolling back an active Workout draft.
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            let names = try context.fetch(FetchDescriptor<Exercise>()).map(\.name)
            if let message = validationMessage(existingNames: names) {
                errorMessage = message
                return false
            }
            context.insert(Exercise(name: trimmedName, primaryBodyPart: bodyPart))
            if let persist { try persist(context) } else { try context.save() }
            errorMessage = nil
            return true
        } catch {
            context.rollback()
            errorMessage = "種目を保存できませんでした。\(error.localizedDescription)"
            return false
        }
    }

    private static func nameKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "ja_JP"))
    }
}
