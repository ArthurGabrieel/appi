import Foundation
import SwiftData

@Model
final class CollectionModel {
    @Attribute(.unique) var id: UUID
    var name: String
    var parentId: UUID?
    var sortIndex: Int
    var workspaceId: UUID
    var authData: Data
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID, name: String, parentId: UUID?, sortIndex: Int, workspaceId: UUID, authData: Data, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.parentId = parentId
        self.sortIndex = sortIndex
        self.workspaceId = workspaceId
        self.authData = authData
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(from collection: Collection) {
        let authData = (try? JSONEncoder().encode(collection.auth)) ?? Data()
        self.init(
            id: collection.id,
            name: collection.name,
            parentId: collection.parentId,
            sortIndex: collection.sortIndex,
            workspaceId: collection.workspaceId,
            authData: authData,
            createdAt: collection.createdAt,
            updatedAt: collection.updatedAt
        )
    }

    func toDomain() -> Collection {
        let auth = (try? JSONDecoder().decode(AuthConfig.self, from: authData)) ?? .none
        return Collection(
            id: id,
            name: name,
            parentId: parentId,
            sortIndex: sortIndex,
            workspaceId: workspaceId,
            auth: auth,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
