import Foundation
@testable import appi

final class MockEnvironmentRepository: EnvironmentRepository, @unchecked Sendable {
    var environments: [Environment] = []
    var saveCalled = false
    var activateCalled = false
    var activatedId: UUID?

    func fetchAll(in workspaceId: UUID) async throws -> [Environment] {
        environments.filter { $0.workspaceId == workspaceId }
    }

    func activate(_ environment: Environment) async throws {
        activateCalled = true
        activatedId = environment.id
        for i in environments.indices {
            environments[i].isActive = environments[i].id == environment.id
        }
    }

    func save(_ environment: Environment) async throws {
        saveCalled = true
        if let index = environments.firstIndex(where: { $0.id == environment.id }) {
            environments[index] = environment
        } else {
            environments.append(environment)
        }
    }

    func delete(_ environment: Environment) async throws {
        environments.removeAll { $0.id == environment.id }
    }
}
