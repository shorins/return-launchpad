//
//  AppOrderManagerTests.swift
//  Return LaunchpadTests
//
//  Created for professional testing of persistence functionality
//

import XCTest
@testable import Return_Launchpad

class AppOrderManagerTests: XCTestCase {
    
    var appOrderManager: AppOrderManager!
    var testApps: [AppInfo]!
    
    override func setUpWithError() throws {
        try super.setUpWithError()
        
        // Create test instance
        appOrderManager = AppOrderManager()
        
        // Create mock apps for testing
        testApps = createMockApps()
        
        // Clear any existing test data
        clearTestData()
    }
    
    override func tearDownWithError() throws {
        // Clean up test data
        clearTestData()
        appOrderManager = nil
        testApps = nil
        try super.tearDownWithError()
    }
    
    // MARK: - Helper Methods
    
    func createMockApps() -> [AppInfo] {
        let mockApps = [
            AppInfo(name: "App A", icon: NSImage(), url: URL(fileURLWithPath: "/Applications/AppA.app"), bundleIdentifier: "com.test.appa"),
            AppInfo(name: "App B", icon: NSImage(), url: URL(fileURLWithPath: "/Applications/AppB.app"), bundleIdentifier: "com.test.appb"),
            AppInfo(name: "App C", icon: NSImage(), url: URL(fileURLWithPath: "/Applications/AppC.app"), bundleIdentifier: "com.test.appc"),
            AppInfo(name: "App D", icon: NSImage(), url: URL(fileURLWithPath: "/Applications/AppD.app"), bundleIdentifier: "com.test.appd"),
            AppInfo(name: "App E", icon: NSImage(), url: URL(fileURLWithPath: "/Applications/AppE.app"), bundleIdentifier: "com.test.appe")
        ]
        return mockApps
    }
    
    func clearTestData() {
        let testUser = NSUserName()
        let keys = [
            "\(testUser)_isCustomOrderEnabled",
            "\(testUser)_userAppOrder"
        ]
        
        // Clear from both standard and app group UserDefaults
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
            UserDefaults(suiteName: "group.shorins.return-launchpad")?.removeObject(forKey: key)
        }
        
        UserDefaults.standard.synchronize()
        UserDefaults(suiteName: "group.shorins.return-launchpad")?.synchronize()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Test that new AppOrderManager starts in alphabetical mode
        XCTAssertFalse(appOrderManager.isCustomOrderEnabled, "Should start in alphabetical mode")
        
