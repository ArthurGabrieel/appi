// appi/Presentation/Views/Environment/EnvironmentEditorSheet.swift
import SwiftUI

struct EnvironmentEditorSheet: View {
    @Bindable var viewModel: EnvironmentViewModel
    @SwiftUI.Environment(\.dismiss) private var dismiss
    @State private var selectedEnvironmentId: UUID?
    @State private var renamingId: UUID?
    @State private var renameText: String = ""

    private var selectedEnvironment: Environment? {
        viewModel.environments.first(where: { $0.id == selectedEnvironmentId })
    }

    var body: some View {
        VStack(spacing: 0) {
            if let error = viewModel.error {
                InlineErrorBanner(error: error) {
                    viewModel.clearError()
                }
                .padding([.top, .horizontal])
            }

            HSplitView {
                // Left: environment list
                VStack(alignment: .leading, spacing: 0) {
                    List(selection: $selectedEnvironmentId) {
                        ForEach(viewModel.environments) { env in
                            Group {
                                if renamingId == env.id {
                                    TextField("", text: $renameText)
                                        .textFieldStyle(.plain)
                                        .onSubmit { commitRename(env) }
                                        .onExitCommand { renamingId = nil }
                                } else {
                                    HStack {
                                        Text(env.name)
                                        if env.isActive {
                                            Spacer()
                                            Circle().fill(.green).frame(width: 8, height: 8)
                                        }
                                    }
                                    .contextMenu {
                                        Button(String(localized: "env.rename")) {
                                            renameText = env.name
                                            renamingId = env.id
                                        }
                                        Divider()
                                        Button(String(localized: "env.delete"), role: .destructive) {
                                            Task { await viewModel.delete(env) }
                                        }
                                    }
                                }
                            }
                            .tag(env.id)
                        }
                    }
                    .listStyle(.sidebar)
                    .accessibilityLabel(String(localized: "env.list.label"))

                    Divider()
                    HStack {
                        Button {
                            Task { await viewModel.createEnvironment(name: String(localized: "env.newEnvironmentDefaultName")) }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "env.add"))
                        Spacer()
                    }
                    .padding(8)
                }
                .frame(minWidth: 180, maxWidth: 200)

                // Right: variable editor
                VStack(alignment: .leading, spacing: 0) {
                    if let env = selectedEnvironment {
                        HStack {
                            Text(env.name).font(.headline)
                            Spacer()
                            if env.isActive {
                                Text(String(localized: "env.active"))
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Button(String(localized: "env.activate")) {
                                    Task { await viewModel.activate(env) }
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()

                        Divider()

                        List {
                            ForEach(env.variables) { variable in
                                EnvVariableRow(
                                    variable: variable,
                                    environmentId: env.id,
                                    viewModel: viewModel
                                )
                            }
                        }
                        .listStyle(.plain)

                        Divider()
                        HStack {
                            Button {
                                Task {
                                    await viewModel.addVariable(
                                        to: env.id, key: "", value: "", isSecret: false
                                    )
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "env.variable.add"))
                            Spacer()
                        }
                        .padding(8)
                    } else {
                        Text(String(localized: "env.selectEnvironment"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(minWidth: 400)
            }
        }
        .frame(minWidth: 620, minHeight: 400)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "action.done")) { dismiss() }
            }
        }
        .onAppear {
            selectedEnvironmentId = viewModel.activeEnvironment?.id ?? viewModel.environments.first?.id
        }
    }

    private func commitRename(_ env: Environment) {
        let name = renameText.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty {
            Task { await viewModel.rename(env.id, to: name) }
        }
        renamingId = nil
    }
}
