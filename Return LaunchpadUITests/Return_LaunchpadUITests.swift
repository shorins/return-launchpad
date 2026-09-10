import XCTest
import AppKit

@MainActor
final class Return_LaunchpadUITests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["--ui-testing", "--test-run", UUID().uuidString]
        app.launch()
        XCTAssertTrue(app.textFields["app-search"].waitForExistence(timeout: 8))
    }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app.terminate()
    }

    func testSearchSystemFixtureAndEscape() {
        let search = app.textFields["app-search"]
        search.click(); pasteIntoFocusedField("Terminal")
        XCTAssertTrue(app.buttons["tile-test.app.21"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["tile-test.app.0"].exists)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(app.buttons["tile-test.app.0"].waitForExistence(timeout: 3))
    }
    func testReorderAdjacentItemsAndUndo() {
        let first = app.buttons["tile-test.app.0"]
        let second = app.buttons["tile-test.app.25"]
        XCTAssertLessThan(first.frame.minX, second.frame.minX)
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).press(forDuration: 0.15,
            thenDragTo: second.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.45)),
            withVelocity: .slow, thenHoldForDuration: 0.15)
        XCTAssertTrue(waitUntil { first.frame.minX > second.frame.minX })
        undoLayout()
        XCTAssertTrue(waitUntil { first.frame.minX < second.frame.minX })
    }
    func testFolderHeaderIsCompactAndCentered() {
        let first = app.buttons["tile-test.app.0"]
        let second = app.buttons["tile-test.app.25"]
        first.press(forDuration: 0.15, thenDragTo: second, withVelocity: .slow, thenHoldForDuration: 0.7)
        let folder = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-folder:")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 3))
        folder.click()
        let back = app.buttons["folder-back"]
        let rename = app.buttons["folder-rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: 3))
        let group = back.frame.union(rename.frame)
        XCTAssertLessThan(group.width, 210)
        XCTAssertEqual(group.midX, app.windows["Return Launchpad"].frame.midX, accuracy: 8)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCreateFolderOpenAndExtract() {
        let first = app.buttons["tile-test.app.0"]
        let second = app.buttons["tile-test.app.25"]
        first.press(forDuration: 0.15, thenDragTo: second, withVelocity: .slow, thenHoldForDuration: 0.85)
        let folder = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-folder:")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 4))
        folder.click()
        let back = app.buttons["folder-back"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["tile-test.app.0"].exists)
        app.buttons["tile-test.app.0"].press(forDuration: 0.15, thenDragTo: back, withVelocity: .slow, thenHoldForDuration: 0.1)
        XCTAssertTrue(waitUntil { !back.exists })
        XCTAssertTrue(app.buttons["next-page"].isEnabled)
        app.activate()
        app.buttons["next-page"].click()
        XCTAssertTrue(app.buttons["tile-test.app.0"].waitForExistence(timeout: 3))
    }
    func testExistingFolderAcceptsQuickDropAndOpensOnHover() {
        let first = app.buttons["tile-test.app.0"]
        let second = app.buttons["tile-test.app.25"]
        first.press(forDuration: 0.15, thenDragTo: second, withVelocity: .slow, thenHoldForDuration: 0.7)
        let folder = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-folder:")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 3))
        let third = app.buttons["tile-test.app.50"]
        third.press(forDuration: 0.15, thenDragTo: folder, withVelocity: .fast, thenHoldForDuration: 0.1)
        XCTAssertFalse(app.buttons["folder-back"].exists)
        folder.click()
        XCTAssertTrue(third.waitForExistence(timeout: 3))
        app.buttons["folder-back"].click()
        // Core Animation is compositor-driven and may outlive XCTest's idle check.
        Thread.sleep(forTimeInterval: 0.4)
        let fourth = app.buttons["tile-test.app.75"]
        fourth.press(forDuration: 0.15, thenDragTo: folder, withVelocity: .fast, thenHoldForDuration: 1.2)
        XCTAssertTrue(app.buttons["folder-back"].waitForExistence(timeout: 3))
        XCTAssertTrue(fourth.exists)
    }

    func testCrossPageDragUsesEdgeAndCanUndo() {
        let first = app.buttons["tile-test.app.0"]
        let window = app.windows["Return Launchpad"]
        let edge = window.coordinate(withNormalizedOffset: CGVector(dx: 0.99, dy: 0.55))
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).press(forDuration: 0.15,
            thenDragTo: edge, withVelocity: .fast, thenHoldForDuration: 0.85)
        XCTAssertTrue(app.buttons["previous-page"].isEnabled)
        XCTAssertTrue(app.buttons["tile-test.app.0"].exists, "Drop at the edge must insert into the page now on screen")
        undoLayout()
        XCTAssertTrue(waitUntil { !self.app.buttons["tile-test.app.0"].exists }, "Undo must remove the item from its drag destination")
        app.buttons["page-0"].click()
        XCTAssertTrue(waitUntil { !self.app.buttons["previous-page"].isEnabled })
        XCTAssertTrue(app.buttons["tile-test.app.0"].exists)
        // Verify that Undo was persisted, not merely reflected by a temporary preview.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["tile-test.app.0"].waitForExistence(timeout: 3))
    }
    func testPageButtonsRespondToPointer() {
        app.activate()
        app.buttons["page-1"].click()
        XCTAssertTrue(waitUntil { self.app.buttons["previous-page"].isEnabled })
        app.activate()
        app.buttons["page-0"].click()
        XCTAssertTrue(waitUntil { !self.app.buttons["previous-page"].isEnabled })
        XCTAssertTrue(app.buttons["tile-test.app.0"].exists)
    }
    func testSettingsAndReturnToLauncher() {
        app.buttons["settings-button"].click()
        let settings = app.windows["Настройки — Return Launchpad"]
        XCTAssertTrue(settings.waitForExistence(timeout: 3))
        XCTAssertTrue(settings.staticTexts["Быстрый доступ"].exists)
        settings.buttons[XCUIIdentifierCloseWindow].click()
        XCTAssertTrue(app.textFields["app-search"].waitForExistence(timeout: 3))
    }
    func testBackgroundBesideSearchDismissesButControlsDoNot() {
        let search = app.textFields["app-search"]
        search.click()
        XCTAssertTrue(search.isHittable)
        app.buttons["next-page"].click()
        XCTAssertTrue(app.buttons["previous-page"].isEnabled)
        XCTAssertTrue(search.isHittable)
        search.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
            .withOffset(CGVector(dx: -120, dy: 0)).click()
        XCTAssertTrue(waitUntil { !search.isHittable })
        XCTAssertNotEqual(app.state, .notRunning)
    }

    func testHideAndReopenKeepsProcess() {
        XCTAssertNotEqual(app.state, .notRunning)
        app.buttons["hide-button"].click()
        app.activate()
        // The menu remains available while the overlay is hidden.
        app.menuBarItems["Return Launchpad"].click()
        app.menuItems["Настройки…"].firstMatch.click()
        XCTAssertTrue(app.windows["Настройки — Return Launchpad"].waitForExistence(timeout: 3))
        XCTAssertNotEqual(app.state, .notRunning)
    }
    private func waitUntil(_ condition: @escaping () -> Bool) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        return XCTWaiter.wait(for: [expectation], timeout: 4) == .completed
    }

    private func undoLayout() {
        app.activate()
        app.buttons["Отменить изменение"].click()
        app.activate()
    }

    private func pasteIntoFocusedField(_ text: String) {
        // Preserve the clipboard while exercising the keyboard shortcut; the menu is hidden.
        let pasteboard = NSPasteboard.general
        let previous = (pasteboard.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        defer { pasteboard.clearContents(); pasteboard.writeObjects(previous) }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        app.typeKey("v", modifierFlags: .command)
    }

    func testDropOnHeaderCancelsAndAllowsNextDrag() {
        let first = app.buttons["tile-test.app.0"]
        let second = app.buttons["tile-test.app.25"]
        first.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).press(forDuration: 0.15,
            thenDragTo: app.windows["Return Launchpad"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.03)))
        XCTAssertLessThan(first.frame.minX, second.frame.minX)
        first.press(forDuration: 0.15, thenDragTo: second, withVelocity: .slow, thenHoldForDuration: 0.85)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-folder:")).firstMatch.waitForExistence(timeout: 3))
    }

    func testFolderSurvivesProcessRestart() {
        app.buttons["tile-test.app.0"].press(forDuration: 0.15, thenDragTo: app.buttons["tile-test.app.25"], withVelocity: .slow, thenHoldForDuration: 0.85)
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tile-folder:"))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 3))
        let id = query.firstMatch.identifier
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons[id].waitForExistence(timeout: 5))
        app.buttons[id].click()
        XCTAssertTrue(app.buttons["tile-test.app.0"].exists)
        XCTAssertTrue(app.buttons["tile-test.app.25"].exists)
    }
}
