enum ExerciseListFilter: String, CaseIterable {
    case all = "すべて"
    case active = "利用中"
    case archived = "アーカイブ済み"

    func includes(_ exercise: Exercise) -> Bool {
        switch self {
        case .all: true
        case .active: !exercise.isArchived
        case .archived: exercise.isArchived
        }
    }

    var emptyMessage: String {
        switch self {
        case .all: "種目はありません"
        case .active: "利用中の種目はありません"
        case .archived: "アーカイブ済みの種目はありません"
        }
    }
}
