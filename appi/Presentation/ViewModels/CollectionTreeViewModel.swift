import Foundation
import SwiftUI

enum SidebarItem: Identifiable, Equatable {
    case collection(Collection)
    case request(Request)

    var id: UUID {
        switch self {
        case .collection(let c): c.id
        case .request(let r): r.id
        }
    }

    var sortIndex: Int {
        switch self {
        case .collection(let c): c.sortIndex
        case .request(let r): r.sortIndex
        }
    }

    var name: String {
        switch self {
        case .collection(let c): c.name
        case .request(let r): r.name
        }
    }
}

@Observable @MainActor
final class CollectionTreeViewModel {
    var collections: [Collection] = []
    var requests: [Request] = []
    var selectedItemId: UUID?
    var searchQuery: String = ""

    var onRequestSelected: ((Request) -> Void)?
    var onTreeChanged: (() -> Void)?
    var collectionAuthError: (any LocalizedError)?

    let workspaceId: UUID
    private let collectionRepository: any CollectionRepository
    private let requestRepository: any RequestRepository
    private let tabRepository: any TabRepository
    private let authService: any AuthService

    init(
        workspaceId: UUID,
        collectionRepository: any CollectionRepository,
        requestRepository: any RequestRepository,
        tabRepository: any TabRepository,
        authService: any AuthService
    ) {
        self.workspaceId = workspaceId
        self.collectionRepository = collectionRepository
        self.requestRepository = requestRepository
        self.tabRepository = tabRepository
        self.authService = authService
    }

    func loadTree() async {
        do {
            collections = try await collectionRepository.fetchAll(in: workspaceId)
            var allRequests: [Request] = []
            for collection in collections {
                let reqs = try await requestRepository.fetchAll(in: collection.id)
                allRequests.append(contentsOf: reqs)
            }
            requests = allRequests
        } catch {
            // Loading failure — UI shows empty sidebar
        }
    }

    /// Returns sidebar items (collections + requests) for a given parent collection ID.
    /// Pass nil for root-level items.
    func children(of parentId: UUID?) -> [SidebarItem] {
        let childCollections = collections
            .filter { $0.parentId == parentId }
            .map { SidebarItem.collection($0) }

        let childRequests: [SidebarItem]
        if let parentId {
            childRequests = requests
                .filter { $0.collectionId == parentId }
                .map { SidebarItem.request($0) }
        } else {
            childRequests = []
        }

        return (childCollections + childRequests).sorted { $0.sortIndex < $1.sortIndex }
    }

    func selectItem(_ id: UUID) {
        selectedItemId = id
        if let request = requests.first(where: { $0.id == id }) {
            onRequestSelected?(request)
        }
    }

    func createCollection(name: String, parentId: UUID?) async {
        let auth: AuthConfig = parentId == nil ? .none : .inheritFromParent
        let collection = Collection(
            id: UUID(), name: name, parentId: parentId,
            sortIndex: children(of: parentId).count,
            workspaceId: workspaceId, auth: auth,
            createdAt: Date(), updatedAt: Date()
        )
        do {
            try await collectionRepository.save(collection)
            await loadTree()
        } catch {}
    }

    func createRequest(in collectionId: UUID) async {
        let sortIndex = children(of: collectionId).count
        let request = Request(
            id: UUID(), name: "New Request", method: .get,
            url: "", headers: [], body: .none,
            auth: .inheritFromParent, collectionId: collectionId,
            sortIndex: sortIndex, createdAt: Date(), updatedAt: Date()
        )
        do {
            try await requestRepository.save(request)
            await loadTree()
        } catch {}
    }

    func renameCollection(_ id: UUID, to newName: String) async {
        guard var collection = collections.first(where: { $0.id == id }) else { return }
        collection.name = newName
        collection.updatedAt = Date()
        do {
            try await collectionRepository.save(collection)
            await loadTree()
        } catch {}
    }

    func renameRequest(_ id: UUID, to newName: String) async {
        guard var request = requests.first(where: { $0.id == id }) else { return }
        request.name = newName
        request.updatedAt = Date()
        do {
            try await requestRepository.save(request)
            await loadTree()
        } catch {}
    }

    func deleteCollection(_ collection: Collection) async {
        do {
            try await collectionRepository.delete(collection)
            try await tabRepository.cleanupOrphanedLinks()
            await loadTree()
            onTreeChanged?()
        } catch {}
    }

