import Testing
import Foundation
@testable import appi

@MainActor
struct CollectionTreeViewModelTests {
    let workspaceId = UUID()

    func makeViewModel(
        collectionRepository: MockCollectionRepository? = nil,
        requestRepository: MockRequestRepository? = nil,
        tabRepository: MockTabRepository? = nil
    ) -> CollectionTreeViewModel {
        let colRepo = collectionRepository ?? MockCollectionRepository()
        let reqRepo = requestRepository ?? MockRequestRepository()
        let tabRepo = tabRepository ?? MockTabRepository()
        return CollectionTreeViewModel(
            workspaceId: workspaceId,
            collectionRepository: colRepo,
            requestRepository: reqRepo,
            tabRepository: tabRepo
        )
    }

    @Test("loadTree fetches collections and requests for workspace")
    func loadTree() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(
            id: UUID(), name: "Auth API", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [collection]

        let reqRepo = MockRequestRepository()
        let request = Request(
            id: UUID(), name: "Login", method: .post,
            url: "{{baseUrl}}/login", headers: [], body: .none,
            auth: .inheritFromParent, collectionId: collection.id,
            sortIndex: 0, createdAt: Date(), updatedAt: Date()
        )
        reqRepo.requests = [request]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        #expect(vm.collections.count == 1)
        #expect(vm.collections.first?.name == "Auth API")
        #expect(vm.requests.count == 1)
        #expect(vm.requests.first?.name == "Login")
    }

    @Test("createCollection adds a new root collection")
    func createCollection() async throws {
        let colRepo = MockCollectionRepository()
        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        await vm.createCollection(name: "Users API", parentId: nil)

        #expect(colRepo.saveCalled)
        #expect(vm.collections.count == 1)
        #expect(vm.collections.first?.name == "Users API")
        #expect(vm.collections.first?.auth == AuthConfig.none)
    }

    @Test("createSubCollection sets parentId and auth to inheritFromParent")
    func createSubCollection() async throws {
        let colRepo = MockCollectionRepository()
        let parentCollection = Collection(
            id: UUID(), name: "Parent", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [parentCollection]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        await vm.createCollection(name: "Child", parentId: parentCollection.id)

        let child = vm.collections.first { $0.name == "Child" }
        #expect(child?.parentId == parentCollection.id)
        #expect(child?.auth == .inheritFromParent)
    }

    @Test("createRequest adds request in collection and reloads")
    func createRequest() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(
            id: UUID(), name: "API", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [collection]
        let reqRepo = MockRequestRepository()

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        await vm.createRequest(in: collection.id)

        #expect(reqRepo.saveCalled)
        #expect(vm.requests.count == 1)
        #expect(vm.requests.first?.name == "New Request")
        #expect(vm.requests.first?.collectionId == collection.id)
    }

    @Test("renameCollection updates name")
    func renameCollection() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(
            id: UUID(), name: "Old Name", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [collection]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        await vm.renameCollection(collection.id, to: "New Name")

        #expect(vm.collections.first?.name == "New Name")
    }

    @Test("deleteCollection removes collection and reloads")
    func deleteCollection() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(
            id: UUID(), name: "Doomed", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [collection]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        await vm.deleteCollection(collection)

        #expect(vm.collections.isEmpty)
    }

    @Test("deleteRequest removes request and reloads")
    func deleteRequest() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(
            id: UUID(), name: "API", parentId: nil,
            sortIndex: 0, workspaceId: workspaceId, auth: .none,
            createdAt: Date(), updatedAt: Date()
        )
        colRepo.collections = [collection]

        let reqRepo = MockRequestRepository()
        let request = Request(
            id: UUID(), name: "Login", method: .post,
            url: "/login", headers: [], body: .none,
            auth: .inheritFromParent, collectionId: collection.id,
            sortIndex: 0, createdAt: Date(), updatedAt: Date()
        )
        reqRepo.requests = [request]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        await vm.deleteRequest(request)

        #expect(vm.requests.isEmpty)
    }
}
