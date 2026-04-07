import Testing
import Foundation
import SwiftData
@testable import appi

struct RequestRepositoryTests {
    func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: WorkspaceModel.self, CollectionModel.self, RequestModel.self,
            ResponseModel.self, EnvironmentModel.self, EnvVariableModel.self, TabModel.self,
            configurations: config
        )
    }

    @Test("save and fetchAll round-trip")
    func saveAndFetch() async throws {
        let container = try makeContainer()
        let repo = SwiftDataRequestRepository(modelContainer: container)
        let collectionId = UUID()

        let request = Request(
            id: UUID(), name: "Get Users", method: .get,
            url: "https://api.example.com/users", headers: [], body: .none,
            auth: .none, collectionId: collectionId, sortIndex: 0,
            createdAt: Date(), updatedAt: Date()
        )

        try await repo.save(request)
        let fetched = try await repo.fetchAll(in: collectionId)

        #expect(fetched.count == 1)
        #expect(fetched[0].name == "Get Users")
        #expect(fetched[0].method == .get)
    }

    @Test("delete removes request")
    func deleteRemoves() async throws {
        let container = try makeContainer()
        let repo = SwiftDataRequestRepository(modelContainer: container)
        let collectionId = UUID()

        let request = Request(
            id: UUID(), name: "Delete Me", method: .delete,
            url: "https://api.example.com", headers: [], body: .none,
            auth: .none, collectionId: collectionId, sortIndex: 0,
            createdAt: Date(), updatedAt: Date()
        )

        try await repo.save(request)
        try await repo.delete(request)
        let fetched = try await repo.fetchAll(in: collectionId)

        #expect(fetched.isEmpty)
    }
}
