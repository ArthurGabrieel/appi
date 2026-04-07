import Foundation

struct Workspace: Equatable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
}
