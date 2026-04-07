import Foundation

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

    let workspaceId: UUID
    private let collectionRepository: any CollectionRepository
    private let requestRepository: any RequestRepository
    private let tabRepository: any TabRepository

    init(
        workspaceId: UUID,
        collectionRepository: any CollectionRepository,
        requestRepository: any RequestRepository,
        tabRepository: any TabRepository
    ) {
        self.workspaceId = workspaceId
        self.collectionRepository = collectionRepository
        self.requestRepository = requestRepository
        self.tabRepository = tabRepository
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
}
