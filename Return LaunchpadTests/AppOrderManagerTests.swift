import XCTest
@testable import Return_Launchpad

final class LayoutDocumentTests: XCTestCase {
    private func document(_ ids: [String] = ["a", "b", "c", "d"]) -> LayoutDocument {
        var result = LayoutDocument(); result.rootItems = ids; return result
    }
    func testMoveRightUsesAnchorAfterRemoval() {
        var layout = document()
        XCTAssertTrue(layout.move("a", to: .root, before: "c"))
        XCTAssertEqual(layout.rootItems, ["b", "a", "c", "d"])
        XCTAssertTrue(layout.move("a", to: .root, before: nil))
        XCTAssertEqual(layout.rootItems, ["b", "c", "d", "a"])
    }
    func testMoveLeftAndNoOp() {
        var layout = document()
        XCTAssertTrue(layout.move("d", to: .root, before: "a"))
        XCTAssertEqual(layout.rootItems, ["d", "a", "b", "c"])
        let before = layout
        XCTAssertFalse(layout.move("d", to: .root, before: "d"))
        XCTAssertEqual(layout, before)
        XCTAssertFalse(layout.move("missing", to: .root, before: nil))
    }
    func testFolderCreationAndExtractionAreAtomic() throws {
        var layout = document()
        let id = try XCTUnwrap(layout.createFolder(source: "a", target: "c"))
        XCTAssertEqual(layout.rootItems, ["b", id, "d"])
        XCTAssertEqual(layout.folder(id)?.appIDs, ["c", "a"])
        XCTAssertTrue(layout.isValid)
        layout.move("d", to: .folder(id), before: "a")
        XCTAssertEqual(layout.folder(id)?.appIDs, ["c", "d", "a"])
        layout.move("c", to: .root, before: "b")
        XCTAssertEqual(layout.rootItems, ["c", "b", id])
        XCTAssertTrue(layout.isValid)
    }
    func testLastChildRemovesEmptyFolderButSingleChildRemains() throws {
        var layout = document(["a", "b"])
        let id = try XCTUnwrap(layout.createFolder(source: "a", target: "b"))
        layout.move("a", to: .root, before: nil)
        XCTAssertEqual(layout.folder(id)?.appIDs, ["b"])
        layout.move("b", to: .root, before: nil)
        XCTAssertTrue(layout.folders.isEmpty)
        XCTAssertEqual(layout.rootItems, ["a", "b"])
        XCTAssertTrue(layout.isValid)
    }
    func testFolderCannotBeNested() throws {
        var layout = document()
        let first = try XCTUnwrap(layout.createFolder(source: "a", target: "b"))
        let second = try XCTUnwrap(layout.createFolder(source: "c", target: "d"))
        let original = layout
        XCTAssertFalse(layout.move(first, to: .folder(second), before: nil))
        XCTAssertEqual(layout, original)
    }
    func testRenameAndDissolvePreserveOrder() throws {
        var layout = document()
        let id = try XCTUnwrap(layout.createFolder(source: "a", target: "b"))
        layout.renameFolder(id, name: "  Работа  ")
        XCTAssertEqual(layout.folder(id)?.name, "Работа")
        layout.renameFolder(id, name: "  ")
        XCTAssertEqual(layout.folder(id)?.name, "Работа")
        layout.dissolveFolder(id)
        XCTAssertEqual(layout.rootItems, ["b", "a", "c", "d"])
        XCTAssertTrue(layout.isValid)
    }
    func testDragPreviewDoesNotModifyOriginalAndUsesIDsAcrossPages() {
        let original = document((0..<100).map { "app.\($0)" })
        var drag = DragSessionManager(itemID: "app.2", document: original)
        drag.previewMove(to: .root, before: "app.80")
        XCTAssertEqual(drag.original, original)
        XCTAssertEqual(drag.preview.rootItems[79], "app.2")
        drag.previewMove(to: .root, before: "app.1")
        XCTAssertEqual(drag.preview.rootItems[1], "app.2")
        XCTAssertEqual(Set(drag.preview.allAppIDs).count, 100)
        XCTAssertTrue(drag.preview.isValid)
    }
    func testFolderPreviewCanBeDiscarded() {
        let original = document()
        var drag = DragSessionManager(itemID: "a", document: original)
        drag.previewFolder(on: "b")
        XCTAssertEqual(drag.original, original)
        XCTAssertEqual(drag.preview.folders.count, 1)
        XCTAssertTrue(drag.preview.isValid)
    }
    func testInvalidAnchorDoesNotLoseSource() {
        var layout = document()
        let original = layout
        XCTAssertFalse(layout.move("a", to: .root, before: "missing"))
        XCTAssertEqual(layout, original)
    }
    func testCatalogReconcilePreservesUnavailableAppsAndFolderMembership() throws {
        var layout = document(["a", "b"])
        let folder = try XCTUnwrap(layout.createFolder(source: "a", target: "b"))
        layout.reconcile([AppInfo(name: "C", url: URL(fileURLWithPath: "/C.app"), bundleIdentifier: "c")])
        XCTAssertEqual(layout.rootItems, [folder, "c"])
        XCTAssertEqual(layout.folder(folder)?.appIDs, ["b", "a"])
        XCTAssertTrue(layout.isValid)
    }
    func testValidationRejectsDuplicatesAndUnsupportedVersion() {
        var layout = document(["a", "a"])
        XCTAssertFalse(layout.isValid)
        layout = document(); layout.schemaVersion = 999
        XCTAssertFalse(layout.isValid)
    }
    func testRepeatedMovesPreserveEveryItem() {
        var layout = document((0..<100).map { "app.\($0)" })
        for index in 0..<500 {
            layout.move("app.\(index % 100)", to: .root, before: "app.\((index * 17 + 3) % 100)")
            XCTAssertTrue(layout.isValid)
            XCTAssertEqual(Set(layout.allAppIDs).count, 100)
        }
    }
}

final class LayoutPersistenceTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    func testAtomicRoundTripAndOrderedWrites() throws {
        let storage = LayoutPersistence(fileURL: directory.appendingPathComponent("layout.json"))
        var layout = LayoutDocument(); layout.rootItems = ["a", "b", "c"]
        storage.save(layout)
        layout.createFolder(source: "a", target: "b")
        storage.save(layout)
        storage.flush()
        XCTAssertEqual(try storage.load(), layout)
    }
    func testMigrationUsesIsolatedDefaultsAndKeepsOriginal() throws {
        let suite = "ReturnLaunchpadTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "\(NSUserName())_userAppOrder"
        defaults.set(true, forKey: "\(NSUserName())_isCustomOrderEnabled")
        defaults.set("[\"c\",\"a\",\"a\",\"b\"]", forKey: key)
        let file = directory.appendingPathComponent("layout.json")
        let storage = LayoutPersistence(fileURL: file)
        let result = try storage.load(legacyDefaults: [defaults])
        XCTAssertEqual(result.rootItems, ["c", "a", "b"])
        XCTAssertTrue(result.isCustomized)
        XCTAssertNotNil(defaults.string(forKey: key))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.appendingPathExtension("legacy-backup").path))
    }
    func testCorruptDocumentRemainsUntouched() throws {
        let file = directory.appendingPathComponent("layout.json")
        let data = Data("broken".utf8)
        try data.write(to: file)
        XCTAssertThrowsError(try LayoutPersistence(fileURL: file).load())
        XCTAssertEqual(try Data(contentsOf: file), data)
    }
}