    func deleteRequest(_ request: Request) async {
        do {
            try await requestRepository.delete(request)
            try await tabRepository.cleanupOrphanedLinks()
            await loadTree()
            onTreeChanged?()
        } catch {}
    }

    func duplicateRequest(_ request: Request) async {
        let copy = Request(
            id: UUID(), name: "\(request.name) Copy",
            method: request.method, url: request.url,
            headers: request.headers, body: request.body,
            auth: request.auth, collectionId: request.collectionId,
            sortIndex: 0,  // placeholder — saveReindexed sets the real value
            createdAt: Date(), updatedAt: Date()
        )
        var items = children(of: request.collectionId)
        let insertAt = items.firstIndex(where: { $0.id == request.id }).map { $0 + 1 } ?? items.count
        items.insert(.request(copy), at: insertAt)
        do {
            try await requestRepository.save(copy)
            try await saveReindexed(items)
            await loadTree()
        } catch {}
    }

    func moveRequest(_ requestId: UUID, toCollection collectionId: UUID, atIndex: Int) async {
        guard let request = requests.first(where: { $0.id == requestId }) else { return }
        let sourceCollectionId = request.collectionId
        var movedRequest = request
        movedRequest.collectionId = collectionId
        var destItems = children(of: collectionId).filter { $0.id != requestId }
        destItems.insert(.request(movedRequest), at: min(atIndex, destItems.count))
        do {
            try await saveReindexed(destItems)
            if sourceCollectionId != collectionId {
                let sourceItems = children(of: sourceCollectionId).filter { $0.id != requestId }
                try await saveReindexed(sourceItems)
            }
            await loadTree()
        } catch {}
    }

    func moveCollection(_ collectionId: UUID, toParent parentId: UUID?, atIndex: Int) async {
        guard var collection = collections.first(where: { $0.id == collectionId }) else { return }
        let sourceParentId = collection.parentId
        guard canDropCollection(collectionId, intoParent: parentId) else { return }
        collection.parentId = parentId
        if parentId == nil, collection.auth == .inheritFromParent {
            collection.auth = .none
        }
        collection.updatedAt = Date()
        var destItems = children(of: parentId).filter { $0.id != collectionId }
        destItems.insert(.collection(collection), at: min(atIndex, destItems.count))
        do {
            try await saveReindexed(destItems)
            if sourceParentId != parentId {
                let sourceItems = children(of: sourceParentId).filter { $0.id != collectionId }
                try await saveReindexed(sourceItems)
            }
            await loadTree()
        } catch {}
    }

    /// Re-orders items within a parent level, called by List's .onMove.
    func reorderChildren(of parentId: UUID?, from: IndexSet, to: Int) async {
        guard searchQuery.isEmpty else { return }
        var items = children(of: parentId)
        items.move(fromOffsets: from, toOffset: to)
        do {
            try await saveReindexed(items)
            await loadTree()
        } catch {}
    }

    /// Assigns sortIndex 0…N to each item and persists only those whose index or
    /// parent changed. Items already carry updated parentId/collectionId from the caller.
    private func saveReindexed(_ items: [SidebarItem]) async throws {
        for (index, item) in items.enumerated() {
            switch item {
            case .collection(var c):
                let stored = collections.first(where: { $0.id == c.id })
                guard stored?.sortIndex != index || stored?.parentId != c.parentId else { continue }
                c.sortIndex = index
                c.updatedAt = Date()
                try await collectionRepository.save(c)
            case .request(let r):
                let stored = requests.first(where: { $0.id == r.id })
                guard stored?.sortIndex != index || stored?.collectionId != r.collectionId else { continue }
                try await requestRepository.move(r.id, toCollection: r.collectionId, sortIndex: index)
            }
        }
    }

    func canDropCollection(_ collectionId: UUID, intoParent parentId: UUID?) -> Bool {
        // Prevent cycle: cannot drop into own descendant
        if let parentId {
            var currentId: UUID? = parentId
            while let id = currentId {
                if id == collectionId { return false }
                currentId = collections.first(where: { $0.id == id })?.parentId
            }
        }

        // Depth check: count depth of target + subtree depth of dragged collection
        let targetDepth = depth(of: parentId)
        let subtreeDepth = maxSubtreeDepth(of: collectionId)
        return targetDepth + subtreeDepth + 1 <= 5
    }

