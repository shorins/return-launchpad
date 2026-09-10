import XCTest

@MainActor
final class Return_LaunchpadUITestsLaunchTests: XCTestCase {
    func testLaunchScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--test-run", UUID().uuidString]
        app.launch()
        app.activate()
        XCTAssertTrue(app.textFields["app-search"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launchpad — isolated test catalog"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.terminate()
    }
    func testLaunchPerformance() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--test-run", UUID().uuidString]
        let options = XCTMeasureOptions(); options.iterationCount = 3
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) { app.launch() }
        app.terminate()
    }
}
