import SwiftUI

struct TabBarView: View {
    @Bindable var viewModel: TabBarViewModel
    let defaultCollectionId: UUID?

    @State private var tabPendingClose: Tab?

    var body: some View {
        HStack(spacing: 2) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 2) {
                    ForEach(viewModel.tabs) { tab in
                        TabItemView(
                            tab: tab,
                            isActive: tab.id == viewModel.activeTabId,
                            isDirty: viewModel.isDirty(tab),
                            onActivate: {
                                Task { await viewModel.activateTab(tab.id) }
                            },
                            onClose: {
                                Task {
                                    let result = await viewModel.closeTab(tab.id)
                                    if case .needsConfirmation(let t) = result {
                                        tabPendingClose = t
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }

            Button {
                Task {
                    if let collectionId = defaultCollectionId {
                        await viewModel.newTab(collectionId: collectionId)
                    }
                }
            } label: {
                Image(systemName: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .accessibilityLabel(String(localized: "tabs.new"))
            .keyboardShortcut("t", modifiers: .command)
        }
        .frame(height: 32)
        .background(.bar)
        .alert(
            String(localized: "tabs.unsavedChanges.title"),
            isPresented: Binding(
                get: { tabPendingClose != nil },
                set: { if !$0 { tabPendingClose = nil } }
            )
        ) {
            Button(String(localized: "tabs.save"), role: nil) {
                if let tab = tabPendingClose {
                    Task { await viewModel.saveAndCloseTab(tab.id, requestRepository: viewModel.requestRepository) }
                }
            }
            Button(String(localized: "tabs.discard"), role: .destructive) {
                if let tab = tabPendingClose {
                    Task { await viewModel.forceCloseTab(tab.id) }
                }
            }
            Button(String(localized: "tabs.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "tabs.unsavedChanges.message"))
        }
    }
}
