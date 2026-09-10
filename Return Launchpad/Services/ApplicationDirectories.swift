import AppKit

/// Explicitly selected directories retain read access across sandboxed launches.
@MainActor
final class ApplicationDirectories {
    private let defaults: UserDefaults
    private let key = "applicationDirectoryBookmarks.v1"
    private(set) var urls: [URL] = []
    private(set) var issues: [String] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var refreshed: [Data] = []
        for data in defaults.array(forKey: key) as? [Data] ?? [] {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope, .withoutUI], bookmarkDataIsStale: &stale)
                guard url.startAccessingSecurityScopedResource() else {
                    issues.append("Снова выберите папку \(url.lastPathComponent), чтобы разрешить чтение.")
                    refreshed.append(data)
                    continue
                }
                urls.append(url)
                refreshed.append(stale ? (try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])) : data)
            } catch {
                refreshed.append(data)
                issues.append("Не удалось восстановить доступ к папке приложений: \(error.localizedDescription)")
            }
        }
        defaults.set(refreshed, forKey: key)
    }

    func add(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
            var bookmarks = defaults.array(forKey: key) as? [Data] ?? []
            if !urls.contains(where: { $0.standardizedFileURL == url.standardizedFileURL }) {
                urls.append(url)
                bookmarks.append(data)
                defaults.set(bookmarks, forKey: key)
            } else if accessing { url.stopAccessingSecurityScopedResource() }
            issues = []
        } catch {
            if accessing { url.stopAccessingSecurityScopedResource() }
            throw error
        }
    }
}
