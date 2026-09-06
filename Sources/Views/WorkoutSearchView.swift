import SwiftData
import SwiftUI

struct WorkoutSearchView: View {
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \ExerciseEntry.order) private var exerciseEntries: [ExerciseEntry]
    @State private var query = ""

    private var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var results: [WorkoutSession] {
        WorkoutSearch.sessions(
            matching: query,
            sessions: sessions,
            exerciseEntries: exerciseEntries
        )
    }

    var body: some View {
        Group {
            if normalizedQuery.isEmpty {
                ContentUnavailableView(
                    "種目名で検索",
                    systemImage: "magnifyingglass",
                    description: Text("種目名を入力すると、完了したワークアウトを検索できます。")
                )
                .accessibilityIdentifier("workout-search-unsearched")
            } else if results.isEmpty {
                ContentUnavailableView.search(text: normalizedQuery)
                    .accessibilityIdentifier("workout-search-empty")
            } else {
                List(results) { session in
                    if let content = WorkoutHistoryRowContent(
                        session: session,
                        exerciseEntries: exerciseEntries.filter {
                            $0.workoutSession?.id == session.id
                        }
                    ) {
                        NavigationLink(value: OverviewRoute.workoutDetail(session.id)) {
                            WorkoutHistoryRow(content: content)
                        }
                        .accessibilityIdentifier(
                            "workout-search-result-row-\(session.id.uuidString)"
                        )
                    }
                }
            }
        }
        .navigationTitle("検索")
        .searchable(text: $query, prompt: "種目名を検索")
    }
}

#Preview {
    NavigationStack {
        WorkoutSearchView()
    }
    .modelContainer(
        for: [WorkoutSession.self, Exercise.self, ExerciseEntry.self, SetEntry.self],
        inMemory: true
    )
}
