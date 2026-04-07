import SwiftUI

struct TabItemView: View {
    let tab: Tab
    let isActive: Bool
    let isDirty: Bool
    let onActivate: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            if isDirty {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 6, height: 6)
                    .accessibilityLabel(String(localized: "tabs.unsavedChanges"))
            }

            Text(tab.draft.method.rawValue)
                .font(.caption2.monospaced().bold())
                .foregroundStyle(.secondary)

            Text(tab.draft.name)
                .lineLimit(1)
                .font(.caption)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "tabs.close"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isActive ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
        .onTapGesture { onActivate() }
        .accessibilityLabel(String(localized: "tabs.item.label \(tab.draft.method.rawValue) \(tab.draft.name)"))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}
