import Testing
import Foundation
@testable import appi

@MainActor
struct CollectionTreeViewModelTests {
    let workspaceId = UUID()

    func makeViewModel(
        collectionRepository: MockCollectionRepository? = nil,
        requestRepository: MockRequestRepository? = nil,
        tabRepository: MockTabRepository? = nil,
        authService: MockAuthService? = nil
    ) -> CollectionTreeViewModel {
        let colRepo = collectionRepository ?? MockCollectionRepository()
        let reqRepo = requestRepository ?? MockRequestRepository()
        let tabRepo = tabRepository ?? MockTabRepository()
        let authSvc = authService ?? MockAuthService()
        return CollectionTreeViewModel(
            workspaceId: workspaceId,
            collectionRepository: colRepo,
            requestRepository: reqRepo,
            tabRepository: tabRepo,
            authService: authSvc
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

    @Test("moveRequest updates collectionId and sortIndex")
    func moveRequest() async throws {
        let colRepo = MockCollectionRepository()
        let col1 = Collection(id: UUID(), name: "A", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let col2 = Collection(id: UUID(), name: "B", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [col1, col2]

        let reqRepo = MockRequestRepository()
        let request = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: col1.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
        reqRepo.requests = [request]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        await vm.moveRequest(request.id, toCollection: col2.id, atIndex: 0)

        let moved = vm.requests.first { $0.id == request.id }
        #expect(moved?.collectionId == col2.id)
        #expect(moved?.sortIndex == 0)
    }

    @Test("moveCollection updates parentId")
    func moveCollection() async throws {
        let colRepo = MockCollectionRepository()
        let parent = Collection(id: UUID(), name: "Parent", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let child = Collection(id: UUID(), name: "Child", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [parent, child]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        await vm.moveCollection(child.id, toParent: parent.id, atIndex: 0)

        let moved = vm.collections.first { $0.id == child.id }
        #expect(moved?.parentId == parent.id)
    }

    @Test("canDropCollection rejects cycle — cannot drop into own descendant")
    func canDropCollectionRejectsCycle() async throws {
        let colRepo = MockCollectionRepository()
        let parent = Collection(id: UUID(), name: "Parent", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let child = Collection(id: UUID(), name: "Child", parentId: parent.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [parent, child]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        let canDrop = vm.canDropCollection(parent.id, intoParent: child.id)
        #expect(canDrop == false)
    }

    @Test("canDropCollection rejects exceeding 5-level depth limit")
    func canDropCollectionRejectsDepth() async throws {
        let colRepo = MockCollectionRepository()
        // Build chain: root → l1 → l2 → l3 → l4 (4 levels deep)
        let root = Collection(id: UUID(), name: "Root", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let l1 = Collection(id: UUID(), name: "L1", parentId: root.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
        let l2 = Collection(id: UUID(), name: "L2", parentId: l1.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
        let l3 = Collection(id: UUID(), name: "L3", parentId: l2.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
        let l4 = Collection(id: UUID(), name: "L4", parentId: l3.id, sortIndex: 0, workspaceId: workspaceId, auth: .inheritFromParent, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [root, l1, l2, l3, l4]

        // Another standalone collection to try moving under l4
        let standalone = Collection(id: UUID(), name: "Standalone", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections.append(standalone)

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        // l4 is level 5 — dropping standalone under l4 would make level 6
        let canDrop = vm.canDropCollection(standalone.id, intoParent: l4.id)
        #expect(canDrop == false)
    }

    @Test("filteredChildren returns all items when searchQuery is empty")
    func filteredChildrenNoQuery() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [collection]

        let reqRepo = MockRequestRepository()
        let request = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
        reqRepo.requests = [request]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()
        vm.searchQuery = ""

        let roots = vm.filteredChildren(of: nil)
        #expect(roots.count == 1) // collection
    }

    @Test("filteredChildren matches request name case-insensitively")
    func filteredChildrenMatchesRequest() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [collection]

        let reqRepo = MockRequestRepository()
        let match = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
        let noMatch = Request(id: UUID(), name: "Logout", method: .post, url: "/logout", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 1, createdAt: Date(), updatedAt: Date())
        reqRepo.requests = [match, noMatch]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()
        vm.searchQuery = "login"

        // Collection should be visible because it contains a matching request
        let roots = vm.filteredChildren(of: nil)
        #expect(roots.count == 1)

        let collectionChildren = vm.filteredChildren(of: collection.id)
        #expect(collectionChildren.count == 1)
        #expect(collectionChildren.first?.name == "Login")
    }

    @Test("filteredChildren matches collection name")
    func filteredChildrenMatchesCollection() async throws {
        let colRepo = MockCollectionRepository()
        let matchCol = Collection(id: UUID(), name: "Auth API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let noMatchCol = Collection(id: UUID(), name: "Users", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [matchCol, noMatchCol]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()
        vm.searchQuery = "auth"

        let roots = vm.filteredChildren(of: nil)
        #expect(roots.count == 1)
        #expect(roots.first?.name == "Auth API")
    }

    @Test("moveRequest re-indexes siblings left in source collection")
    func moveRequestReindexesSourceSiblings() async throws {
        let colRepo = MockCollectionRepository()
        let col1 = Collection(id: UUID(), name: "Source", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let col2 = Collection(id: UUID(), name: "Dest", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [col1, col2]

        let reqRepo = MockRequestRepository()
        let r0 = Request(id: UUID(), name: "R0", method: .get, url: "/r0", headers: [], body: .none, auth: .inheritFromParent, collectionId: col1.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
        let r1 = Request(id: UUID(), name: "R1", method: .get, url: "/r1", headers: [], body: .none, auth: .inheritFromParent, collectionId: col1.id, sortIndex: 1, createdAt: Date(), updatedAt: Date())
        let r2 = Request(id: UUID(), name: "R2", method: .get, url: "/r2", headers: [], body: .none, auth: .inheritFromParent, collectionId: col1.id, sortIndex: 2, createdAt: Date(), updatedAt: Date())
        reqRepo.requests = [r0, r1, r2]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        // Move middle request to another collection — leaves gap at index 1
        await vm.moveRequest(r1.id, toCollection: col2.id, atIndex: 0)

        // Source siblings must be compacted: r0→0, r2→1 (no gap)
        let remaining = vm.requests.filter { $0.collectionId == col1.id }.sorted { $0.sortIndex < $1.sortIndex }
        #expect(remaining.map(\.sortIndex) == [0, 1])
        #expect(remaining.map(\.name) == ["R0", "R2"])
    }

    @Test("moveCollection re-indexes siblings left in source parent")
    func moveCollectionReindexesSourceSiblings() async throws {
        let colRepo = MockCollectionRepository()
        let root = Collection(id: UUID(), name: "Root", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let c0 = Collection(id: UUID(), name: "C0", parentId: nil, sortIndex: 1, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let c1 = Collection(id: UUID(), name: "C1", parentId: nil, sortIndex: 2, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        let c2 = Collection(id: UUID(), name: "C2", parentId: nil, sortIndex: 3, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [root, c0, c1, c2]

        let vm = makeViewModel(collectionRepository: colRepo)
        await vm.loadTree()

        // Move c1 under root — leaves gap at position 2 in root-level siblings
        await vm.moveCollection(c1.id, toParent: root.id, atIndex: 0)

        // Remaining root siblings: root(0), c0(1), c2(2) — no gap
        let rootSiblings = vm.collections.filter { $0.parentId == nil }.sorted { $0.sortIndex < $1.sortIndex }
        #expect(rootSiblings.map(\.sortIndex) == [0, 1, 2])
        #expect(rootSiblings.map(\.name) == ["Root", "C0", "C2"])
    }

    @Test("duplicateRequest inserts copy after original with contiguous sortIndex")
    func duplicateRequestInsertsAfterOriginal() async throws {
        let colRepo = MockCollectionRepository()
        let col = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [col]

        let reqRepo = MockRequestRepository()
        let r0 = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: col.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
        let r1 = Request(id: UUID(), name: "Logout", method: .post, url: "/logout", headers: [], body: .none, auth: .inheritFromParent, collectionId: col.id, sortIndex: 1, createdAt: Date(), updatedAt: Date())
        reqRepo.requests = [r0, r1]

        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo)
        await vm.loadTree()

        await vm.duplicateRequest(r0)

        // Expect: Login(0), Login Copy(1), Logout(2) — no index collision
        let sorted = vm.requests.filter { $0.collectionId == col.id }.sorted { $0.sortIndex < $1.sortIndex }
        #expect(sorted.count == 3)
        #expect(sorted[0].name == "Login")
        #expect(sorted[0].sortIndex == 0)
        #expect(sorted[1].name == "Login Copy")
        #expect(sorted[1].sortIndex == 1)
        #expect(sorted[2].name == "Logout")
        #expect(sorted[2].sortIndex == 2)
    }

    @Test("deleteRequest calls cleanupOrphanedLinks on tabRepository")
    func deleteRequestCleansUpOrphans() async throws {
        let colRepo = MockCollectionRepository()
        let collection = Collection(id: UUID(), name: "API", parentId: nil, sortIndex: 0, workspaceId: workspaceId, auth: .none, createdAt: Date(), updatedAt: Date())
        colRepo.collections = [collection]

        let reqRepo = MockRequestRepository()
        let request = Request(id: UUID(), name: "Login", method: .post, url: "/login", headers: [], body: .none, auth: .inheritFromParent, collectionId: collection.id, sortIndex: 0, createdAt: Date(), updatedAt: Date())
        reqRepo.requests = [request]

        let tabRepo = MockTabRepository()
        let vm = makeViewModel(collectionRepository: colRepo, requestRepository: reqRepo, tabRepository: tabRepo)
        await vm.loadTree()

        await vm.deleteRequest(request)

        #expect(tabRepo.cleanupOrphanedLinksCalled)
    }
}
