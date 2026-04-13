// appi/Presentation/Views/Environment/EnvVariableRow.swift
import SwiftUI

struct EnvVariableRow: View {
    let variable: EnvVariable
    let environmentId: UUID
    @Bindable var viewModel: EnvironmentViewModel

    @State private var key: String
    @State private var value: String
    @State private var isSecret: Bool

    init(variable: EnvVariable, environmentId: UUID, viewModel: EnvironmentViewModel) {
        self.variable = variable
        self.environmentId = environmentId
        self.viewModel = viewModel
        _key = State(initialValue: variable.key)
        _value = State(initialValue: variable.value)
        _isSecret = State(initialValue: variable.isSecret)
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { variable.isEnabled },
                set: { _ in Task { await viewModel.toggleVariable(variable.id, in: environmentId) } }
            ))
            .labelsHidden()
            .accessibilityLabel(String(localized: "env.variable.enabled"))

            TextField(String(localized: "env.variable.key"), text: $key)
                .textFieldStyle(.plain)
                .frame(maxWidth: .infinity)
                .onSubmit { commitKey() }
                .accessibilityLabel(String(localized: "env.variable.key"))

            if isSecret {
                SecureField(String(localized: "env.variable.value"), text: $value)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .onSubmit { commitValue() }
                    .accessibilityLabel(String(localized: "env.variable.secretValue"))
            } else {
                TextField(String(localized: "env.variable.value"), text: $value)
                    .textFieldStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .onSubmit { commitValue() }
                    .accessibilityLabel(String(localized: "env.variable.value"))
            }

            Toggle(String(localized: "env.variable.secret"), isOn: Binding(
                get: { isSecret },
                set: { newValue in
                    isSecret = newValue
                    Task {
                        await viewModel.updateVariable(
                            variable.id,
                            in: environmentId,
                            key: key,
                            value: value,
                            isSecret: newValue
                        )
                    }
                }
            ))
            .toggleStyle(.checkbox)
            .accessibilityLabel(String(localized: "env.variable.secret"))

            Button {
                Task { await viewModel.deleteVariable(variable.id, from: environmentId) }
            } label: {
                Image(systemName: "minus.circle")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "env.variable.delete"))
        }
        .opacity(variable.isEnabled ? 1 : 0.4)
    }

    private func commitKey() {
        let trimmed = key.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != variable.key else { return }
        Task {
            await viewModel.updateVariable(
                variable.id,
                in: environmentId,
                key: trimmed,
                value: value,
                isSecret: isSecret
            )
        }
    }

    private func commitValue() {
        guard value != variable.value else { return }
        Task {
            await viewModel.updateVariable(
                variable.id,
                in: environmentId,
                key: key,
                value: value,
                isSecret: isSecret
            )
        }
    }
}
