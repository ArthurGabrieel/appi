import SwiftUI

struct HeadersEditorView: View {
    @Binding var headers: [Header]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(String(localized: "headers.title"))
                    .font(.headline)
                Spacer()
                Button {
                    headers.append(Header(id: UUID(), key: "", value: "", isEnabled: true))
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(String(localized: "headers.add"))
            }
            .padding(.horizontal)

            if headers.isEmpty {
                Text(String(localized: "headers.empty"))
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach($headers) { $header in
                        HStack {
                            Toggle("", isOn: $header.isEnabled)
                                .labelsHidden()
                                .accessibilityLabel(String(localized: "headers.toggle"))
                            TextField(String(localized: "headers.key"), text: $header.key)
                                .textFieldStyle(.roundedBorder)
                            TextField(String(localized: "headers.value"), text: $header.value)
                                .textFieldStyle(.roundedBorder)
                            Button {
                                headers.removeAll { $0.id == header.id }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(String(localized: "headers.remove"))
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }
}
