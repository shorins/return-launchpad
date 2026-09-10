import Foundation

/// The drag state is independent of pages and views. Cancel never mutates the original layout.
struct DragSessionManager {
    let sessionID = UUID().uuidString
    let itemID: String
    let original: LayoutDocument
    private(set) var preview: LayoutDocument
    init(itemID: String, document: LayoutDocument) {
        self.itemID = itemID
        original = document
        preview = document
    }
    mutating func previewMove(to container: LayoutContainer, before anchor: String?) {
        var next = original
        next.move(itemID, to: container, before: anchor)
        preview = next
    }
    mutating func previewFolder(on target: String) {
        var next = original
        if next.folder(target) != nil {
            next.move(itemID, to: .folder(target), before: nil)
        } else {
            next.createFolder(source: itemID, target: target)
        }
        preview = next
    }
}
