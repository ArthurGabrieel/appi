import SwiftUI
import AppKit

struct VariableHighlightingTextField: NSViewRepresentable {
    @Binding var text: String
    let unresolvedKeys: [String]
    let placeholder: String

    private static let variablePattern = try! NSRegularExpression(pattern: #"\{\{(\w+)\}\}"#)

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.allowsEditingTextAttributes = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Skip re-applying attributes while the user is actively editing to avoid
        // clobbering the cursor position. controlTextDidEndEditing handles the
        // highlighting update on blur. This means unresolvedKeys changes won't
        // reflect live while the field is focused — an accepted trade-off.
        if nsView.currentEditor() != nil { return }
        nsView.attributedStringValue = attributedText()
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func attributedText() -> NSAttributedString {
        let base = NSMutableAttributedString(string: text)
        let fullRange = NSRange(text.startIndex..., in: text)
        base.addAttribute(.foregroundColor, value: NSColor.labelColor, range: fullRange)

        guard !unresolvedKeys.isEmpty else { return base }

        let matches = Self.variablePattern.matches(in: text, range: fullRange)
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
                // Reset typing attributes so newly typed characters use the default label color
                if let editor = field.currentEditor() as? NSTextView {
                    editor.typingAttributes = [
                        .foregroundColor: NSColor.labelColor,
                        .font: field.font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize)
                    ]
                }
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            if let field = obj.object as? NSTextField {
                field.attributedStringValue = parent.attributedText()
            }
        }
    }
}
