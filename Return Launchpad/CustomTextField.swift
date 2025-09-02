import SwiftUI
import AppKit

struct CustomTextField: NSViewRepresentable {
    @Binding var text: String
    var onArrowKey: ((CustomNSTextField.ArrowKey) -> Void)?
    var onEnterKey: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?

    func makeNSView(context: Context) -> CustomNSTextField {
        let textField = CustomNSTextField()
        textField.delegate = context.coordinator
        textField.onArrowKey = onArrowKey
        textField.onEnterKey = onEnterKey
        textField.isBordered = false
        textField.focusRingType = .none
        textField.backgroundColor = .clear
        textField.font = .systemFont(ofSize: 36) // Match existing font size
        textField.textColor = .white // Match existing text color
        textField.placeholderString = "Search" // Match existing placeholder

        // Set up a notification observer for focus changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.controlTextDidBeginEditing(_:)),
            name: NSTextField.textDidBeginEditingNotification,
            object: textField
        )
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(context.coordinator.controlTextDidEndEditing(_:)),
            name: NSTextField.textDidEndEditingNotification,
            object: textField
        )

        return textField
    }

    func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: CustomTextField

        init(_ parent: CustomTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let textField = obj.object as? NSTextField else { return }
            parent.text = textField.stringValue
        }

        @objc func controlTextDidBeginEditing(_ obj: Notification) {
            parent.onFocusChange?(true)
        }

        @objc func controlTextDidEndEditing(_ obj: Notification) {
            parent.onFocusChange?(false)
        }

        // Method to handle special commands, including arrow keys
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.moveLeft(_:)):
                parent.onArrowKey?(.left)
                return true // Prevent default behavior (cursor movement)
            case #selector(NSResponder.moveRight(_:)):
                parent.onArrowKey?(.right)
                return true // Prevent default behavior
            case #selector(NSResponder.moveUp(_:)):
                parent.onArrowKey?(.up) // Although we don't use Up/Down for icon navigation, we can still capture it
                return true // Prevent default behavior
            case #selector(NSResponder.moveDown(_:)):
                parent.onArrowKey?(.down) // Same as above
                return true // Prevent default behavior
            default:
                return false // Allow standard handling for other commands
            }
        }
    }
}
