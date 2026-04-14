// appi/Presentation/Views/Sidebar/CollectionAuthSheet.swift
import SwiftUI

struct CollectionAuthSheet: View {
    let collection: Collection
    @Bindable var viewModel: CollectionTreeViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var auth: AuthConfig
    @State private var effectiveAuth: AuthConfig?

    init(collection: Collection, viewModel: CollectionTreeViewModel) {
        self.collection = collection
        self.viewModel = viewModel
        _auth = State(initialValue: collection.auth)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "collection.auth.title \(collection.name)"))
                .font(.headline)
                .padding()

            AuthEditorView(
                auth: $auth,
                allowInherit: collection.parentId != nil,
                effectiveAuth: effectiveAuth,
                authError: viewModel.collectionAuthError,
                onClearAuthError: { viewModel.collectionAuthError = nil },
                onGetToken: { config in
                    await viewModel.authorizeCollectionOAuth2(collection.id, config: config)
                }
            )

            Divider()
            HStack {
                Button(String(localized: "action.cancel"), role: .cancel) { dismiss() }
                Spacer()
                Button(String(localized: "action.save")) {
                    Task {
                        let saved = await viewModel.updateCollectionAuth(collection.id, auth: auth)
                        if saved { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(minWidth: 480, minHeight: 360)
        .accessibilityLabel(String(localized: "collection.auth.label"))
        .task {
            viewModel.collectionAuthError = nil
            effectiveAuth = await viewModel.loadEffectiveCollectionAuth(collection.id)
        }
        .onChange(of: auth) { _, newValue in
            Task {
                if case .inheritFromParent = newValue {
                    effectiveAuth = await viewModel.loadEffectiveCollectionAuth(collection.id)
                } else {
                    effectiveAuth = nil
                }
            }
        }
    }
}
