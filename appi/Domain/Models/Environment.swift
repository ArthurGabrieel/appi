import Foundation

struct Environment: Equatable, Identifiable {
    let id: UUID
    var name: String
    var isActive: Bool
    var workspaceId: UUID
    var variables: [EnvVariable]
    let createdAt: Date
    var updatedAt: Date
}
