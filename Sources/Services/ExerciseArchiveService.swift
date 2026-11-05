import Foundation
import SwiftData

@MainActor
struct ExerciseArchiveService {
    func setArchived(
        _ archived: Bool, exerciseID: UUID, in container: ModelContainer,
        persist: ((ModelContext) throws -> Void)? = nil
    ) throws {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            guard let exercise = try context.fetch(FetchDescriptor<Exercise>()).first(where: { $0.id == exerciseID }) else {
                throw ExerciseArchiveError.notFound
            }
            exercise.isArchived = archived
            if let persist { try persist(context) } else { try context.save() }
        } catch {
            context.rollback()
            throw error
        }
    }
}

private enum ExerciseArchiveError: LocalizedError {
    case notFound

    var errorDescription: String? { "対象の種目が見つかりません。" }
}