    /// Returns filtered sidebar items for a given parent.
    /// When searchQuery is non-empty:
    /// - A collection whose name matches shows with ALL its children (unfiltered).
    /// - A collection that doesn't match but has matching descendants is kept, and
    ///   filtering continues recursively into its children.
    /// - Requests are filtered by name.
    func filteredChildren(of parentId: UUID?) -> [SidebarItem] {
        guard !searchQuery.isEmpty else {
            return children(of: parentId)
        }

        let query = searchQuery.lowercased()

        // If parentId points to a collection whose name directly matched,
        // show all children unfiltered (collection match → show with all children).
        if let parentId, collectionNameMatches(parentId, query: query) {
            return children(of: parentId)
        }

        let childCollections = collections
            .filter { $0.parentId == parentId }
            .filter { collectionMatchesSearch($0, query: query) }
            .map { SidebarItem.collection($0) }

        let childRequests: [SidebarItem]
        if let parentId {
            childRequests = requests
                .filter { $0.collectionId == parentId }
                .filter { $0.name.lowercased().contains(query) }
                .map { SidebarItem.request($0) }
        } else {
            childRequests = []
        }

        return (childCollections + childRequests).sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Returns true if the collection's own name matches the query.
    private func collectionNameMatches(_ collectionId: UUID, query: String) -> Bool {
        collections.first(where: { $0.id == collectionId })?.name.lowercased().contains(query) ?? false
    }

    /// Returns true if collection name matches OR any descendant matches.
    private func collectionMatchesSearch(_ collection: Collection, query: String) -> Bool {
        if collection.name.lowercased().contains(query) { return true }

        let hasMatchingRequest = requests
            .filter { $0.collectionId == collection.id }
            .contains { $0.name.lowercased().contains(query) }
        if hasMatchingRequest { return true }

        let childCollections = collections.filter { $0.parentId == collection.id }
        return childCollections.contains { collectionMatchesSearch($0, query: query) }
    }

    private func depth(of collectionId: UUID?) -> Int {
        var count = 0
        var currentId = collectionId
        while let id = currentId {
            count += 1
            currentId = collections.first(where: { $0.id == id })?.parentId
        }
        return count
    }

    private func maxSubtreeDepth(of collectionId: UUID) -> Int {
        let children = collections.filter { $0.parentId == collectionId }
        if children.isEmpty { return 0 }
        return 1 + children.map { maxSubtreeDepth(of: $0.id) }.max()!
    }

    // MARK: - Auth

    func updateCollectionAuth(_ collectionId: UUID, auth: AuthConfig) async -> Bool {
        guard var collection = collections.first(where: { $0.id == collectionId }) else { return false }
        let normalizedAuth: AuthConfig
        if collection.parentId == nil, auth == .inheritFromParent {
            normalizedAuth = .none
        } else {
            normalizedAuth = auth
        }
        collection.auth = normalizedAuth
        collection.updatedAt = Date()
        do {
            try await collectionRepository.save(collection)
            collectionAuthError = nil
            await loadTree()
            return true
        } catch {
            collectionAuthError = error as? any LocalizedError ?? PersistenceError.saveFailed(error)
            return false
        }
    }

    // Returns AuthConfig? (not ResolvedAuth?) — the preview must never trigger OAuth2 token refresh.
    // authResolver is NOT called here.
    func loadEffectiveCollectionAuth(_ collectionId: UUID) async -> AuthConfig? {
        guard let collection = collections.first(where: { $0.id == collectionId }),
              case .inheritFromParent = collection.auth
        else { return nil }
        do {
            let chain = try await collectionRepository.ancestorChain(for: collectionId)
            return firstConcreteAuth(in: chain)
        } catch {
            return nil
        }
    }

    // Duplicate of the same helper in RequestEditorViewModel — kept local to avoid cross-ViewModel coupling.
    private func firstConcreteAuth(in chain: [Collection]) -> AuthConfig {
        for collection in chain {
            if case .inheritFromParent = collection.auth { continue }
            return collection.auth
        }
        return .none
    }

    func authorizeCollectionOAuth2(_ collectionId: UUID, config: OAuth2Config) async -> Bool {
        do {
            collectionAuthError = nil
            _ = try await authService.authorize(with: config)
            return true
        } catch {
            collectionAuthError = error as? any LocalizedError
                ?? AuthError.invalidConfiguration(String(localized: "error.auth.unknown"))
            return false
        }
    }
}
