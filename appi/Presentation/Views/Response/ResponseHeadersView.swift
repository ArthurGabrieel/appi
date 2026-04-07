import SwiftUI

struct ResponseHeadersView: View {
    let headers: [Header]

    var body: some View {
        List(headers) { header in
            HStack {
                Text(header.key)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Spacer()
                Text(header.value)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
        .listStyle(.plain)
        .accessibilityLabel(String(localized: "response.headersList"))
    }
}
