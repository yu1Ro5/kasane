import SwiftData
import SwiftUI

@main
struct KASANEApp: App {
    private let container: Result<ModelContainer, Error>

    init() {
        container = Result { try AppModelContainer.make() }
    }

    var body: some Scene {
        WindowGroup {
            switch container {
            case .success(let container):
                AppRootTabView()
                    .modelContainer(container)
            case .failure(let error):
                ContentUnavailableView(
                    "データを読み込めませんでした",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error.localizedDescription)
                )
            }
        }
    }
}

@MainActor
private enum AppModelContainer {
    private static let schema = Schema([
        WorkoutSession.self,
        Exercise.self,
        ExerciseEntry.self,
        SetEntry.self,
    ])

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) throws -> ModelContainer {
        guard arguments.contains("--ui-testing") else {
            return try ModelContainer(for: schema)
        }

        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        )
        if fixtureName(in: arguments) == "workout-set-layout" {
            try insertWorkoutSetLayoutFixture(into: container.mainContext)
        } else if fixtureName(in: arguments) == "workout-history" {
            try insertHistoryFixture(into: container.mainContext)
        }
        return container
    }

    private static func fixtureName(in arguments: [String]) -> String? {
        guard let optionIndex = arguments.firstIndex(of: "--fixture") else { return nil }
        let valueIndex = arguments.index(after: optionIndex)
        guard valueIndex < arguments.endIndex else { return nil }
        return arguments[valueIndex]
    }

    private static func insertWorkoutSetLayoutFixture(into context: ModelContext) throws {
        guard let sessionID = UUID(uuidString: "10000000-0000-4000-8000-000000000001") else {
            throw FixtureError.invalidIdentifier
        }
        let session = WorkoutSession(
            id: sessionID,
            startedAt: Date(timeIntervalSince1970: 1_767_225_600)
        )
        context.insert(session)
        guard let exerciseID = UUID(uuidString: "20000000-0000-4000-8000-000000000001") else {
            throw FixtureError.invalidIdentifier
        }
        let exercise = Exercise(id: exerciseID, name: "シーテッドロー", primaryBodyPart: .back)
        context.insert(exercise)
        let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: 0)
        context.insert(entry)
        for (order, values) in [(18.0, 12), (23.0, 10), (4.5, 8)].enumerated() {
            context.insert(
                SetEntry(
                    exerciseEntry: entry,
                    order: order,
                    weightKg: values.0,
                    reps: values.1
                )
            )
        }
        try context.save()
    }

    private static func insertHistoryFixture(into context: ModelContext) throws {
        let session = WorkoutSession(
            startedAt: Date(timeIntervalSince1970: 1_767_229_200),
            endedAt: Date(timeIntervalSince1970: 1_767_232_320)
        )
        let fixtures: [(String, BodyPart)] = [
            ("ベンチプレス", .chest),
            ("ラットプルダウン", .back),
            ("スクワット", .legs),
        ]

        context.insert(session)
        for (order, fixture) in fixtures.enumerated() {
            let exercise = Exercise(name: fixture.0, primaryBodyPart: fixture.1)
            context.insert(exercise)
            let entry = ExerciseEntry(workoutSession: session, exercise: exercise, order: order)
            context.insert(entry)
            let setFixtures: [(Double, Int)] =
                order == 0
                ? [(40, 10), (42.5, 8)]
                : order == 1 ? [(0, 12), (22.5, 8)] : [(60, 10)]
            for (setOrder, setFixture) in setFixtures.enumerated() {
                context.insert(
                    SetEntry(
                        exerciseEntry: entry,
                        order: setOrder,
                        weightKg: setFixture.0,
                        reps: setFixture.1
                    )
                )
            }
        }
        guard
            let historyEditExerciseID = UUID(
                uuidString: "30000000-0000-4000-8000-000000000001"
            )
        else {
            throw FixtureError.invalidIdentifier
        }
        context.insert(
            Exercise(
                id: historyEditExerciseID,
                name: "履歴編集テスト種目",
                primaryBodyPart: .fullBody
            )
        )
        try context.save()
    }

    private enum FixtureError: Error {
        case invalidIdentifier
    }
}
