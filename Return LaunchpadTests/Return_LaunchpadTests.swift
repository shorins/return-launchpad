import XCTest
@testable import Return_Launchpad

final class AppScannerTests: XCTestCase {
    func testUserApplicationsRootIsOutsideSandboxContainer() {
        let path = AppScanner.userApplicationsDirectory.path
        XCTAssertTrue(path.hasSuffix("/Applications"))
        XCTAssertFalse(path.contains("/Library/Containers/"))
        XCTAssertTrue(AppScanner.defaultRoots.contains(AppScanner.userApplicationsDirectory))
    }
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    @discardableResult private func makeApp(_ path: String, id: String, agent: Bool = false) throws -> URL {
        let url = directory.appendingPathComponent(path)
        let contents = url.appendingPathComponent("Contents")
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = ["CFBundleIdentifier": id, "CFBundleName": path.components(separatedBy: "/").last!, "CFBundlePackageType": "APPL", "LSUIElement": agent]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }
    func testNestedApplicationsAndSystemRootsWithoutEmbeddedHelpers() throws {
        try makeApp("System/Applications/Utilities/Terminal.app", id: "terminal")
        try makeApp("Applications/Parent.app", id: "parent")
        try makeApp("Applications/Parent.app/Contents/Helpers/Helper.app", id: "helper")
        try makeApp("Applications/Agent.app", id: "agent", agent: true)
        let result = AppScanner(roots: [directory], excludedBundleID: nil).scan()
        XCTAssertEqual(Set(result.apps.map(\.id)), ["terminal", "parent"])
    }
    func testDeduplicationAndStableIdentity() throws {
        try makeApp("A.app", id: "same")
        try makeApp("B.app", id: "same")
        let scanner = AppScanner(roots: [directory, directory], excludedBundleID: nil)
        XCTAssertEqual(scanner.scan().apps.count, 1)
        XCTAssertEqual(scanner.scan().apps.first?.id, scanner.scan().apps.first?.id)
    }
    func testMissingRootAndSelfExclusion() throws {
        try makeApp("Self.app", id: "self")
        let result = AppScanner(roots: [directory, directory.appendingPathComponent("missing")], excludedBundleID: "self").scan()
        XCTAssertTrue(result.apps.isEmpty)
    }
}

@MainActor
final class AppManagerTests: XCTestCase {
    var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDownWithError() throws {
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }
    func testBackgroundClosesFolderBeforeDismissingLauncher() throws {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        model.createFolder("test.app.0", with: "test.app.25")
        model.folderID = try XCTUnwrap(model.layout.folders.first?.id)
        var dismissals = 0
        model.onDismiss = { dismissals += 1 }
        model.dismissBackground()
        XCTAssertNil(model.folderID)
        XCTAssertEqual(dismissals, 0)
        model.dismissBackground()
        XCTAssertEqual(dismissals, 1)
        model.flush()
    }

    func testArrowsPageWithoutSearchAndSelectSearchResults() {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        model.configureGrid(columns: 3, capacity: 6)
        model.handleArrow(1)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertNil(model.selectedID)
        model.handleArrow(-1)
        XCTAssertEqual(model.currentPage, 0)
        model.searchText = "a"
        XCTAssertFalse(model.visibleIDs.isEmpty)
        XCTAssertEqual(model.selectedID, model.visibleIDs.first)
        model.handleArrow(1)
        XCTAssertEqual(model.selectedID, model.visibleIDs[1])
        model.handleArrow(3)
        XCTAssertEqual(model.selectedID, model.visibleIDs[4])
        model.searchText = ""
        model.handleArrow(1)
        XCTAssertEqual(model.currentPage, 1)
        XCTAssertNil(model.selectedID)
    }

    func testUndoRedoAndPersistence() throws {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        let before = model.layout
        model.moveItem("test.app.0", to: .root)
        let after = model.layout
        XCTAssertNotEqual(before, after)
        model.undo(); XCTAssertEqual(model.layout, before)
        model.redo(); XCTAssertEqual(model.layout, after)
        model.flush()
        XCTAssertEqual(try LayoutPersistence(fileURL: directory.appendingPathComponent("layout-v2.json")).load(), after)
    }
    func testSearchDoesNotPermitDragAndFindsFolderChildren() {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        model.createFolder("test.app.0", with: "test.app.1")
        model.searchText = "Calculator"
        XCTAssertTrue(model.visibleIDs.contains("test.app.0"))
        XCTAssertNil(model.beginDrag("test.app.0"))
        XCTAssertNotNil(model.parentFolderName("test.app.0"))
        model.flush()
    }
    func testCancelDragNeverSavesPreview() {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        let original = model.layout
        XCTAssertNotNil(model.beginDrag("test.app.0"))
        model.previewMove(before: nil)
        XCTAssertNotEqual(model.displayedLayout, original)
        model.cancelDrag()
        XCTAssertEqual(model.layout, original)
        XCTAssertNil(model.drag)
        model.flush()
    }
    func testKeyboardSelectionStartsAtFirstItem() {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        model.navigate(model.columnCount)
        XCTAssertEqual(model.selectedID, model.visibleIDs.first)
        model.navigate(model.columnCount)
        XCTAssertEqual(model.selectedID, model.visibleIDs[model.columnCount])
        model.flush()
    }
    func testEdgePreviewActuallyInsertsIntoDestinationPage() {
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        model.configureGrid(columns: 5, capacity: 20)
        let id = model.visibleIDs[0]
        XCTAssertNotNil(model.beginDrag(id))
        model.changePage(1)
        model.previewMoveToPageEdge(forward: true)
        XCTAssertEqual(model.pageIDs.first, id)
        model.commitDrag()
        XCTAssertEqual(model.layout.rootItems[20], id)
        model.flush()
    }
}
