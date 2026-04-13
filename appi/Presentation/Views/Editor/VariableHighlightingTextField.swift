import SwiftUI
import AppKit

struct VariableHighlightingTextField: NSViewRepresentable {
    @Binding var text: String
    let unresolvedKeys: [String]
    let placeholder: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.allowsEditingTextAttributes = false
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.currentEditor() != nil { return }
        nsView.attributedStringValue = attributedText()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func attributedText() -> NSAttributedString {
        let base = NSMutableAttributedString(string: text)
        let fullRange = NSRange(text.startIndex..., in: text)
        base.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        guard !unresolvedKeys.isEmpty else { return base }

        let pattern = try? NSRegularExpression(pattern: #"\{\{(\w+)\}\}"#)
        let matches = pattern?.matches(in: text, range: fullRange) ?? []
        for match in matches {
            let keyRange = Range(match.range(at: 1), in: text).map { String(text[$0]) } ?? ""
            if unresolvedKeys.contains(keyRange) {
                base.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: match.range)
            }
        }
        return base
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: VariableHighlightingTextField
        init(_ parent: VariableHighlightingTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                parent.text = field.stringValue
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                field.attributedStringValue = parent.attributedText()
            }
        }
    }
}
