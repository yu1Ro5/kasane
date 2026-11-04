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

/// 「すべての種目」の一覧で使用する、年を省略しない固定の日付表記。
enum ExerciseRecordDateText {
    static func format(_ date: Date, timeZone: TimeZone = .current) -> String {
        date.formatted(
            .verbatim(
                "\(year: .defaultDigits)/\(month: .twoDigits)/\(day: .twoDigits)" as Date.FormatString,
                locale: Locale(identifier: "en_US_POSIX"),
                timeZone: timeZone,
                calendar: Calendar(identifier: .gregorian)
            )
        )
    }
}

private struct ExerciseRecordListRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let content: ExerciseOverviewCardContent

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                horizontalLayout
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.045), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(content.accessibilityDescription)
        .accessibilityIdentifier("exercise-record-list-row-\(content.exerciseID.uuidString)")
    }

    private var horizontalLayout: some View {
        HStack(spacing: 12) {
            exerciseIcon
            exerciseInfo
            bestWeight
            chevron
        }
    }

    /// Accessibilityサイズでは縮小・省略より可読性を優先する。
    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                exerciseIcon
                exerciseInfo
            }
            HStack(spacing: 12) {
                Spacer()
                bestWeight
                chevron
            }
        }
    }

    private var exerciseIcon: some View {
        Image(systemName: "dumbbell.fill")
            .foregroundStyle(.tint)
            .frame(width: 44, height: 44)
            .background(Color.accentColor.opacity(0.12), in: .rect(cornerRadius: 12))
            .accessibilityHidden(true)
    }

    private var exerciseInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.exerciseName)
                .font(.headline)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.85)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)

            Text("前回 \(ExerciseRecordDateText.format(content.latestCompletedAt))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var bestWeight: some View {
        Text(
            content.showsWeightSparkline
                ? WorkoutSetDisplayFormatter.displayWeight(content.currentBestWeightKg) : "自重"
        )
        .font(.headline)
        .monospacedDigit()
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.bold())
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}
