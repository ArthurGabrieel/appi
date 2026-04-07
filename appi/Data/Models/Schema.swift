import Foundation
import SwiftData

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [WorkspaceModel.self, CollectionModel.self, RequestModel.self,
         ResponseModel.self, EnvironmentModel.self, EnvVariableModel.self, TabModel.self]
    }
}

enum AppiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
