import Foundation
import Darwin

struct CatalogSnapshot: Codable, Sendable {
    var apps: [AppInfo]
    var scannedAt: Date = Date()
}
struct ScanResult: Sendable {
    var apps: [AppInfo]
    var issues: [String]
}
struct AppScanner: Sendable {
    var roots: [URL]
    var excludedBundleID: String?
    var supplementalURLs: [URL] = []

    static var defaultRoots: [URL] {
        [URL(fileURLWithPath: "/Applications"),
         userApplicationsDirectory,
         URL(fileURLWithPath: "/System/Applications"),
         URL(fileURLWithPath: "/System/Library/CoreServices/Applications")]
    }

    // Foundation's home-directory functions resolve to the app container in a sandbox.
    // This is only path discovery; normal filesystem permissions still apply.
    static var userApplicationsDirectory: URL {
        var entry = passwd()
        var resolved: UnsafeMutablePointer<passwd>?
        var buffer = [CChar](repeating: 0, count: 16_384)
        let home = buffer.withUnsafeMutableBufferPointer { bytes -> String? in
            guard getpwuid_r(getuid(), &entry, bytes.baseAddress!, bytes.count, &resolved) == 0,
                  resolved != nil, let path = entry.pw_dir else { return nil }
            return String(cString: path)
        }
        return URL(fileURLWithPath: home ?? NSHomeDirectory()).appendingPathComponent("Applications")
    }

    func scan() -> ScanResult {
        var result = ScanResult(apps: [], issues: [])
        var known = Set<String>()
        var paths = Set<String>()
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .contentModificationDateKey]
        func inspect(_ url: URL) {
            let canonical = url.resolvingSymlinksInPath().standardizedFileURL
            guard paths.insert(canonical.path).inserted, let bundle = Bundle(url: canonical) else { return }
            let identifier = bundle.bundleIdentifier ?? "path:" + canonical.path
            guard identifier != excludedBundleID,
                  (bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool) != true,
                  (bundle.object(forInfoDictionaryKey: "LSUIElement") as? Bool) != true,
                  known.insert(identifier).inserted else { return }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? canonical.deletingPathExtension().lastPathComponent
            let modified = (try? canonical.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let resources = canonical.appendingPathComponent("Contents/Resources")
            var iconFiles = [canonical.appendingPathComponent("Contents/Info.plist"), resources.appendingPathComponent("Assets.car")]
            if let file = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String {
                iconFiles.append(resources.appendingPathComponent(file))
                if (file as NSString).pathExtension.isEmpty { iconFiles.append(resources.appendingPathComponent(file + ".icns")) }
            }
            let stamps = iconFiles.map { url -> String in
                let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
                return "\(values?.contentModificationDate?.timeIntervalSince1970 ?? 0):\(values?.fileSize ?? 0)"
            }
            let revision = ([bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""] + stamps).joined(separator: "|")
            result.apps.append(AppInfo(name: name, url: canonical, bundleIdentifier: identifier, modificationDate: modified, iconRevision: revision))
        }
        for root in roots {
            guard FileManager.default.fileExists(atPath: root.path) else { continue }
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { url, error in
                    result.issues.append("\(url.lastPathComponent): \(error.localizedDescription)")
                    return true
                }) else {
                result.issues.append(L10n.format("Could not read %@", root.path))
                continue
            }
            var candidates: [URL] = []
            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "app" {
                    candidates.append(url)
                    enumerator.skipDescendants()
                } else if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
                    enumerator.skipDescendants()
                }
            }
            // The first configured root wins; duplicates inside it have a stable path order.
            candidates.sorted { $0.path < $1.path }.forEach(inspect)
        }
        supplementalURLs.forEach(inspect)
        result.apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return result
    }
}
