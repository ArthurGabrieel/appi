import SwiftUI

struct EmptyStateView: View {
    let onNewRequest: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(String(localized: "emptyState.title"))
                .font(.title2)
            Button(String(localized: "emptyState.newRequest")) { onNewRequest() }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("t", modifiers: .command)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(String(localized: "emptyState.title"))
    }
}
