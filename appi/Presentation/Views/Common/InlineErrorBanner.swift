import SwiftUI

struct InlineErrorBanner: View {
    let error: any LocalizedError
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(error.errorDescription ?? String(localized: "error.unknown"))
                .font(.callout)
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(String(localized: "error.banner"))
    }
}
