import Foundation

protocol WorkspaceRepository: Sendable {
    func fetchAll() async throws -> [Workspace]
    func save(_ workspace: Workspace) async throws
    func delete(_ workspace: Workspace) async throws
}
