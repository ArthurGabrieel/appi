import Testing
import Foundation
import SwiftData
@testable import appi

struct CollectionRepositoryTests {
    func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WorkspaceModel.self, CollectionModel.self, RequestModel.self,
            ResponseModel.self, EnvironmentModel.self, EnvVariableModel.self, TabModel.self,
            configurations: config
        )
    }

    @Test("ancestorChain returns correct hierarchy")
    func ancestorChain() async throws {
        let container = try makeContainer()
        let repo = SwiftDataCollectionRepository(modelContainer: container)
        let workspaceId = UUID()

        let root = Collection(id: UUID(), name: "Root", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let child = Collection(id: UUID(), name: "Child", parentId: root.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
        let grandchild = Collection(id: UUID(), name: "Grandchild", parentId: child.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())

        try await repo.save(root)
        try await repo.save(child)
        try await repo.save(grandchild)

        let chain = try await repo.ancestorChain(for: grandchild.id)

        #expect(chain.count == 3)
        #expect(chain[0].name == "Grandchild")
        #expect(chain[1].name == "Child")
        #expect(chain[2].name == "Root")
    }
}
