import SwiftUI

struct SidebarView: View {
    @Bindable var viewModel: CollectionTreeViewModel
    @Bindable var environmentViewModel: EnvironmentViewModel

    var body: some View {
        VStack(spacing: 0) {
            CollectionTreeView(viewModel: viewModel)
                .searchable(text: $viewModel.searchQuery, prompt: String(localized: "sidebar.search.prompt"))

            Divider()

            EnvironmentPickerView(viewModel: environmentViewModel)
        }
        .accessibilityLabel(String(localized: "sidebar.label"))
    }
}
