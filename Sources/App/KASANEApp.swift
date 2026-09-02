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
        } else if fixtureName(in: arguments) == "overview-recent-workouts" {
            try insertOverviewRecentWorkoutsFixture(into: container.mainContext)
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
        for (order, values) in [(40.0, 10), (42.5, 8), (4.5, 12), (100.0, 6), (22.25, 8)]
            .enumerated()
        {
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
        guard let sessionID = UUID(uuidString: "50000000-0000-4000-8000-000000000001") else {
            throw FixtureError.invalidIdentifier
        }
        let session = WorkoutSession(
            id: sessionID,
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
                ? [(40, 10), (42.5, 8), (4.5, 12), (100, 6), (22.25, 8)]
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

    private static func insertOverviewRecentWorkoutsFixture(into context: ModelContext) throws {
        let fixtures: [(String, TimeInterval, TimeInterval?, [(String, BodyPart)])] = [
            (
                "40000000-0000-4000-8000-000000000001",
                1_767_546_000,
                1_767_549_600,
                [("ベンチプレス", .chest), ("ラットプルダウン", .back)]
            ),
            (
                "40000000-0000-4000-8000-000000000002",
                1_767_459_600,
                1_767_462_300,
                [("スクワット", .legs)]
            ),
            (
                "40000000-0000-4000-8000-000000000003",
                1_767_373_200,
                1_767_375_600,
                [("ショルダープレス", .shoulders)]
            ),
            (
                "40000000-0000-4000-8000-000000000004",
                1_767_286_800,
                1_767_288_600,
                [("デッドリフト", .back)]
            ),
            (
                "40000000-0000-4000-8000-000000000005",
                1_767_632_400,
                nil,
                [("アクティブテスト種目", .fullBody)]
            ),
        ]

        for fixture in fixtures {
            guard let sessionID = UUID(uuidString: fixture.0) else {
                throw FixtureError.invalidIdentifier
            }
            let session = WorkoutSession(
                id: sessionID,
                startedAt: Date(timeIntervalSince1970: fixture.1),
                endedAt: fixture.2.map(Date.init(timeIntervalSince1970:))
            )
            context.insert(session)
            for (order, exerciseFixture) in fixture.3.enumerated() {
                let exercise = Exercise(
                    name: exerciseFixture.0,
                    primaryBodyPart: exerciseFixture.1
                )
                context.insert(exercise)
                context.insert(
                    ExerciseEntry(workoutSession: session, exercise: exercise, order: order)
                )
            }
        }
        try context.save()
    }

    private enum FixtureError: Error {
        case invalidIdentifier
    }
}
