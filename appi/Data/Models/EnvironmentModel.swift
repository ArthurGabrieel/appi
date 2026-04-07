import Foundation
import SwiftData

@Model
final class EnvironmentModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var isActive: Bool
    var workspaceId: UUID
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \EnvVariableModel.environment)
    var variables: [EnvVariableModel] = []

    init(id: UUID, name: String, isActive: Bool, workspaceId: UUID, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.isActive = isActive
        self.workspaceId = workspaceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(from environment: Environment) {
        self.init(
            id: environment.id,
            name: environment.name,
            isActive: environment.isActive,
            workspaceId: environment.workspaceId,
            createdAt: environment.createdAt,
            updatedAt: environment.updatedAt
        )
        self.variables = environment.variables.map { EnvVariableModel(from: $0) }
    }

    func toDomain() -> Environment {
        Environment(
            id: id,
            name: name,
            isActive: isActive,
            workspaceId: workspaceId,
            variables: variables.map { $0.toDomain() },
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
