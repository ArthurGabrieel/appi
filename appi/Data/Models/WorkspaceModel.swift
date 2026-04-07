import Foundation
import SwiftData

@Model
final class WorkspaceModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    init(id: UUID, name: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }

    convenience init(from workspace: Workspace) {
        self.init(id: workspace.id, name: workspace.name, createdAt: workspace.createdAt)
    }

    func toDomain() -> Workspace {
        Workspace(id: id, name: name, createdAt: createdAt)
    }
}
