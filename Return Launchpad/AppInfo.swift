import Foundation

/// Metadata only: decoding the catalog never decodes an icon or creates AppKit objects.
struct AppInfo: Identifiable, Hashable, Codable, Sendable {
    let name: String
    let url: URL
    let bundleIdentifier: String
    var modificationDate: Date = .distantPast
    var iconRevision: String? = nil
    var id: String { bundleIdentifier }
    var iconKey: String { "\(url.path)|\(modificationDate.timeIntervalSince1970)|\(iconRevision ?? "")" }
}
