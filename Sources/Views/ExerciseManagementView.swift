import SwiftData
import SwiftUI

struct ExerciseManagementView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var isAdding = false

    var body: some View {
        List {
            ForEach(BodyPart.allCases, id: \.self) { part in
                let items = exercises.filter { $0.bodyPart == part }
                if !items.isEmpty {
                    Section(part.displayName) {
                        ForEach(items) { exercise in
                            VStack(alignment: .leading) {
                                Text(exercise.name)
                                Text(part.displayName).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("種目管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("種目を追加", systemImage: "plus") { isAdding = true }
                    .accessibilityIdentifier("exercise-add-button")
            }
        }
        .sheet(isPresented: $isAdding) {
            ExerciseFormSheet()
        }
    }
}
