import SwiftUI

struct WorkoutDetailView: View {
    let content: WorkoutDetailContent

    init(session: WorkoutSession) {
        content = WorkoutDetailContent(session: session)
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(content.startedAt, format: .dateTime.year().month().day())
                        .font(.title2.bold())
                    HStack(spacing: 8) {
                        Text(content.startedAt, format: .dateTime.hour().minute())
                        Text("〜")
                        if let endedAt = content.endedAt {
                            Text(endedAt, format: .dateTime.hour().minute())
                        } else {
                            Text("--")
                        }
                    }
                    Text(content.durationText)
                        .font(.headline)
                }
                .padding(.vertical, 4)
            }

            ForEach(content.exercises) { exercise in
                Section(exercise.name) {
                    HStack {
                        Text("セット")
                        Spacer()
                        Text("重量")
                        Spacer()
                        Text("回数")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(exercise.sets) { set in
                        HStack {
                            Text("\(set.number)")
                            Spacer()
                            Text("\(set.weightText) kg")
                            Spacer()
                            Text("\(set.reps)")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("workout-detail-view")
        .navigationTitle("ワークアウト詳細")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let session = WorkoutSession(startedAt: .now, endedAt: .now.addingTimeInterval(3_120))
    NavigationStack {
        WorkoutDetailView(session: session)
    }
}
