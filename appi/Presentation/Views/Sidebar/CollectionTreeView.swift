import SwiftUI

struct CollectionTreeView: View {
    @Bindable var viewModel: CollectionTreeViewModel

    @State private var expandedCollections: Set<UUID> = []
    @State private var renamingItemId: UUID?
    @State private var renameText: String = ""
    @State private var itemPendingDelete: SidebarItem?

    var body: some View {
        List(selection: $viewModel.selectedItemId) {
            ForEach(viewModel.filteredChildren(of: nil)) { item in
                sidebarItemView(item)
            }
            .onMove(perform: viewModel.searchQuery.isEmpty ? { from, to in
                Task { await viewModel.reorderChildren(of: nil, from: from, to: to) }
            } : nil)
        }
        .onChange(of: viewModel.selectedItemId) { _, newValue in
            if let id = newValue {
                viewModel.selectItem(id)
            }
        }
        // Root-level drop zone: accepts collection drags to re-parent to root.
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let itemId = UUID(uuidString: idString),
                  viewModel.collections.contains(where: { $0.id == itemId }),
                  viewModel.canDropCollection(itemId, intoParent: nil)
            else { return false }
            let atIndex = viewModel.children(of: nil).count
            Task { await viewModel.moveCollection(itemId, toParent: nil, atIndex: atIndex) }
            return true
        }
        .alert(String(localized: "sidebar.delete.title"), isPresented: Binding(
            get: { itemPendingDelete != nil },
            set: { if !$0 { itemPendingDelete = nil } }
        )) {
            Button(String(localized: "sidebar.delete.confirm"), role: .destructive) {
                if let item = itemPendingDelete {
                    Task {
                        switch item {
                        case .collection(let c): await viewModel.deleteCollection(c)
                        case .request(let r): await viewModel.deleteRequest(r)
                        }
                    }
                }
                itemPendingDelete = nil
            }
            Button(String(localized: "sidebar.delete.cancel"), role: .cancel) {
                itemPendingDelete = nil
            }
        } message: {
            if let item = itemPendingDelete {
                Text(String(localized: "sidebar.delete.message \(item.name)"))
            }
        }
    }

    // MARK: - Expansion helpers

    private func isCollectionExpanded(_ id: UUID) -> Bool {
        if viewModel.searchQuery.isEmpty {
            return expandedCollections.contains(id)
        }
        return searchExpandedCollections.contains(id)
    }

    private func setCollectionExpanded(_ id: UUID, _ expanded: Bool) {
        guard viewModel.searchQuery.isEmpty else { return }
        if expanded { expandedCollections.insert(id) } else { expandedCollections.remove(id) }
    }

    /// Collections that should be force-expanded when a search is active,
    /// so that matching items and their full ancestor chain are visible.
    private var searchExpandedCollections: Set<UUID> {
        guard !viewModel.searchQuery.isEmpty else { return [] }
        var expanded = Set<UUID>()
        let query = viewModel.searchQuery.lowercased()

        for request in viewModel.requests where request.name.lowercased().contains(query) {
            var currentId: UUID? = request.collectionId
            while let id = currentId {
                expanded.insert(id)
                currentId = viewModel.collections.first(where: { $0.id == id })?.parentId
            }
        }

        for collection in viewModel.collections where collection.name.lowercased().contains(query) {
            expanded.insert(collection.id)  // expand the matching collection to reveal its children
            var currentId: UUID? = collection.parentId
            while let id = currentId {
                expanded.insert(id)
                currentId = viewModel.collections.first(where: { $0.id == id })?.parentId
            }
        }

        return expanded
    }

    // MARK: - Row builders

    @ViewBuilder
    private func sidebarItemView(_ item: SidebarItem) -> some View {
        switch item {
        case .collection(let collection):
            collectionDisclosure(collection)
        case .request(let request):
            requestRow(request)
        }
    }

    @ViewBuilder
    private func requestRow(_ request: Request) -> some View {
        Group {
            if renamingItemId == request.id {
                TextField("", text: $renameText)
                    .textFieldStyle(.plain)
                    .onSubmit { commitRenameRequest(request) }
                    .onExitCommand { renamingItemId = nil }
            } else {
                RequestRow(request: request)
            }
        }
        .tag(request.id)
        .draggable(request.id.uuidString)
        .contextMenu { requestContextMenu(request) }
    }

    private func collectionDisclosure(_ collection: Collection) -> some View {
        AnyView(
            DisclosureGroup(isExpanded: Binding(
                get: { isCollectionExpanded(collection.id) },
                set: { setCollectionExpanded(collection.id, $0) }
            )) {
                ForEach(viewModel.filteredChildren(of: collection.id)) { child in
                    sidebarItemView(child)
                }
                .onMove(perform: viewModel.searchQuery.isEmpty ? { from, to in
                    Task { await viewModel.reorderChildren(of: collection.id, from: from, to: to) }
                } : nil)
            } label: {
                Group {
                    if renamingItemId == collection.id {
                        TextField("", text: $renameText)
                            .textFieldStyle(.plain)
                            .onSubmit { commitRenameCollection(collection) }
                            .onExitCommand { renamingItemId = nil }
                    } else {
                        CollectionRow(
                            collection: collection,
                            isExpanded: .constant(isCollectionExpanded(collection.id))
                        )
                    }
                }
                .tag(collection.id)
                .draggable(collection.id.uuidString)
                .contextMenu { collectionContextMenu(collection) }
            }
            // Drop ON a collection: move item into it, appending at the end.
            .dropDestination(for: String.self) { items, _ in
                guard let idString = items.first, let itemId = UUID(uuidString: idString) else { return false }
                let atIndex = viewModel.children(of: collection.id).count
                if viewModel.requests.contains(where: { $0.id == itemId }) {
                    Task { await viewModel.moveRequest(itemId, toCollection: collection.id, atIndex: atIndex) }
                    return true
                } else if viewModel.canDropCollection(itemId, intoParent: collection.id) {
                    Task { await viewModel.moveCollection(itemId, toParent: collection.id, atIndex: atIndex) }
                    return true
                }
                return false
            }
        )
    }

    // MARK: - Rename helpers

    private func startRenaming(_ id: UUID, currentName: String) {
        renameText = currentName
        renamingItemId = id
    }

    private func commitRenameCollection(_ collection: Collection) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            Task { await viewModel.renameCollection(collection.id, to: name) }
        }
        renamingItemId = nil
    }

    private func commitRenameRequest(_ request: Request) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            Task { await viewModel.renameRequest(request.id, to: name) }
        }
        renamingItemId = nil
    }

    // MARK: - Context menus

    @ViewBuilder
    private func collectionContextMenu(_ collection: Collection) -> some View {
        Button(String(localized: "sidebar.menu.newRequest")) {
            Task { await viewModel.createRequest(in: collection.id) }
        }
        Button(String(localized: "sidebar.menu.newSubcollection")) {
            Task { await viewModel.createCollection(name: "New Collection", parentId: collection.id) }
        }
        Divider()
        Button(String(localized: "sidebar.menu.rename")) {
            startRenaming(collection.id, currentName: collection.name)
        }
        Divider()
        Button(String(localized: "sidebar.menu.delete"), role: .destructive) {
            itemPendingDelete = .collection(collection)
        }
    }

    @ViewBuilder
    private func requestContextMenu(_ request: Request) -> some View {
        Button(String(localized: "sidebar.menu.rename")) {
            startRenaming(request.id, currentName: request.name)
        }
        Button(String(localized: "sidebar.menu.duplicate")) {
            Task { await viewModel.duplicateRequest(request) }
        }
        Divider()
        Button(String(localized: "sidebar.menu.delete"), role: .destructive) {
            itemPendingDelete = .request(request)
        }
    }
}
