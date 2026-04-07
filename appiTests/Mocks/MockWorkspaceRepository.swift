import Foundation
@testable import appi

final class MockWorkspaceRepository: WorkspaceRepository, @unchecked Sendable {
    var workspaces: [Workspace] = []
    var saveCalled = false

    func fetchAll() async throws -> [Workspace] {
        workspaces
    }

    func save(_ workspace: Workspace) async throws {
        saveCalled = true
        if let index = workspaces.firstIndex(where: { $0.id == workspace.id }) {
            workspaces[index] = workspace
        } else {
            workspaces.append(workspace)
        }
    }

    func delete(_ workspace: Workspace) async throws {
        workspaces.removeAll { $0.id == workspace.id }
    }
}
