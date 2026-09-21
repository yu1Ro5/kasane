import SwiftData

enum KASANEMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [KASANESchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