        let verification = appOrderManager.verifyInitialization()
        XCTAssertFalse(verification.customOrderEnabled, "Custom order should be disabled initially")
        XCTAssertEqual(verification.savedItemsCount, 0, "Should have no saved items initially")
    }
    
    func testAlphabeticalSorting() {
        // Test that apps are sorted alphabetically by default
        let unsortedApps = [testApps[2], testApps[0], testApps[4], testApps[1], testApps[3]] // C, A, E, B, D
        let sortedApps = appOrderManager.sortApps(unsortedApps)
        
        let expectedOrder = ["App A", "App B", "App C", "App D", "App E"]
        let actualOrder = sortedApps.map { $0.name }
        
        XCTAssertEqual(actualOrder, expectedOrder, "Apps should be sorted alphabetically")
    }
    
    // MARK: - Custom Order Tests
    
    func testEnableCustomOrder() {
        // Test enabling custom order
        XCTAssertFalse(appOrderManager.isCustomOrderEnabled)
        
        appOrderManager.enableCustomOrder()
        
        XCTAssertTrue(appOrderManager.isCustomOrderEnabled, "Custom order should be enabled")
    }
    
    func testEnableCustomOrderWithPositions() {
        // Test enabling custom order with current positions
        appOrderManager.enableCustomOrderWithCurrentPositions(testApps)
        
        XCTAssertTrue(appOrderManager.isCustomOrderEnabled, "Custom order should be enabled")
        
        let verification = appOrderManager.verifyInitialization()
        XCTAssertEqual(verification.savedItemsCount, testApps.count, "Should save all app positions")
    }
    
    // MARK: - Drag & Drop Tests
    
    func testMoveAppEnablesCustomOrder() {
        // Test that moving an app automatically enables custom order
        XCTAssertFalse(appOrderManager.isCustomOrderEnabled)
        
        let reorderedApps = appOrderManager.moveApp(from: 0, to: 2, in: testApps)
        
        XCTAssertTrue(appOrderManager.isCustomOrderEnabled, "Moving app should enable custom order")
        XCTAssertEqual(reorderedApps.count, testApps.count, "Should maintain same number of apps")
    }
    
    func testMoveAppChangesOrder() {
        // Test that moving an app actually changes the order
        let originalOrder = testApps.map { $0.name }
        let reorderedApps = appOrderManager.moveApp(from: 0, to: 2, in: testApps)
        let newOrder = reorderedApps.map { $0.name }
        
        XCTAssertNotEqual(originalOrder, newOrder, "Order should change after moving app")
        
        // Verify specific move: App A (index 0) should now be at index 2
        XCTAssertEqual(reorderedApps[2].name, "App A", "App A should be at index 2 after move")
    }
    
    // MARK: - Persistence Tests
    
    func testPersistenceAfterRestart() {
        // Test that custom order persists after "restart" (new instance)
        
        // Set up custom order
        appOrderManager.enableCustomOrderWithCurrentPositions(testApps)
        let originalOrder = testApps.map { $0.bundleIdentifier }
        
        // Move an app to create custom order
        _ = appOrderManager.moveApp(from: 0, to: 2, in: testApps)
        
        // Force save
        appOrderManager.forceSave()
        
        // Create new instance (simulating app restart)
        let newAppOrderManager = AppOrderManager()
        
        // Check that custom order is restored
        XCTAssertTrue(newAppOrderManager.isCustomOrderEnabled, "Custom order should persist after restart")
        
        let verification = newAppOrderManager.verifyInitialization()
        XCTAssertTrue(verification.customOrderEnabled, "Custom order should be enabled after restart")
        XCTAssertGreaterThan(verification.savedItemsCount, 0, "Should have saved items after restart")
    }
    
    func testResetToAlphabetical() {
        // Test resetting to alphabetical order
        appOrderManager.enableCustomOrderWithCurrentPositions(testApps)
        XCTAssertTrue(appOrderManager.isCustomOrderEnabled)
        
        appOrderManager.resetToAlphabetical()
        
        XCTAssertFalse(appOrderManager.isCustomOrderEnabled, "Should reset to alphabetical mode")
        
        let verification = appOrderManager.verifyInitialization()
        XCTAssertEqual(verification.savedItemsCount, 0, "Should clear saved items")
    }
    
    // MARK: - Data Validation Tests
    
    func testDataValidation() {
        // Test data validation functionality
        appOrderManager.enableCustomOrderWithCurrentPositions(testApps)
        
        let verification = appOrderManager.verifyInitialization()
        XCTAssertTrue(verification.customOrderEnabled, "Should validate correct data")
    }
    
    // MARK: - Performance Tests
    
    func testPerformanceSortLargeNumberOfApps() {
        // Test performance with large number of apps
        let largeAppList = Array(repeating: testApps, count: 100).flatMap { $0 }
        
        measure {
            _ = appOrderManager.sortApps(largeAppList)
        }
    }
    
    func testPerformanceMoveAppWithLargeList() {
        // Test performance of moving apps with large list
        let largeAppList = Array(repeating: testApps, count: 100).flatMap { $0 }
        
        measure {
            _ = appOrderManager.moveApp(from: 0, to: 50, in: largeAppList)
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyAppList() {
        // Test behavior with empty app list
        let emptyList: [AppInfo] = []
        let result = appOrderManager.sortApps(emptyList)
        
        XCTAssertEqual(result.count, 0, "Should handle empty list gracefully")
    }
    
    func testSingleApp() {
        // Test behavior with single app
        let singleApp = [testApps[0]]
        let result = appOrderManager.sortApps(singleApp)
        
        XCTAssertEqual(result.count, 1, "Should handle single app correctly")
        XCTAssertEqual(result[0].name, testApps[0].name, "Should maintain app identity")
    }
    
    func testInvalidMoveIndices() {
        // Test behavior with invalid move indices
        let result = appOrderManager.moveApp(from: -1, to: 10, in: testApps)
        
        // Should handle gracefully and not crash
        XCTAssertNotNil(result, "Should not crash with invalid indices")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() {
        // Test complete workflow: alphabetical -> custom -> move -> restart -> verify
        
        // 1. Start with alphabetical
        XCTAssertFalse(appOrderManager.isCustomOrderEnabled)
        
        // 2. Enable custom order
        appOrderManager.enableCustomOrderWithCurrentPositions(testApps)
        XCTAssertTrue(appOrderManager.isCustomOrderEnabled)
        
        // 3. Move an app
        let reorderedApps = appOrderManager.moveApp(from: 0, to: 2, in: testApps)
        
        // 4. Force save
        appOrderManager.forceSave()
        
        // 5. Simulate restart
        let newManager = AppOrderManager()
        
        // 6. Verify persistence
        XCTAssertTrue(newManager.isCustomOrderEnabled, "Custom order should persist through restart")
        
        let verification = newManager.verifyInitialization()
        XCTAssertGreaterThan(verification.savedItemsCount, 0, "Should have saved data after restart")
    }
}