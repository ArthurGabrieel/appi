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
                .contextMenu { collectionContextMenu(collection) }
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
