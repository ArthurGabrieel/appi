import SwiftUI

struct ContentView: View {
    @SwiftUI.Environment(DependencyContainer.self) private var container

    @State private var viewModel: RequestEditorViewModel?

    var body: some View {
        Group {
            if let viewModel {
                RequestEditorView(viewModel: viewModel, activeEnvironment: nil)
            } else {
                EmptyStateView { createNewRequest() }
            }
        }
        .onAppear { createNewRequest() }
    }

    private func createNewRequest() {
        let collectionId = UUID()
        let tab = Tab(
            id: UUID(), linkedRequestId: nil,
            draft: RequestDraft.empty(in: collectionId),
            sortIndex: 0, isActive: true, createdAt: Date()
        )
        viewModel = container.makeRequestEditorViewModel(draft: tab.draft, tab: tab)
    }
}
