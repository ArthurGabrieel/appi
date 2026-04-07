import SwiftUI

struct RequestRow: View {
    let request: Request

    var body: some View {
        HStack(spacing: 6) {
            Text(request.method.rawValue)
                .font(.caption.monospaced().bold())
                .foregroundStyle(color(for: request.method))
                .frame(width: 50, alignment: .leading)

            Text(request.name)
                .lineLimit(1)
        }
        .accessibilityLabel(String(localized: "sidebar.request.label \(request.method.rawValue) \(request.name)"))
    }

    private func color(for method: HTTPMethod) -> Color {
        switch method {
        case .get: .green
        case .post: .orange
        case .put: .blue
        case .patch: .purple
        case .delete: .red
        case .head: .gray
        case .options: .gray
        }
    }
}
