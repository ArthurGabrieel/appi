import Foundation

struct Collection: Equatable, Identifiable {
    let id: UUID
    var name: String
    var parentId: UUID?
    var sortIndex: Int
    var workspaceId: UUID
    var auth: AuthConfig
    let createdAt: Date
    var updatedAt: Date
}
