import XCTest
import AppKit
@testable import Return_Launchpad

@MainActor
final class GridGeometryTests: XCTestCase {
    func testRapidReorderCPUWorkload() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        let preferences = LauncherPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        preferences.motion = .smooth
        let grid = LauncherGridView(frame: NSRect(x: 0, y: 0, width: 1512, height: 720))
        grid.model = model; grid.preferences = preferences
        model.configureGrid(columns: 9, capacity: 45)
        grid.refresh()
        let original = model.layout
        let anchors = Array(model.pageIDs.dropFirst())
        XCTAssertNotNil(model.beginDrag("test.app.0"))
        var timings: [Double] = []
        for index in 0..<300 {
            let start = ProcessInfo.processInfo.systemUptime
            autoreleasepool {
                model.previewMove(before: anchors[(index * 17) % anchors.count])
                grid.refresh()
            }
            timings.append((ProcessInfo.processInfo.systemUptime - start) * 1000)
        }
        timings.sort()
        print("REORDER_CPU_MS median=\(timings[150]) p95=\(timings[285]) total=\(timings.reduce(0, +))")
        model.cancelDrag()
        XCTAssertEqual(model.layout, original)
        model.flush()
    }

    func testSearchUsesFadeAndResetsCachedPointerHighlight() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        let preferences = LauncherPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        preferences.motion = .smooth
        let grid = LauncherGridView(frame: NSRect(x: 0, y: 0, width: 1512, height: 720))
        grid.model = model; grid.preferences = preferences
        model.configureGrid(columns: 9, capacity: 45)
        grid.refresh()
        let tiles = grid.subviews.flatMap(\.subviews).compactMap { $0 as? LauncherTile }
        let first = try XCTUnwrap(tiles.first)
        let second = try XCTUnwrap(tiles.dropFirst().first)
        first.onPointerEnter?()
        XCTAssertTrue(first.hovered)
        second.onPointerEnter?()
        XCTAssertFalse(first.hovered)
        XCTAssertTrue(second.hovered)
        model.searchText = "Calculator"
        grid.refresh()
        XCTAssertFalse(tiles.contains { $0.hovered })
        let page = try XCTUnwrap(grid.subviews.first { $0.layer?.animation(forKey: "searchFade") != nil })
        XCTAssertNil(page.layer?.animation(forKey: "pageSlide"))
        let results = page.subviews.compactMap { $0 as? LauncherTile }
        XCTAssertEqual(results.count, 4)
        XCTAssertTrue(results.allSatisfy { ($0.layer?.animationKeys() ?? []).isEmpty })
        let result = try XCTUnwrap(results.first)
        result.setPointerHovered(true)
        model.presentationID = UUID()
        grid.refresh()
        XCTAssertFalse(result.hovered)
        model.flush()
    }

    func testSparseFolderKeepsFullPageBaseline() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = AppManager(directory: directory, legacyDefaults: [], testing: true)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let preferences = LauncherPreferences(defaults: defaults)
        preferences.motion = .reduced
        let grid = LauncherGridView(frame: NSRect(x: 0, y: 0, width: 1512, height: 720))
        grid.model = model
        grid.preferences = preferences
        model.configureGrid(columns: 9, capacity: 45)
        grid.refresh()
        func firstRow() throws -> CGFloat {
            let tiles = grid.subviews.flatMap(\.subviews).compactMap { $0 as? LauncherTile }
            return try XCTUnwrap(tiles.map { $0.frame.minY }.min())
        }
        let baseline = try firstRow()
        model.createFolder("test.app.0", with: "test.app.25")
        grid.refresh()
        model.folderID = try XCTUnwrap(model.layout.folders.first?.id)
        grid.refresh()
        XCTAssertEqual(try firstRow(), baseline, accuracy: 0.01)
        grid.layoutSubtreeIfNeeded()
        grid.refresh()
        XCTAssertEqual(try firstRow(), baseline, accuracy: 0.01)
        model.folderID = nil
        grid.refresh()
        XCTAssertEqual(try firstRow(), baseline, accuracy: 0.01)
        model.flush()
    }
}
