import AppKit
import SwiftUI
import OSLog

@MainActor
final class AppManager: ObservableObject {
    @Published private(set) var apps: [AppInfo] = []
    @Published private(set) var layout = LayoutDocument()
    @Published private(set) var drag: DragSessionManager?
    @Published private(set) var isLoading = true
    @Published var searchText = "" { didSet { if searchText != oldValue { currentPage = 0; cancelDrag(); selectedID = isSearching ? visibleIDs.first : nil } } }
    @Published var currentPage = 0
    @Published var folderID: String? { didSet { if oldValue != folderID { currentPage = 0; selectedID = nil } } }
    @Published var selectedID: String?
    @Published var errorMessage: String?
    @Published var catalogIssues: [String] = []
    @Published var presentationID = UUID()
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var folderCandidate: String?
    var onDismiss: (() -> Void)?
    var onSettings: (() -> Void)?
    var onDragCancel: (() -> Void)?
    var itemsPerPage = 35
    var columnCount = 7
    private var appByID: [String: AppInfo] = [:]
    private var undoHistory: [LayoutDocument] = []
    private var redoHistory: [LayoutDocument] = []
    private let persistence: LayoutPersistence
    private let cacheURL: URL
    private var storageWritable = true
    private var scanTask: Task<Void, Never>?
    private var lastScan = Date.distantPast
    private let testing: Bool
    private var applicationDirectories: ApplicationDirectories?
    private let log = Logger(subsystem: "shorins.Return-Launchpad", category: "Catalog")
    private let signposter = OSSignposter(subsystem: "shorins.Return-Launchpad", category: "Performance")

    var displayedLayout: LayoutDocument { drag?.preview ?? layout }
    var currentContainer: LayoutContainer { folderID.map(LayoutContainer.folder) ?? .root }
    var isSearching: Bool { !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var currentFolder: LauncherFolder? { folderID.flatMap { layout.folder($0) } }
    var visibleIDs: [String] {
        if isSearching {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return apps.filter { $0.name.localizedStandardContains(query) }.map(\.id)
        }
        return displayedLayout.items(in: currentContainer).filter { appByID[$0] != nil || displayedLayout.folder($0) != nil }
    }
    var pageCount: Int { max(1, (visibleIDs.count + itemsPerPage - 1) / itemsPerPage) }
    var pageIDs: [String] {
        let ids = visibleIDs
        let start = min(max(0, currentPage) * itemsPerPage, ids.count)
        return Array(ids[start..<min(start + itemsPerPage, ids.count)])
    }

    init(directory: URL? = nil, legacyDefaults: [UserDefaults]? = nil, testing: Bool = false) {
        self.testing = testing
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Return Launchpad", isDirectory: true)
        persistence = LayoutPersistence(fileURL: base.appendingPathComponent("layout-v2.json"))
        cacheURL = base.appendingPathComponent("catalog-v2.json")
        do {
            let legacy = legacyDefaults ?? [UserDefaults.standard]
            layout = try persistence.load(legacyDefaults: legacy)
        } catch {
            storageWritable = false
            errorMessage = L10n.format("Could not load the layout: %@ New changes will not be saved.", error.localizedDescription)
        }
        if testing {
            apps = Self.demoApps
            appByID = Dictionary(uniqueKeysWithValues: apps.map { ($0.id, $0) })
            layout.reconcile(apps)
            isLoading = false
        } else {
            applicationDirectories = ApplicationDirectories()
            loadCatalog()
        }
    }

    private func loadCatalog() {
        let url = cacheURL
        scanTask = Task { [weak self] in
            let cached = await Task.detached(priority: .userInitiated) {
                guard let data = try? Data(contentsOf: url) else { return nil as CatalogSnapshot? }
                return try? JSONDecoder().decode(CatalogSnapshot.self, from: data)
            }.value
            guard let self, !Task.isCancelled else { return }
            if let cached { self.applyCatalog(cached.apps); self.isLoading = false }
            self.scanTask = nil
            self.rescanApps()
        }
    }

    func rescanIfNeeded() { if Date().timeIntervalSince(lastScan) > 60 { rescanApps() } }
    func chooseApplicationsDirectory() {
        guard !testing else { return }
        let panel = NSOpenPanel()
        panel.title = L10n.text("Application folder")
        panel.message = L10n.text("Allow access to your Applications folder or choose another folder containing apps.")
        panel.prompt = L10n.text("Add folder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = AppScanner.userApplicationsDirectory
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                try self.applicationDirectories?.add(url)
                self.rescanApps()
            } catch { self.errorMessage = L10n.format("Could not add the folder: %@", error.localizedDescription) }
        }
    }
    func rescanApps() {
        guard !testing, scanTask == nil, drag == nil else { return }
        isLoading = apps.isEmpty
        let finder = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder")
        let roots = AppScanner.defaultRoots + (applicationDirectories?.urls ?? [])
        let accessIssues = applicationDirectories?.issues ?? []
        let scanner = AppScanner(roots: roots, excludedBundleID: Bundle.main.bundleIdentifier, supplementalURLs: [finder].compactMap { $0 })
        let interval = signposter.beginInterval("catalog.scan")
        scanTask = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) { scanner.scan() }.value
            guard let self, !Task.isCancelled else { return }
            // Do not change a drag's source snapshot while an asynchronous scan finishes.
            if self.drag == nil {
                if result.issues.isEmpty { self.applyCatalog(result.apps) }
                else {
                    let merged = Dictionary((self.apps + result.apps).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
                    self.applyCatalog(Array(merged.values).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
                }
            }
            self.catalogIssues = accessIssues + result.issues
            self.isLoading = false
            self.lastScan = Date()
            self.scanTask = nil
            self.signposter.endInterval("catalog.scan", interval)
            self.log.info("Catalog ready: \(result.apps.count) apps; \(result.issues.count) source errors")
            let snapshot = CatalogSnapshot(apps: self.apps)
            let cache = self.cacheURL
            Task.detached(priority: .utility) {
                do {
                    try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try JSONEncoder().encode(snapshot).write(to: cache, options: .atomic)
                } catch { /* A cache failure must not prevent launching apps. */ }
            }
        }
    }

