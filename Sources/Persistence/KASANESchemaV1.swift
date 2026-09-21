import SwiftData

/// KASANE 0.1.x で出荷済みの永続化スキーマ。
///
/// 既存の non-versioned store との entity identity を維持するため、モデル型は
/// nested type にせず、従来どおりトップレベルに置く。この定義は変更しない。
enum KASANESchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        .init(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            WorkoutSession.self,
            Exercise.self,
            ExerciseEntry.self,
            SetEntry.self,
        ]
    }
}
