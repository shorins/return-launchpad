import XCTest
import AppKit
@testable import Return_Launchpad

@MainActor
final class IconCacheTests: XCTestCase {
    func testPersistedIconLoadsAfterCacheIsRecreated() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppInfo(name: "Fixture", url: URL(fileURLWithPath: "/nonexistent/Fixture.app"), bundleIdentifier: "fixture")
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        for x in 0..<2 { for y in 0..<2 { bitmap.setColor(NSColor(deviceRed: 0, green: 1, blue: 0, alpha: 1), atX: x, y: y) } }
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: directory.appendingPathComponent(IconCache.filename(for: app)))
        for _ in 0..<2 {
            let cache = IconCache(directory: directory)
            let loaded = expectation(description: "Persistent icon")
            cache.image(for: app) { image in
                let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
                let pixel = NSBitmapImageRep(cgImage: cg).colorAt(x: 0, y: 0)!.usingColorSpace(.deviceRGB)!
                XCTAssertGreaterThan(pixel.greenComponent, 0.9)
                XCTAssertLessThan(pixel.redComponent, 0.1)
                loaded.fulfill()
            }
            await fulfillment(of: [loaded], timeout: 2)
        }
    }

    func testIconResourceRevisionInvalidatesDiskKey() {
        var app = AppInfo(name: "Fixture", url: URL(fileURLWithPath: "/Fixture.app"), bundleIdentifier: "fixture")
        let old = IconCache.filename(for: app)
        app.iconRevision = "updated-resource"
        XCTAssertNotEqual(old, IconCache.filename(for: app))
    }
}
