import Foundation

/// SwiftDataのrelationshipを、Workout入力画面で安定して表示するための射影。
///
/// relationshipが再faultされた際に同じモデルが一時的に複数回含まれても、永続モデルを
/// 変更せず、論理IDごとに一度だけ表示する。未確定Draftはこの射影には含めず、各種目の
/// 保存済みセットに続く行としてViewが常に一行だけ描画する。
struct WorkoutSessionContent {
    let exerciseEntries: [ExerciseEntry]

    init(exerciseEntries: [ExerciseEntry]) {
        self.exerciseEntries = Self.unique(exerciseEntries).sorted { $0.order < $1.order }
    }

    static func setEntries(for exerciseEntry: ExerciseEntry) -> [SetEntry] {
        unique(exerciseEntry.setEntries).sorted { $0.order < $1.order }
    }

    static func draftOrder(for exerciseEntry: ExerciseEntry) -> Int {
        (setEntries(for: exerciseEntry).map(\.order).max() ?? -1) + 1
    }

    static func draft(for exerciseEntry: ExerciseEntry) -> SetEntryDraft {
        SetEntryDraft(
            weight: exerciseEntry.draftWeight ?? "",
            reps: exerciseEntry.draftReps ?? ""
        )
    }

    private static func unique<Model: Identifiable>(_ models: [Model]) -> [Model]
    where Model.ID == UUID {
        var seen = Set<UUID>()
        return models.filter { seen.insert($0.id).inserted }
    }
}
