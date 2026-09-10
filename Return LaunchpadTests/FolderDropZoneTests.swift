import XCTest
import AppKit
@testable import Return_Launchpad

@MainActor
final class FolderDropZoneTests: XCTestCase {
    func testDropZoneStateResetsWithoutChangingGeometryOrLeavingHoverTimer() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        model.createFolder("test.app.0", with: "test.app.25")
        let folder = try XCTUnwrap(model.layout.folders.first?.id)
        model.folderID = folder
        let button = FolderBackNativeButton()
        button.model = model
        button.frame = NSRect(x: 30, y: 10, width: 320, height: 34)
        let frame = button.frame
        button.configureDropZone(active: false, folderName: "Папка", reduceMotion: true)
        XCTAssertEqual(button.title, "Папка")
        XCTAssertNotNil(model.beginDrag("test.app.0"))
        button.configureDropZone(active: true, folderName: "Папка", reduceMotion: true)
        XCTAssertTrue(button.dropMode)
        XCTAssertEqual(button.title, L10n.text("Drag to main screen"))
        XCTAssertEqual(button.frame, frame)
        if let bitmap = button.bitmapImageRepForCachingDisplay(in: button.bounds) {
            button.cacheDisplay(in: button.bounds, to: bitmap)
            let preview = FileManager.default.temporaryDirectory.appendingPathComponent("launchpad-dropzone-preview.png")
            try bitmap.representation(using: .png, properties: [:])?.write(to: preview)
            print("DROP_ZONE_PREVIEW=\(preview.path)")
        }
        button.beginInternalHover()
        XCTAssertEqual(button.title, L10n.text("Release to move to main screen"))
        model.cancelDrag()
        button.configureDropZone(active: false, folderName: "Папка", reduceMotion: true)
        XCTAssertFalse(button.dropMode)
        XCTAssertEqual(button.title, "Папка")
        XCTAssertEqual(button.layer?.borderWidth, 0)
        XCTAssertEqual(button.frame, frame)
        // A new session must not inherit the previous hover timer or highlight.
        XCTAssertNotNil(model.beginDrag("test.app.0"))
        button.configureDropZone(active: true, folderName: "Папка", reduceMotion: true)
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(model.folderID, folder)
        XCTAssertEqual(button.title, L10n.text("Drag to main screen"))
        model.cancelDrag()
        model.flush()
    }
}
