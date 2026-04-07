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
}
