import SwiftUI

struct RequestEditorView: View {
    @Bindable var viewModel: RequestEditorViewModel
    let activeEnvironment: Environment?

    @State private var selectedRequestTab: RequestTab = .headers

    enum RequestTab: String, CaseIterable {
        case headers, body
    }

    var body: some View {
        VSplitView {
            // Request panel
            VStack(spacing: 0) {
                URLBarView(
                    method: $viewModel.draft.method,
                    url: $viewModel.draft.url,
                    isLoading: viewModel.isLoading,
                    onSend: { await viewModel.send(environment: activeEnvironment) },
                    onCancel: { viewModel.cancelRequest() }
                )

                Picker("", selection: $selectedRequestTab) {
                    Text(String(localized: "request.headers")).tag(RequestTab.headers)
                    Text(String(localized: "request.body")).tag(RequestTab.body)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedRequestTab {
                case .headers:
                    HeadersEditorView(headers: $viewModel.draft.headers)
                case .body:
                    BodyEditorView(requestBody: $viewModel.draft.body)
                }
            }

            // Response panel
            VStack(spacing: 0) {
                if let error = viewModel.error {
                    InlineErrorBanner(error: error) {
                        viewModel.error = nil
                    }
                    .padding(.horizontal)
                }

                if let response = viewModel.response {
                    ResponseViewerView(response: response)
                } else {
                    Text(String(localized: "response.placeholder"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }
}
