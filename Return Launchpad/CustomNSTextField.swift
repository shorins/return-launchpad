import AppKit

class CustomNSTextField: NSTextField {
    var onArrowKey: ((ArrowKey) -> Void)?
    var onEnterKey: (() -> Void)?

    enum ArrowKey {
        case up, down, left, right
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // This method is called for key equivalents (like command-key combinations)
        // but also for some special keys like Enter.
        if event.keyCode == 36 { // Enter key
            onEnterKey?()
            return true // Handle the event
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        switch Int(event.keyCode) {
        case 126: // Up arrow
            onArrowKey?(.up)
            return // Prevent default behavior
        case 125: // Down arrow
            onArrowKey?(.down)
            return
        case 123: // Left arrow
            onArrowKey?(.left)
            return
        case 124: // Right arrow
            onArrowKey?(.right)
            return
        default:
            super.keyDown(with: event) // Handle other keys normally
        }
    }
}
