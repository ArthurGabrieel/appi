import SwiftUI

struct RequestEditorView: View {
    @Bindable var viewModel: RequestEditorViewModel
    let activeEnvironment: Environment?

    @State private var selectedRequestTab: RequestTab = .headers

    enum RequestTab: String, CaseIterable {
        case headers, body, auth
    }

    private var unresolvedKeys: [String] {
        viewModel.unresolvedKeys(environment: activeEnvironment)
    }

    var body: some View {
        VSplitView {
            // Request panel
            VStack(spacing: 0) {
                URLBarView(
                    method: $viewModel.draft.method,
                    url: $viewModel.draft.url,
                    unresolvedKeys: unresolvedKeys,
                    isLoading: viewModel.isLoading,
                    onSend: { viewModel.startSend(environment: activeEnvironment) },
                    onCancel: { viewModel.cancelRequest() }
                )

                Picker("", selection: $selectedRequestTab) {
                    Text(String(localized: "request.headers")).tag(RequestTab.headers)
                    Text(String(localized: "request.body")).tag(RequestTab.body)
                    Text(String(localized: "request.auth")).tag(RequestTab.auth)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                switch selectedRequestTab {
                case .headers:
                    HeadersEditorView(headers: $viewModel.draft.headers)
                case .body:
                    BodyEditorView(requestBody: $viewModel.draft.body)
                case .auth:
                    AuthEditorView(
                        auth: $viewModel.draft.auth,
                        allowInherit: true,
                        effectiveAuth: viewModel.effectiveAuth,
                        authError: viewModel.authError,
                        onClearAuthError: { viewModel.authError = nil },
                        onGetToken: { config in
                            await viewModel.authorizeOAuth2(config: config)
                        }
                    )
                    .onChange(of: viewModel.draft.auth) { _, _ in
                        Task { await viewModel.loadEffectiveAuth() }
                    }
                    .task { await viewModel.loadEffectiveAuth() }
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
