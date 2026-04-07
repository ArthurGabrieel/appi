import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: CollectionTreeViewModel

    var body: some View {
        VStack(spacing: 0) {
            CollectionTreeView(viewModel: viewModel)
                .searchable(text: $viewModel.searchQuery, prompt: String(localized: "sidebar.search.prompt"))

            Divider()

            // Environment picker placeholder — Sprint 3
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                Text(String(localized: "sidebar.noEnvironment"))
                    .foregroundStyle(.secondary)
                    .font(.caption)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .accessibilityLabel(String(localized: "sidebar.label"))
    }
}
