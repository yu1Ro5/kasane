import SwiftData
import SwiftUI

/// 過去に記録したすべての種目を、最終実施日の新しい順に表示する。
struct ExerciseRecordsView: View {
    @Query private var entries: [ExerciseEntry]

    init() {
        _entries = Query(OverviewWorkoutLoader.exerciseOverviewEntryDescriptor)
    }

    var body: some View {
        let contents = ExerciseOverviewCardBuilder.build(entries: entries)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(contents) { content in
                    NavigationLink(value: OverviewRoute.exerciseProgress(content.exerciseID)) {
                        ExerciseRecordListRow(content: content)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("すべての種目")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("exercise-records-screen")
    }
}

private struct ExerciseRecordListRow: View {
    let content: ExerciseOverviewCardContent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell.fill")
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(content.exerciseName).font(.headline)
                Text("最終実施日 \(content.latestCompletedAt.formatted(.dateTime.year().month().day()))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(
                content.showsWeightSparkline
                    ? WorkoutSetDisplayFormatter.displayWeight(content.currentBestWeightKg) : "自重"
            )
            .font(.headline)
            .monospacedDigit()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.accessibilityDescription)
        .accessibilityIdentifier("exercise-record-list-row-\(content.exerciseID.uuidString)")
    }
}
