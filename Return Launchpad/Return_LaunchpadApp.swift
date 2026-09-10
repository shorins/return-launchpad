import SwiftUI
import AppKit
import KeyboardShortcuts
import OSLog

@main
struct LaunchpadApplication {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = LauncherAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}

final class LauncherWindow: NSWindow {
    var onBackgroundClick: (() -> Void)?
    var isInternalDragActive: (() -> Bool)?
    private var swallowedBackgroundClick = false

    func isInteractive(at point: NSPoint) -> Bool {
        guard let root = contentView else { return false }
        var hit = root.hitTest(root.superview?.convert(point, from: nil) ?? point)
        while let view = hit {
            if view is NSButton { return true }
            if let field = view as? NSTextField, field.isEditable || field.isSelectable { return true }
            if let editor = view as? NSTextView, editor.isEditable || editor.isSelectable { return true }
            hit = view.superview
        }
        func containsControlRegion(_ view: NSView) -> Bool {
            guard !view.isHidden, view.alphaValue > 0 else { return false }
            if view is LauncherInteractionRegionView,
               view.bounds.contains(view.convert(point, from: nil)) { return true }
            return view.subviews.contains { containsControlRegion($0) }
        }
        return containsControlRegion(root)
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseUp, swallowedBackgroundClick {
            swallowedBackgroundClick = false
            return
        }
        if event.type == .leftMouseDown {
            swallowedBackgroundClick = false
            if attachedSheet == nil, NSApp.modalWindow == nil, isInternalDragActive?() != true,
               !isInteractive(at: event.locationInWindow) {
                swallowedBackgroundClick = true
                onBackgroundClick?()
                return
            }
        }
        super.sendEvent(event)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class LauncherAppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var model: AppManager!
    private var preferences: LauncherPreferences!
    private var launcherWindow: LauncherWindow?
    private var settingsWindow: NSWindow?
    private var statusItem: NSStatusItem?
    private var keyMonitor: Any?
    private var presentationToken = UUID()
    private var isShowing = false
    private var savedPresentation: NSApplication.PresentationOptions?
    private var testing = false
    private let signposter = OSSignposter(subsystem: "shorins.Return-Launchpad", category: "Performance")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hosted unit tests must never read, migrate, or overwrite the user's layout.
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil { return }
        testing = ProcessInfo.processInfo.arguments.contains("--ui-testing")
        if testing {
            let arguments = ProcessInfo.processInfo.arguments
            let index = arguments.firstIndex(of: "--test-run")
            let runID = index.flatMap { arguments.indices.contains($0 + 1) ? UUID(uuidString: arguments[$0 + 1]) : nil } ?? UUID()
            let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("LaunchpadUITest-" + runID.uuidString)
            model = AppManager(directory: temporary, legacyDefaults: [], testing: true)
            preferences = LauncherPreferences(defaults: UserDefaults(suiteName: "LaunchpadUITest." + UUID().uuidString)!)
            // Desktop test tools can briefly activate their runner; keep the fixture visible.
            preferences.hideOnDeactivate = false
        } else {
            model = AppManager()
            preferences = LauncherPreferences()
        }
        model.onDismiss = { [weak self] in self?.hideLauncher() }
        model.onSettings = { [weak self] in self?.showSettings() }
        setupMenus()
        setupWindow()
        installKeyboardHandler()
        if !testing {
            KeyboardShortcuts.onKeyUp(for: .toggleLaunchpad) { [weak self] in self?.toggleLauncher() }
        }
        showLauncher()
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showLauncher(); return false }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationDidBecomeActive(_ notification: Notification) {
        if isShowing { launcherWindow?.makeKeyAndOrderFront(nil) }
    }
    func applicationWillTerminate(_ notification: Notification) { restorePresentation(); model?.flush(); if let keyMonitor { NSEvent.removeMonitor(keyMonitor) } }
    func applicationDidResignActive(_ notification: Notification) {
        if preferences?.hideOnDeactivate == true { hideLauncher() }
    }

