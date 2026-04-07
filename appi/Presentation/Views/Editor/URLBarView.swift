import SwiftUI

struct URLBarView: View {
    @Binding var method: HTTPMethod
    @Binding var url: String
    let isLoading: Bool
    let onSend: () async -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $method) {
                ForEach(HTTPMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .frame(width: 100)
            .accessibilityLabel(String(localized: "urlBar.method"))

            TextField(String(localized: "urlBar.placeholder"), text: $url)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(String(localized: "urlBar.url"))

            if isLoading {
                Button(String(localized: "action.cancel")) { onCancel() }
                    .accessibilityLabel(String(localized: "action.cancel"))
            } else {
                Button(String(localized: "action.send")) { Task { await onSend() } }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(String(localized: "action.send"))
                    .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
    }
}