    private func applyCatalog(_ result: [AppInfo]) {
        let unique = Dictionary(result.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        apps = unique.values.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        appByID = unique
        if !testing { IconCache.shared.preload(apps) }
        var next = layout
        next.reconcile(apps)
        if next != layout { layout = next; save() }
        clampPage()
    }

    func app(_ id: String) -> AppInfo? { appByID[id] }
    func title(_ id: String) -> String { displayedLayout.folder(id)?.name ?? appByID[id]?.name ?? L10n.text("Unavailable") }
    func parentFolderName(_ id: String) -> String? { layout.folders.first { $0.appIDs.contains(id) }?.name }
    func configureGrid(columns: Int, capacity: Int) {
        columnCount = max(1, columns)
        let next = max(1, capacity)
        if itemsPerPage != next { itemsPerPage = next; clampPage() }
    }
    func clampPage() { currentPage = max(0, min(currentPage, pageCount - 1)) }
    func changePage(_ delta: Int) {
        let next = max(0, min(currentPage + delta, pageCount - 1))
        if next != currentPage { currentPage = next; selectedID = nil; folderCandidate = nil }
    }
    func handleArrow(_ offset: Int) {
        if isSearching { navigate(offset) }
        else { changePage(offset < 0 ? -1 : 1) }
    }
    func navigate(_ offset: Int) {
        let ids = visibleIDs
        guard !ids.isEmpty else { return }
        guard let index = selectedID.flatMap({ ids.firstIndex(of: $0) }) else {
            selectedID = ids[0]
            currentPage = 0
            return
        }
        let next = max(0, min(index + offset, ids.count - 1))
        selectedID = ids[next]
        currentPage = next / itemsPerPage
    }
    func activateSelection() { if let id = selectedID ?? pageIDs.first { activate(id) } }
    func activate(_ id: String) {
        guard drag == nil else { return }
        if layout.folder(id) != nil { folderID = id; return }
        guard let app = appByID[id] else { return }
        if testing { errorMessage = L10n.format("Test launch: %@", app.name); return }
        NSWorkspace.shared.openApplication(at: app.url, configuration: .init()) { [weak self] _, error in
            Task { @MainActor in
                if let error { self?.errorMessage = L10n.format("Could not open the app: %@", error.localizedDescription) }
                else { self?.onDismiss?() }
            }
        }
    }
    func dismissBackground() {
        guard drag == nil else { return }
        if folderID != nil { folderID = nil }
        else { onDismiss?() }
    }
    func escape() {
        if drag != nil { onDragCancel?(); cancelDrag() }
        else if isSearching { searchText = "" }
        else if folderID != nil { folderID = nil }
        else { onDismiss?() }
    }

    func beginDrag(_ id: String) -> String? {
        guard !isSearching, drag == nil else { return nil }
        drag = DragSessionManager(itemID: id, document: layout)
        selectedID = nil
        return drag?.sessionID
    }
    func previewMove(before id: String?) {
        guard var session = drag else { return }
        session.previewMove(to: currentContainer, before: id)
        if session.preview != drag?.preview { drag = session }
    }
    func previewMoveToPageEdge(forward: Bool) {
        guard let session = drag else { return }
        let ids = session.original.items(in: currentContainer).filter {
            $0 != session.itemID && (appByID[$0] != nil || session.original.folder($0) != nil)
        }
        let position = forward ? currentPage * itemsPerPage : min((currentPage + 1) * itemsPerPage - 1, ids.count)
        previewMove(before: position < ids.count ? ids[max(0, position)] : nil)
    }
    func commitDrag(folderTarget: String? = nil) {
        guard var session = drag else { return }
        if let folderTarget { session.previewFolder(on: folderTarget) }
        drag = nil
        folderCandidate = nil
        commit(session.preview)
        if let folderID, layout.folder(folderID) == nil { self.folderID = nil }
        clampPage()
    }
    func cancelDrag() {
        drag = nil
        folderCandidate = nil
        clampPage()
    }
    func moveItem(_ id: String, to container: LayoutContainer, before anchor: String? = nil) {
        var next = layout
        if next.move(id, to: container, before: anchor) { commit(next) }
        if let folderID, layout.folder(folderID) == nil { self.folderID = nil }
        clampPage()
    }
    func renameFolder(_ id: String, name: String) { var next = layout; next.renameFolder(id, name: name); commit(next) }
    func dissolveFolder(_ id: String) { var next = layout; next.dissolveFolder(id); commit(next); if folderID == id { folderID = nil } }
    func alphabetize() { var next = layout; next.sortAlphabetically(apps); commit(next) }
    func createFolder(_ source: String, with target: String) { var next = layout; if next.createFolder(source: source, target: target) != nil { commit(next) } }

    private func commit(_ next: LayoutDocument) {
        guard next != layout, next.isValid else { return }
        undoHistory.append(layout)
        if undoHistory.count > 50 { undoHistory.removeFirst() }
        redoHistory.removeAll()
        layout = next
        updateUndoState()
        save()
    }
    func undo() {
        cancelDrag()
        guard let previous = undoHistory.popLast() else { return }
        redoHistory.append(layout); layout = previous; updateUndoState(); save(); repairNavigation()
    }
    func redo() {
        cancelDrag()
        guard let next = redoHistory.popLast() else { return }
        undoHistory.append(layout); layout = next; updateUndoState(); save(); repairNavigation()
    }
    private func repairNavigation() {
        if let folderID, layout.folder(folderID) == nil { self.folderID = nil }
        clampPage()
    }
    private func updateUndoState() { canUndo = !undoHistory.isEmpty; canRedo = !redoHistory.isEmpty }
    private func save() {
        guard storageWritable else { return }
        persistence.save(layout) { [weak self] message in
            if let message { Task { @MainActor in self?.errorMessage = L10n.format("Could not save the layout: %@", message) } }
        }
    }
    func flush() { persistence.flush() }

    static var demoApps: [AppInfo] {
        let names = ["Calculator", "Calendar", "Contacts", "Dictionary", "FaceTime", "Finder", "Freeform", "Home", "Mail", "Maps", "Messages", "Music", "Notes", "Numbers", "Pages", "Photos", "Preview", "Reminders", "Safari", "Shortcuts", "System Settings", "Terminal", "TextEdit", "TV", "Voice Memos"]
        return (0..<90).map { index in
            let name = names[index % names.count] + (index >= names.count ? " \(index / names.count + 1)" : "")
            return AppInfo(name: name, url: URL(fileURLWithPath: "/System/Applications/\(names[index % names.count]).app"), bundleIdentifier: "test.app.\(index)")
        }
    }
}
