import Foundation

protocol EnvironmentRepository: Sendable {
    func fetchAll(in workspaceId: UUID) async throws -> [Environment]
    func activate(_ environment: Environment) async throws
    func save(_ environment: Environment) async throws
    func delete(_ environment: Environment) async throws
}
