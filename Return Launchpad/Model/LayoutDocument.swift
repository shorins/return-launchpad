import Foundation

struct LauncherFolder: Identifiable, Codable, Equatable, Sendable {
    var id: String = "folder:" + UUID().uuidString
    var name: String
    var appIDs: [String]
}

enum LayoutContainer: Equatable, Sendable {
    case root
    case folder(String)
}

/// Value transactions keep a drag preview separate from the persisted layout.
struct LayoutDocument: Codable, Equatable, Sendable {
    var schemaVersion = 2
    var rootItems: [String] = []
    var folders: [LauncherFolder] = []
    var isCustomized = false

    func folder(_ id: String) -> LauncherFolder? { folders.first { $0.id == id } }
    func items(in container: LayoutContainer) -> [String] {
        switch container {
        case .root: return rootItems
        case .folder(let id): return folder(id)?.appIDs ?? []
        }
    }
    var allAppIDs: [String] {
        let folderIDs = Set(folders.map(\.id))
        return rootItems.filter { !folderIDs.contains($0) } + folders.flatMap(\.appIDs)
    }
    var isValid: Bool {
        guard schemaVersion == 2,
              Set(rootItems).count == rootItems.count,
              Set(folders.map(\.id)).count == folders.count else { return false }
        let folderIDs = Set(folders.map(\.id))
        guard folderIDs.isSubset(of: Set(rootItems)),
              folders.allSatisfy({ !$0.appIDs.isEmpty && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              folders.allSatisfy({ Set($0.appIDs).isDisjoint(with: folderIDs) }) else { return false }
        return Set(allAppIDs).count == allAppIDs.count
    }

    mutating func reconcile(_ apps: [AppInfo]) {
        let known = Set(allAppIDs)
        let added = apps.filter { !known.contains($0.id) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        rootItems.append(contentsOf: added.map(\.id))
        if !isCustomized && folders.isEmpty {
            let names = Dictionary(apps.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
            rootItems.sort { (names[$0] ?? $0).localizedStandardCompare(names[$1] ?? $1) == .orderedAscending }
        }
        // Missing apps stay in the document: an unreadable volume must not destroy folders.
    }

    @discardableResult
    mutating func move(_ id: String, to container: LayoutContainer, before anchor: String?) -> Bool {
        guard rootItems.contains(id) || folders.contains(where: { $0.appIDs.contains(id) }) else { return false }
        if anchor == id { return false }
        if let anchor, !items(in: container).contains(anchor) { return false }
        if case .folder(let folderID) = container {
            guard folder(folderID) != nil, folder(id) == nil else { return false }
        }
        let original = self
        removeReference(id)
        switch container {
        case .root:
            let index = anchor.flatMap { rootItems.firstIndex(of: $0) } ?? rootItems.count
            rootItems.insert(id, at: index)
        case .folder(let folderID):
            guard let index = folders.firstIndex(where: { $0.id == folderID }) else { self = original; return false }
            let position = anchor.flatMap { folders[index].appIDs.firstIndex(of: $0) } ?? folders[index].appIDs.count
            folders[index].appIDs.insert(id, at: position)
        }
        removeEmptyFolders()
        guard rootItems != original.rootItems || folders != original.folders else { self = original; return false }
        isCustomized = true
        return true
    }

    @discardableResult
    mutating func createFolder(source: String, target: String, name: String = L10n.text("New folder")) -> String? {
        guard source != target, folder(source) == nil, folder(target) == nil,
              rootItems.contains(target), allAppIDs.contains(source) else { return nil }
        removeReference(source)
        guard let index = rootItems.firstIndex(of: target) else { return nil }
        let folder = LauncherFolder(name: name, appIDs: [target, source])
        rootItems[index] = folder.id
        folders.append(folder)
        removeEmptyFolders()
        isCustomized = true
        return folder.id
    }

    mutating func renameFolder(_ id: String, name: String) {
        let trimmed = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        guard !trimmed.isEmpty, let index = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[index].name = trimmed
    }

    mutating func dissolveFolder(_ id: String) {
        guard let folder = folder(id), let index = rootItems.firstIndex(of: id) else { return }
        rootItems.replaceSubrange(index...index, with: folder.appIDs)
        folders.removeAll { $0.id == id }
        isCustomized = true
    }

    mutating func sortAlphabetically(_ apps: [AppInfo]) {
        let names = Dictionary(apps.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let folderNames = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0.name) })
        rootItems.sort { (folderNames[$0] ?? names[$0] ?? $0).localizedStandardCompare(folderNames[$1] ?? names[$1] ?? $1) == .orderedAscending }
        isCustomized = true
    }

    private mutating func removeReference(_ id: String) {
        rootItems.removeAll { $0 == id }
        for index in folders.indices { folders[index].appIDs.removeAll { $0 == id } }
    }

    private mutating func removeEmptyFolders() {
        let empty = Set(folders.filter { $0.appIDs.isEmpty }.map(\.id))
        rootItems.removeAll { empty.contains($0) }
        folders.removeAll { empty.contains($0.id) }
    }
}
