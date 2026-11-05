import SwiftData
import XCTest

@testable import KASANE

@MainActor
final class ExerciseManagementTests: XCTestCase {
    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([Exercise.self, WorkoutSession.self, ExerciseEntry.self, SetEntry.self])
        return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }

    func testThreeFiltersAndEmptyStates() throws {
        let container = try makeContainer()
        let active = Exercise(name: "利用中", primaryBodyPart: .chest)
        let archived = Exercise(name: "保管中", primaryBodyPart: .back, isArchived: true)
        container.mainContext.insert(active)
        container.mainContext.insert(archived)
        try container.mainContext.save()

        let exercises = try container.mainContext.fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(ExerciseListFilter.allCases.map { filter in exercises.filter { filter.includes($0) }.count }, [2, 1, 1])
        XCTAssertEqual(ExerciseListFilter.active.rawValue, "利用中")
        XCTAssertEqual(ExerciseListFilter.archived.emptyMessage, "アーカイブ済みの種目はありません")
        XCTAssertEqual(ExerciseListFilter.all.emptyMessage, "種目はありません")
        XCTAssertEqual(ExerciseListFilter.active.emptyMessage, "利用中の種目はありません")
    }

    func testArchiveAndRestoreUpdateFilterResultsWithoutDeletingExercise() throws {
        let container = try makeContainer()
        let exercise = Exercise(name: "対象", primaryBodyPart: .legs)
        let id = exercise.id
        container.mainContext.insert(exercise)
        try container.mainContext.save()

        try ExerciseArchiveService().setArchived(true, exerciseID: id, in: container)
        var stored = try ModelContext(container).fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertTrue(stored[0].isArchived)
        XCTAssertEqual(stored.filter { ExerciseListFilter.active.includes($0) }.count, 0)
        XCTAssertEqual(stored.filter { ExerciseListFilter.archived.includes($0) }.count, 1)

        try ExerciseArchiveService().setArchived(false, exerciseID: id, in: container)
        stored = try ModelContext(container).fetch(FetchDescriptor<Exercise>())
        XCTAssertEqual(stored.first?.id, id)
        XCTAssertFalse(stored[0].isArchived)
        XCTAssertEqual(stored.filter { ExerciseListFilter.active.includes($0) }.count, 1)
    }

    func testArchiveFailurePreservesStoredState() throws {
        let container = try makeContainer()
        let exercise = Exercise(name: "対象", primaryBodyPart: .legs)
        container.mainContext.insert(exercise)
        try container.mainContext.save()

        XCTAssertThrowsError(try ExerciseArchiveService().setArchived(true, exerciseID: exercise.id, in: container) { _ in
            throw CocoaError(.fileWriteUnknown)
        })
        XCTAssertFalse(try XCTUnwrap(ModelContext(container).fetch(FetchDescriptor<Exercise>()).first).isArchived)
    }

    func testEditedArchivedExerciseSurvivesBackupRestoreAndSeed() throws {
        let source = try makeContainer()
        try ExerciseCatalogService(context: source.mainContext).seed()
        let original = try XCTUnwrap(source.mainContext.fetch(FetchDescriptor<Exercise>()).first)
        let id = original.id
        let draft = ExerciseFormViewModel(name: "改名した種目", bodyPart: .arms, editingID: id)
        XCTAssertTrue(draft.save(in: source))
        try ExerciseArchiveService().setArchived(true, exerciseID: id, in: source)

        let backup = try KASANEBackupExporter(container: source).makeBackup()
        let destination = try makeContainer()
        try KASANEBackupImporter(container: destination).importBackup(backup)
        try ExerciseCatalogService(context: destination.mainContext).seed()
        let restored = try XCTUnwrap(ModelContext(destination).fetch(FetchDescriptor<Exercise>()).first(where: { $0.id == id }))
        XCTAssertEqual(restored.name, "改名した種目")
        XCTAssertEqual(restored.bodyPart, .arms)
        XCTAssertTrue(restored.isArchived)
    }
}