    private func setupWindow() {
        let window = LauncherWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        window.onBackgroundClick = { [weak self] in self?.model.dismissBackground() }
        window.isInternalDragActive = { [weak self] in self?.model.drag != nil }
        window.title = "Return Launchpad"
        window.identifier = NSUserInterfaceItemIdentifier("launcher-window")
        window.isOpaque = false; window.backgroundColor = .clear; window.hasShadow = false
        window.level = .popUpMenu
        window.isMovable = false
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: ContentView(model: model, preferences: preferences))
        launcherWindow = window
    }
    private func chosenScreen() -> NSScreen? {
        if testing { return NSScreen.main ?? NSScreen.screens.first }
        if preferences.usePointerScreen, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) { return screen }
        return NSScreen.main ?? NSScreen.screens.first
    }
    func toggleLauncher() { isShowing ? hideLauncher() : showLauncher() }
    func showLauncher() {
        guard let window = launcherWindow, let screen = chosenScreen() else { return }
        if isShowing {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let interval = signposter.beginInterval("window.present")
        presentationToken = UUID()
        isShowing = true
        savedPresentation = NSApp.presentationOptions
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        model.cancelDrag()
        model.searchText = ""
        model.folderID = nil
        model.presentationID = UUID()
        window.setFrame(screen.frame, display: false)
        if !window.isVisible { window.alphaValue = 0 }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = preferences.duration
            window.animator().alphaValue = 1
        } completionHandler: { [signposter] in signposter.endInterval("window.present", interval) }
        model.rescanIfNeeded()
    }
    func hideLauncher() {
        guard let window = launcherWindow, isShowing else { return }
        isShowing = false
        restorePresentation()
        model.onDragCancel?(); model.cancelDrag()
        let token = UUID(); presentationToken = token
        NSAnimationContext.runAnimationGroup { context in
            context.duration = preferences.reduceMotion ? 0.08 : 0.16
            window.animator().alphaValue = 0
        } completionHandler: { [weak self, weak window] in
            Task { @MainActor in
                guard let self, self.presentationToken == token, !self.isShowing else { return }
                window?.orderOut(nil)
            }
        }
    }
    private func restorePresentation() {
        if let savedPresentation { NSApp.presentationOptions = savedPresentation }
        savedPresentation = nil
    }
    func showSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 540, height: 640), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "Настройки — Return Launchpad"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(rootView: LauncherSettingsView(preferences: preferences, model: model, testing: testing))
            settingsWindow = window
        }
        hideLauncher()
        settingsWindow?.center()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) { if (notification.object as? NSWindow) === settingsWindow { showLauncher() } }

    private func setupMenus() {
        let main = NSMenu()
        let appItem = NSMenuItem(); main.addItem(appItem)
        let app = NSMenu(); appItem.submenu = app
        app.addItem(ClosureMenuItem(title: "О программе Return Launchpad") { NSApp.orderFrontStandardAboutPanel(nil) })
        let settings = ClosureMenuItem(title: "Настройки…") { [weak self] in self?.showSettings() }
        settings.keyEquivalent = ","; app.addItem(settings)
        app.addItem(.separator())
        let hide = ClosureMenuItem(title: "Скрыть Launchpad") { [weak self] in self?.hideLauncher() }
        hide.keyEquivalent = "h"; app.addItem(hide)
        app.addItem(.separator())
        let quit = ClosureMenuItem(title: "Завершить Return Launchpad") { NSApp.terminate(nil) }
        quit.keyEquivalent = "q"; app.addItem(quit)
        let editItem = NSMenuItem(); main.addItem(editItem)
        let edit = NSMenu(title: "Правка"); editItem.submenu = edit
        let undo = ClosureMenuItem(title: "Отменить изменение раскладки") { [weak self] in self?.model.undo() }
        undo.keyEquivalent = "z"; edit.addItem(undo)
        let redo = ClosureMenuItem(title: "Повторить изменение раскладки") { [weak self] in self?.model.redo() }
        redo.keyEquivalent = "z"; redo.keyEquivalentModifierMask = [.command, .shift]; edit.addItem(redo)
        edit.addItem(.separator())
        for (title, selector, key) in [("Вырезать", #selector(NSText.cut(_:)), "x"), ("Копировать", #selector(NSText.copy(_:)), "c"), ("Вставить", #selector(NSText.paste(_:)), "v"), ("Выбрать всё", #selector(NSText.selectAll(_:)), "a")] {
            edit.addItem(withTitle: title, action: selector, keyEquivalent: key)
        }
        NSApp.mainMenu = main
        let status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "Return Launchpad")
        status.button?.toolTip = "Return Launchpad"
        let menu = NSMenu()
        let show = ClosureMenuItem(title: "Открыть Launchpad") { [weak self] in self?.showLauncher() }
        if !testing { show.setShortcut(for: .toggleLaunchpad) }
        menu.addItem(show)
        menu.addItem(ClosureMenuItem(title: "Настройки…") { [weak self] in self?.showSettings() })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "Завершить") { NSApp.terminate(nil) })
        status.menu = menu
        statusItem = status
    }
    private func installKeyboardHandler() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.launcherWindow, self.isShowing else { return event }
            if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "w" { self.hideLauncher(); return nil }
            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
                switch event.keyCode {
                case 53: self.model.escape(); return nil
                case 125: self.model.handleArrow(self.model.columnCount); return nil
                case 126: self.model.handleArrow(-self.model.columnCount); return nil
                case 123, 124:
                    self.model.handleArrow(event.keyCode == 123 ? -1 : 1); return nil
                case 36, 76:
                    if let button = self.launcherWindow?.firstResponder as? NSButton { button.performClick(nil); return nil }
                    if self.launcherWindow?.firstResponder is NSTextView || self.launcherWindow?.firstResponder is LauncherGridView {
                        self.model.activateSelection(); return nil
                    }
                default: break
                }
            }
            return event
        }
    }
}
