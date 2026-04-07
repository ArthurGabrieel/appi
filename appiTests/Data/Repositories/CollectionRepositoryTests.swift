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

    @Test("delete cascades through sub-collections, requests, and responses")
    func deleteCascadesChildren() async throws {
        let container = try makeContainer()
        let collectionRepo = SwiftDataCollectionRepository(modelContainer: container)
        let requestRepo = SwiftDataRequestRepository(modelContainer: container)
        let responseRepo = SwiftDataResponseRepository(modelContainer: container)
        let workspaceId = UUID()

        let root = Collection(
            id: UUID(),
            name: "Root",
            parentId: nil,
            sortIndex: 0,
            workspaceId: workspaceId,
            auth: .none,
            createdAt: Date(),
            updatedAt: Date()
        )
        let child = Collection(
            id: UUID(),
            name: "Child",
            parentId: root.id,
            sortIndex: 0,
            workspaceId: workspaceId,
            auth: .inheritFromParent,
            createdAt: Date(),
            updatedAt: Date()
        )
        let request = Request(
            id: UUID(),
            name: "Get Users",
            method: .get,
            url: "https://api.example.com/users",
            headers: [],
            body: .none,
            auth: .none,
            collectionId: child.id,
            sortIndex: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
        let response = Response(
            id: UUID(),
            statusCode: 200,
            statusMessage: "OK",
            headers: [],
            body: Data(),
            contentType: "application/json",
            duration: 0.1,
            size: 2,
            createdAt: Date()
        )

        try await collectionRepo.save(root)
        try await collectionRepo.save(child)
        try await requestRepo.save(request)
        try await responseRepo.save(response, forRequestId: request.id)

        try await collectionRepo.delete(root)

        let remainingCollections = try await collectionRepo.fetchAll(in: workspaceId)
        let remainingRequests = try await requestRepo.fetchAll(in: child.id)
        let remainingResponses = try await responseRepo.fetchHistory(for: request.id)

        #expect(remainingCollections.isEmpty)
        #expect(remainingRequests.isEmpty)
        #expect(remainingResponses.isEmpty)
    }
}
