import SwiftUI

struct BodyEditorView: View {
    @Binding var requestBody: RequestBody

    @State private var selectedMode: BodyMode = .none

    enum BodyMode: String, CaseIterable {
        case none, raw, formData
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(String(localized: "body.mode"), selection: $selectedMode) {
                Text(String(localized: "body.none")).tag(BodyMode.none)
                Text(String(localized: "body.raw")).tag(BodyMode.raw)
                Text(String(localized: "body.formData")).tag(BodyMode.formData)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .accessibilityLabel(String(localized: "body.mode"))
            .onChange(of: selectedMode) { _, newValue in
                switch newValue {
                case .none:
                    requestBody = .none
                case .raw:
                    if case .raw = requestBody { return }
                    requestBody = .raw("", contentType: "application/json")
                case .formData:
                    if case .formData = requestBody { return }
                    requestBody = .formData([])
                }
            }

            switch requestBody {
            case .none:
                Text(String(localized: "body.noBody"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .raw(let content, let contentType):
                rawEditor(content: content, contentType: contentType)
            case .formData(let fields):
                formDataEditor(fields: fields)
            }
        }
        .onAppear {
            switch requestBody {
            case .none: selectedMode = .none
            case .raw: selectedMode = .raw
            case .formData: selectedMode = .formData
            }
        }
    }

    @ViewBuilder
    private func rawEditor(content: String, contentType: String) -> some View {
        HStack {
            Picker(String(localized: "body.contentType"), selection: Binding(
                get: { contentType },
                set: { requestBody = .raw(content, contentType: $0) }
            )) {
                Text("JSON").tag("application/json")
                Text("XML").tag("application/xml")
                Text("Text").tag("text/plain")
                Text("HTML").tag("text/html")
            }
            .frame(width: 150)
            .accessibilityLabel(String(localized: "body.contentType"))
        }
        .padding(.horizontal)

        TextEditor(text: Binding(
            get: { content },
            set: { requestBody = .raw($0, contentType: contentType) }
        ))
        .font(.system(.body, design: .monospaced))
        .accessibilityLabel(String(localized: "body.rawContent"))
    }

    @ViewBuilder
    private func formDataEditor(fields: [FormField]) -> some View {
        VStack {
            HStack {
                Spacer()
                Button {
                    var updated = fields
                    updated.append(FormField(id: UUID(), key: "", value: .text(""), isEnabled: true))
                    requestBody = .formData(updated)
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "body.addField"))
            }
            .padding(.horizontal)

            List {
                ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                    HStack {
                        Toggle("", isOn: Binding(
                            get: { field.isEnabled },
                            set: { newValue in
                                var updated = fields
                                updated[index] = FormField(
                                    id: field.id, key: field.key,
                                    value: field.value, isEnabled: newValue
                                )
                                requestBody = .formData(updated)
                            }
                        ))
                        .labelsHidden()
                        TextField(String(localized: "body.fieldKey"), text: Binding(
                            get: { field.key },
                            set: { newValue in
                                var updated = fields
                                updated[index] = FormField(
                                    id: field.id, key: newValue,
                                    value: field.value, isEnabled: field.isEnabled
                                )
                                requestBody = .formData(updated)
                            }
                        ))
                        .textFieldStyle(.roundedBorder)
                        if case .text(let text) = field.value {
                            TextField(String(localized: "body.fieldValue"), text: Binding(
                                get: { text },
                                set: { newValue in
                                    var updated = fields
                                    updated[index] = FormField(
                                        id: field.id, key: field.key,
                                        value: .text(newValue), isEnabled: field.isEnabled
                                    )
                                    requestBody = .formData(updated)
                                }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        Button {
                            var updated = fields
                            updated.remove(at: index)
                            requestBody = .formData(updated)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "body.removeField"))
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
