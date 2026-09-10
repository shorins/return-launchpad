import AppKit
import CryptoKit
import ImageIO
import UniformTypeIdentifiers

/// Decoded icons stay resident for the current catalog. PNG files survive relaunches.
@MainActor
final class IconCache {
    static let shared = IconCache()
    private var images: [String: NSImage] = [:]
    private var waiting: [String: [(NSImage) -> Void]] = [:]
    private var requested = Set<String>()
    private var catalogKeys = Set<String>()
    private var pending: [AppInfo] = []
    private var scheduled = false
    private var resumeAt = Date.distantPast
    private let disk = DispatchQueue(label: "Launchpad.IconDisk", qos: .utility)
    private let directory: URL
    private static let pixels = 192

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Return Launchpad/Icons-v1", isDirectory: true)
    }

    nonisolated static func filename(for app: AppInfo) -> String {
        SHA256.hash(data: Data(("192-v1|" + app.iconKey).utf8)).map { String(format: "%02x", $0) }.joined() + ".png"
    }

    func preload(_ apps: [AppInfo]) {
        let valid = Set(apps.map(\.iconKey))
        guard valid != catalogKeys else { return }
        catalogKeys = valid
        images = images.filter { valid.contains($0.key) }
        let files = Set(apps.map { Self.filename(for: $0) })
        let directory = directory
        disk.async {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
                where url.pathExtension == "png" && !files.contains(url.lastPathComponent) {
                try? FileManager.default.removeItem(at: url)
            }
        }
        // All pages, not just the visible one. Visible requests can promote cold jobs.
        for app in apps { request(app) }
    }

    func image(for app: AppInfo, completion: @escaping (NSImage) -> Void) {
        if let image = images[app.iconKey] { completion(image); return }
        waiting[app.iconKey, default: []].append(completion)
        if let index = pending.firstIndex(where: { $0.iconKey == app.iconKey }) {
            pending.insert(pending.remove(at: index), at: 0)
        }
        request(app)
    }

    func pauseExtraction(for duration: TimeInterval) {
        resumeAt = Date().addingTimeInterval(duration)
    }

    private func request(_ app: AppInfo) {
        guard images[app.iconKey] == nil, requested.insert(app.iconKey).inserted else { return }
        let file = directory.appendingPathComponent(Self.filename(for: app))
        disk.async { [weak self] in
            let decoded: CGImage? = autoreleasepool {
                guard FileManager.default.fileExists(atPath: file.path) else { return nil }
                guard let source = CGImageSourceCreateWithURL(file as CFURL, nil) else { return nil }
                return CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary)
            }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if let decoded { self.finish(app, image: NSImage(cgImage: decoded, size: NSSize(width: 96, height: 96))) }
                else {
                    if self.waiting[app.iconKey] != nil { self.pending.insert(app, at: 0) }
                    else { self.pending.append(app) }
                    self.scheduleNext()
                }
            }
        }
    }

    private func finish(_ app: AppInfo, image: NSImage) {
        images[app.iconKey] = image
        requested.remove(app.iconKey)
        let callbacks = waiting.removeValue(forKey: app.iconKey) ?? []
        callbacks.forEach { $0(image) }
    }

    private func scheduleNext() {
        guard !scheduled, !pending.isEmpty else { return }
        scheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + max(0.012, resumeAt.timeIntervalSinceNow)) { [weak self] in
            guard let self else { return }
            self.scheduled = false
            guard Date() >= self.resumeAt else { self.scheduleNext(); return }
            guard !self.pending.isEmpty else { return }
            let app = self.pending.removeFirst()
            let image = Self.rasterized(NSWorkspace.shared.icon(forFile: app.url.path))
            self.finish(app, image: image)
            if let bitmap = image.representations.first as? NSBitmapImageRep, let cgImage = bitmap.cgImage {
                let file = self.directory.appendingPathComponent(Self.filename(for: app))
                self.disk.async {
                    let data = NSMutableData()
                    if let target = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) {
                        CGImageDestinationAddImage(target, cgImage, nil)
                        if CGImageDestinationFinalize(target) {
                            try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try? (data as Data).write(to: file, options: .atomic)
                        }
                    }
                }
            }
            self.scheduleNext()
        }
    }

    private static func rasterized(_ source: NSImage) -> NSImage {
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return source }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        source.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        bitmap.size = NSSize(width: 96, height: 96)
        let result = NSImage(size: bitmap.size)
        result.addRepresentation(bitmap)
        return result
    }
}
