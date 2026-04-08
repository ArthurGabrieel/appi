import SwiftUI

struct CollectionTreeView: View {
    @Bindable var viewModel: CollectionTreeViewModel

    var body: some View {
        List(selection: $viewModel.selectedItemId) {
            ForEach(viewModel.children(of: nil)) { item in
                sidebarItemView(item)
            }
        }
        .onChange(of: viewModel.selectedItemId) { _, newValue in
            if let id = newValue {
                viewModel.selectItem(id)
            }
        }
    }

    @State private var expandedCollections: Set<UUID> = []

    @ViewBuilder
    private func sidebarItemView(_ item: SidebarItem) -> some View {
        switch item {
        case .collection(let collection):
            collectionDisclosure(collection)
        case .request(let request):
            RequestRow(request: request)
                .tag(request.id)
                .draggable(request.id.uuidString)
                .contextMenu { requestContextMenu(request) }
        }
    }

    private func collectionDisclosure(_ collection: Collection) -> some View {
        AnyView(
            DisclosureGroup(isExpanded: Binding(
                get: { expandedCollections.contains(collection.id) },
                set: { isExpanded in
                    if isExpanded {
                        expandedCollections.insert(collection.id)
                    } else {
                        expandedCollections.remove(collection.id)
                    }
                }
            )) {
                ForEach(viewModel.children(of: collection.id)) { child in
                    sidebarItemView(child)
                }
            } label: {
                CollectionRow(
                    collection: collection,
                    isExpanded: .constant(expandedCollections.contains(collection.id))
                )
                .tag(collection.id)
                .draggable(collection.id.uuidString)
                .contextMenu { collectionContextMenu(collection) }
            }
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first, let itemId = UUID(uuidString: idString) else { return false }
                if viewModel.requests.contains(where: { $0.id == itemId }) {
                    Task { await viewModel.moveRequest(itemId, toCollection: collection.id, atIndex: 0) }
                    return true
                } else if viewModel.canDropCollection(itemId, intoParent: collection.id) {
                    Task { await viewModel.moveCollection(itemId, toParent: collection.id, atIndex: 0) }
                    return true
                }
                return false
            }
        )
    }

    @ViewBuilder
    private func collectionContextMenu(_ collection: Collection) -> some View {
        Button(String(localized: "sidebar.menu.newRequest")) {
            Task { await viewModel.createRequest(in: collection.id) }
        }
        Button(String(localized: "sidebar.menu.newSubcollection")) {
            Task { await viewModel.createCollection(name: "New Collection", parentId: collection.id) }
        }
        Divider()
        Button(String(localized: "sidebar.menu.delete"), role: .destructive) {
            Task { await viewModel.deleteCollection(collection) }
        }
    }

    @ViewBuilder
    private func requestContextMenu(_ request: Request) -> some View {
        Button(String(localized: "sidebar.menu.duplicate")) {
            Task { await viewModel.duplicateRequest(request) }
        }
        Divider()
        Button(String(localized: "sidebar.menu.delete"), role: .destructive) {
            Task { await viewModel.deleteRequest(request) }
        }
    }
}
