import SwiftUI

struct CollectionRow: View {
    let collection: Collection
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isExpanded ? "folder.fill" : "folder")
                .foregroundStyle(.secondary)
            Text(collection.name)
                .lineLimit(1)
        }
        .accessibilityLabel(String(localized: "sidebar.collection.label \(collection.name)"))
    }
}
