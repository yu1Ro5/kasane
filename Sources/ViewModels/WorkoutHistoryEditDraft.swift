import Foundation

/// 完了済みWorkoutの編集内容を、保存するまでSwiftDataモデルから分離して保持するDraft。
struct WorkoutHistoryEditDraft {
    /// 1種目分の編集対象と、その種目に属するセットDraftを表す。
    struct ExerciseDraft: Identifiable, Equatable {
        /// `ExerciseEntry`と対応する識別子。新規種目では追加時に採番する。
        let id: UUID
        /// 関連する種目マスタの識別子。関連が失われている既存記録では`nil`になる。
        let exerciseID: UUID?
        /// Workoutへ記録された時点の種目名。
        let exerciseNameSnapshot: String
        /// Workoutへ記録された時点の主対象部位。
        let primaryBodyPartSnapshot: String
        /// 表示順に並んだ、この種目のセットDraft。
        var sets: [SetDraft]
    }

    /// 1セット分の編集値と、編集対象外のウォームアップ状態を表す。
    struct SetDraft: Identifiable, Equatable {
        /// `SetEntry`と対応する識別子。新規セットでは追加時に採番する。
        let id: UUID
        /// 入力途中の文字列を含む重量・回数の編集値。
        var values: SetEntryDraft
        /// 既存セットから引き継ぐウォームアップ状態。新規セットでは`false`になる。
        let isWarmup: Bool
    }

    /// 編集対象の`WorkoutSession`識別子。
    let sessionID: UUID
    /// Draft作成時点の種目・セット状態。変更判定と介在変更の検出に使用する。
    private let originalExercises: [ExerciseDraft]
    /// ユーザーが編集している現在の種目・セット状態。
    var exercises: [ExerciseDraft]

    /// 完了済みWorkoutの現在状態から編集Draftを作成する。
    /// - Parameter session: 編集対象のWorkout。
    init(session: WorkoutSession) {
        let exercises = Self.makeExercises(from: session)

        sessionID = session.id
        originalExercises = exercises
        self.exercises = exercises
    }

    /// ユーザーがDraft作成後に種目またはセットを変更しているかを示す。
    var hasChanges: Bool {
        exercises != originalExercises
    }

    /// 保存対象がDraft作成時点の状態を維持しているかを判定する。
    /// - Parameter session: 保存直前のWorkout。
    /// - Returns: Workout識別子と種目・セット状態がDraft作成時点と一致する場合は`true`。
    func matchesOriginalState(of session: WorkoutSession) -> Bool {
        sessionID == session.id && originalExercises == Self.makeExercises(from: session)
    }

    /// SwiftDataモデルを、順序が安定した比較可能なDraft表現へ変換する。
    /// - Parameter session: 変換対象のWorkout。
    /// - Returns: 種目とセットを`order`順に並べたDraft表現。
    private static func makeExercises(from session: WorkoutSession) -> [ExerciseDraft] {
        session.exerciseEntries
            .sorted { $0.order < $1.order }
            .map { entry in
                ExerciseDraft(
                    id: entry.id,
                    exerciseID: entry.exercise?.id,
                    exerciseNameSnapshot: entry.exerciseNameSnapshot,
                    primaryBodyPartSnapshot: entry.primaryBodyPartSnapshot,
                    sets: entry.setEntries
                        .sorted { $0.order < $1.order }
                        .map { setEntry in
                            SetDraft(
                                id: setEntry.id,
                                values: .savedValues(from: setEntry),
                                isWarmup: setEntry.isWarmup
                            )
                        }
                )
            }
    }

    /// 現在のDraftに含まれる種目マスタの識別子。
    var selectedExerciseIDs: Set<UUID> {
        Set(exercises.compactMap(\.exerciseID))
    }

    /// 種目マスタのsnapshotを持つ新規種目Draftを末尾へ追加する。
    /// - Parameter exercise: 追加する種目マスタ。
    /// - Throws: 同じ種目がすでに含まれる場合は`WorkoutExerciseError.duplicateExercise`。
    mutating func addExercise(_ exercise: Exercise) throws {
        guard !selectedExerciseIDs.contains(exercise.id) else {
            throw WorkoutExerciseError.duplicateExercise
        }
        exercises.append(
            ExerciseDraft(
                id: UUID(),
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                primaryBodyPartSnapshot: exercise.primaryBodyPart,
                sets: []
            )
        )
    }

    /// 指定した種目Draftと、その配下のセットDraftを削除する。
    /// - Parameter id: 削除する種目Draftの識別子。
    mutating func deleteExercise(id: UUID) {
        exercises.removeAll { $0.id == id }
    }

    /// 指定した種目Draftの末尾へ空の新規セットDraftを追加する。
    /// - Parameter exerciseID: 追加先となる種目Draftの識別子。
    mutating func addSet(to exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.append(
            SetDraft(id: UUID(), values: SetEntryDraft(), isWarmup: false)
        )
    }

    /// 指定した種目DraftからセットDraftを削除する。
    /// - Parameters:
    ///   - id: 削除するセットDraftの識別子。
    ///   - exerciseID: 削除元となる種目Draftの識別子。
    mutating func deleteSet(id: UUID, from exerciseID: UUID) {
        guard let index = exercises.firstIndex(where: { $0.id == exerciseID }) else { return }
        exercises[index].sets.removeAll { $0.id == id }
    }
}
