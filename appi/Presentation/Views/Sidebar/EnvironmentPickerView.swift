// appi/Presentation/Views/Sidebar/EnvironmentPickerView.swift
import SwiftUI

struct EnvironmentPickerView: View {
    @Bindable var viewModel: EnvironmentViewModel
    @State private var showEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(viewModel.environments) { env in
                        Button {
                            Task { await viewModel.activate(env) }
                        } label: {
                            HStack {
                                Text(env.name)
                                if env.isActive {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    if !viewModel.environments.isEmpty { Divider() }
                    Button(String(localized: "env.picker.noEnvironment")) {
                        Task { await viewModel.deactivate() }
                    }
                    Divider()
                    Button(String(localized: "env.picker.manage")) {
                        showEditor = true
                    }
                } label: {
                    Text(viewModel.activeEnvironment?.name ?? String(localized: "env.picker.none"))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .accessibilityLabel(String(localized: "env.picker.label"))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Inline error for activate/deactivate failures in the sidebar context.
            // The full EnvironmentEditorSheet shows its own error banner for save/delete operations.
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .accessibilityLabel(String(localized: "env.picker.error"))
            }
        }
        .sheet(isPresented: $showEditor) {
            EnvironmentEditorSheet(viewModel: viewModel)
        }
    }
}
