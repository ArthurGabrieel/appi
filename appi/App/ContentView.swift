import SwiftUI

struct ContentView: View {
    @SwiftUI.Environment(DependencyContainer.self) private var container

    @State private var collectionTreeViewModel: CollectionTreeViewModel?
    @State private var tabBarViewModel: TabBarViewModel?
    @State private var editorViewModel: RequestEditorViewModel?
    @State private var environmentViewModel: EnvironmentViewModel?
    @State private var isLoaded = false

    var body: some View {
        NavigationSplitView {
            if let collectionTreeViewModel, let environmentViewModel {
                SidebarView(viewModel: collectionTreeViewModel, environmentViewModel: environmentViewModel)
            }
        } detail: {
            VStack(spacing: 0) {
                if let tabBarViewModel {
                    TabBarView(
                        viewModel: tabBarViewModel,
                        defaultCollectionId: collectionTreeViewModel?.collections.first(where: { $0.parentId == nil })?.id
                    )
                    Divider()
                }

                if let editorViewModel {
                    RequestEditorView(viewModel: editorViewModel, activeEnvironment: nil)
                } else {
                    EmptyStateView {
                        Task {
                            if let collectionId = collectionTreeViewModel?.collections.first?.id {
                                await tabBarViewModel?.newTab(collectionId: collectionId)
                            }
                        }
                    }
                }
            }
        }
        .task {
            guard !isLoaded else { return }
            isLoaded = true

            await bootstrapIfNeeded(
                workspaceRepository: container.workspaceRepository,
                collectionRepository: container.collectionRepository,
                tabRepository: container.tabRepository
            )

            // Resolve workspaceId once
            guard let workspace = try? await container.workspaceRepository.fetchAll().first else { return }

            let treeVM = container.makeCollectionTreeViewModel(workspaceId: workspace.id)
            let tabVM = container.makeTabBarViewModel()
            let envVM = container.makeEnvironmentViewModel(workspaceId: workspace.id)

            // Wire sidebar → tabs
            treeVM.onRequestSelected = { request in
                Task { await tabVM.openRequest(request) }
            }
            treeVM.onTreeChanged = {
                Task { await tabVM.reloadTabs() }
            }

            collectionTreeViewModel = treeVM
            tabBarViewModel = tabVM
            environmentViewModel = envVM

            await treeVM.loadTree()
            await tabVM.loadTabs()
            await envVM.loadEnvironments()

            updateEditor()
        }
        .onChange(of: tabBarViewModel?.activeTabId) { _, _ in
            updateEditor()
        }
        .onChange(of: tabBarViewModel?.tabsVersion) { _, _ in
            // Fires after reloadTabs() — catches payload changes (e.g. orphan cleanup)
            // even when activeTabId stays the same
            updateEditor()
        }
    }

    private func updateEditor() {
        guard let tabBarViewModel, let activeTab = tabBarViewModel.activeTab else {
            editorViewModel = nil
            return
        }
        let vm = container.makeRequestEditorViewModel(draft: activeTab.draft, tab: activeTab)
        vm.onDraftChanged = { [tabBarViewModel] updatedTab in
            if let index = tabBarViewModel.tabs.firstIndex(where: { $0.id == updatedTab.id }) {
                tabBarViewModel.tabs[index] = updatedTab
            }
        }
        editorViewModel = vm
    }
}
