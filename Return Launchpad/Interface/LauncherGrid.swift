import AppKit
import SwiftUI
import QuartzCore

private final class DragPreviewView: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class LauncherPageView: NSView {
    var allowsHitTesting = true
    override func hitTest(_ point: NSPoint) -> NSView? { allowsHitTesting ? super.hitTest(point) : nil }
    override var isFlipped: Bool { true }
}

struct LauncherGrid: NSViewRepresentable {
    @ObservedObject var model: AppManager
    @ObservedObject var preferences: LauncherPreferences
    func makeNSView(context: Context) -> LauncherGridView {
        let view = LauncherGridView()
        view.model = model
        view.preferences = preferences
        return view
    }
    func updateNSView(_ view: LauncherGridView, context: Context) {
        view.model = model
        view.preferences = preferences
        view.refresh()
    }
    static func dismantleNSView(_ view: LauncherGridView, coordinator: ()) { view.endInternalDrag() }
}

/// Stable native tiles with an internal drag that never starts a system drag session.
final class LauncherGridView: NSView {
    weak var model: AppManager?
    weak var preferences: LauncherPreferences?
    private var tiles: [String: LauncherTile] = [:]
    private var frames: [String: NSRect] = [:]
    private var hoverTask: DispatchWorkItem?
    private var pageTask: DispatchWorkItem?
    private var hoverID: String?
    private var edgeDirection = 0
    private var lastPage = -1
    private var lastContainer: LayoutContainer = .root
    private var previousIDs: [String] = []
    private var previousQuery = ""
    private var previousPresentation: UUID?
    private var lastHoverPoint: NSPoint?
    private var dragMonitor: Any?
    private var pendingDragEvent: NSEvent?
    private var dragUpdateTask: DispatchWorkItem?
    private weak var cachedBackButton: FolderBackNativeButton?
    private var cachedBackFolderID: String?
    private var dragPreview: DragPreviewView?
    private weak var backTarget: FolderBackNativeButton?
    private var backRect: NSRect?
    private var backDropActive = false
    private var scrollAccumulator: CGFloat = 0
    private var lastScroll = Date.distantPast
    private let emptyTarget = NSView()
    private var pageView = LauncherPageView()
    private var outgoingPage: NSView?
    private var transitionID = UUID()
    private var folderOrigin = NSRect.zero
    private var interactionResumes = Date.distantPast
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = true
        pageView.wantsLayer = true
        addSubview(pageView)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Приложения")
        emptyTarget.wantsLayer = true
        emptyTarget.layer?.cornerRadius = 18
        emptyTarget.layer?.borderWidth = 1
        emptyTarget.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        emptyTarget.isHidden = true
        addSubview(emptyTarget)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); refresh() }

    func refresh() {
        guard let model, let preferences, bounds.width > 1, bounds.height > 1 else { return }
        let cellWidth = max(CGFloat(116), CGFloat(preferences.iconSize) + 58)
        let cellHeight = CGFloat(preferences.iconSize) + 62
        let columns = max(1, min(9, Int((bounds.width - 48) / cellWidth)))
        let rows = max(1, min(6, Int((bounds.height - 12) / cellHeight)))
        if model.itemsPerPage != columns * rows || model.columnCount != columns {
            DispatchQueue.main.async { [weak model] in model?.configureGrid(columns: columns, capacity: columns * rows) }
        }
        let ids = model.pageIDs
        let queryChanged = previousQuery != model.searchText
        let reopened = previousPresentation != model.presentationID
        if queryChanged {
            transitionID = UUID()
            outgoingPage?.removeFromSuperview(); outgoingPage = nil
            pageView.layer?.removeAllAnimations()
            interactionResumes = .distantPast
        }
        let containerChanged = lastContainer != model.currentContainer
        let openingFolder = model.folderID != nil
        if containerChanged, let folder = model.folderID, let frame = frames[folder] { folderOrigin = frame }
        let pageChanged = lastPage != model.currentPage || lastContainer != model.currentContainer
        let changed = ids != previousIDs
        let direction = model.currentPage >= lastPage ? 1.0 : -1.0
        let animatePage = pageChanged && !queryChanged && lastPage >= 0 && !preferences.reduceMotion
        if pageChanged {
            IconCache.shared.pauseExtraction(for: 0.28)
            outgoingPage?.removeFromSuperview()
            outgoingPage = nil
            transitionID = UUID()
            if animatePage {
                outgoingPage = pageView
                pageView.allowsHitTesting = false
                pageView = LauncherPageView(frame: bounds)
                pageView.wantsLayer = true
                addSubview(pageView, positioned: .below, relativeTo: emptyTarget)
            }
        }
        if pageView.frame != bounds {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            pageView.frame = bounds
            CATransaction.commit()
        }
        let originX = (bounds.width - CGFloat(columns) * cellWidth) / 2
        // A sparse folder and a full page must share the same baseline.
        // Content-dependent centering moved the first row by up to 18 pt during zoom.
        let originY: CGFloat = 8
        var nextFrames: [String: NSRect] = [:]
        for (index, id) in ids.enumerated() {
            nextFrames[id] = NSRect(x: originX + CGFloat(index % columns) * cellWidth + 5,
                                    y: originY + CGFloat(index / columns) * cellHeight + 3,
                                    width: cellWidth - 10, height: cellHeight - 6)
        }
        if pageChanged || changed || queryChanged || reopened {
            tiles.values.forEach { $0.setPointerHovered(false) }
        }
        let visible = Set(ids)
        for (id, tile) in tiles where !visible.contains(id) {
            if tile.superview !== outgoingPage { tile.removeFromSuperview() }
            if model.app(id) == nil && model.displayedLayout.folder(id) == nil { tiles.removeValue(forKey: id) }
        }
        for id in ids {
            guard let destination = nextFrames[id] else { continue }
            let isNew = tiles[id] == nil
            let tile = tiles[id] ?? LauncherTile()
            if isNew {
                tiles[id] = tile
            }
            if tile.superview !== pageView { tile.removeFromSuperview(); pageView.addSubview(tile) }
            tile.configure(id: id, model: model, iconSize: preferences.iconSize)
            tile.onActivate = { [weak model] in model?.activate(id) }
            tile.onPointerEnter = { [weak self, weak tile] in
                guard let self, let tile, tile.superview === self.pageView,
                      Date() >= self.interactionResumes else { return }
                self.tiles.values.forEach { $0.setPointerHovered($0 === tile) }
            }
            tile.onFocus = { [weak model] in model?.selectedID = id }
            tile.onDrag = { [weak self, weak tile] event in
                guard let self, let tile else { return }
                self.beginDrag(id: id, tile: tile, event: event)
            }
            tile.onMenu = { [weak self] in self?.menu(for: id) }
            tile.isSelected = model.selectedID == id
            tile.isFolderTarget = model.folderCandidate == id
            let opacity: CGFloat = model.drag?.itemID == id ? 0.12 : 1
            let moved = tile.frame != destination
            let animateMove = moved && changed && !queryChanged && !model.isSearching && !pageChanged && !isNew && lastPage >= 0 && !preferences.reduceMotion
            let previousPosition = tile.layer?.presentation()?.position ?? tile.layer?.position
            if pageChanged || queryChanged { tile.layer?.removeAllAnimations() }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if moved { tile.frame = destination }
            if tile.alphaValue != opacity { tile.alphaValue = opacity }
            if animateMove, let layer = tile.layer, let previousPosition {
                let motion = CABasicAnimation(keyPath: "position")
                motion.fromValue = NSValue(point: previousPosition)
                motion.toValue = NSValue(point: layer.position)
                motion.duration = 0.22
                motion.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
                // Replace in-flight motion from its displayed position; do not stack animations.
                layer.add(motion, forKey: "reorder")
            }
            CATransaction.commit()
        }
        frames = nextFrames
        previousIDs = ids
        previousQuery = model.searchText
        previousPresentation = model.presentationID
        if queryChanged && !preferences.reduceMotion {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 0
            fade.toValue = 1
            fade.duration = 0.16
            fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
            pageView.layer?.add(fade, forKey: "searchFade")
        }
        lastPage = model.currentPage
        lastContainer = model.currentContainer
        if animatePage {
            if containerChanged { animateFolderTransition(opening: openingFolder) }
            else { animatePageTransition(direction: direction) }
            interactionResumes = Date().addingTimeInterval(containerChanged ? 0.32 : 0.24)
        }
        emptyTarget.isHidden = model.drag == nil || ids.count >= columns * rows
        if !emptyTarget.isHidden {
            let index = ids.count
            emptyTarget.frame = NSRect(x: originX + CGFloat(index % columns) * cellWidth + 13,
                                       y: originY + CGFloat(index / columns) * cellHeight + 11,
                                       width: cellWidth - 26, height: cellHeight - 22)
        }
        model.onDragCancel = { [weak self] in self?.endInternalDrag() }
    }

    private func animatePageTransition(direction: Double) {
        guard let incoming = pageView.layer else { return }
        let token = transitionID
        let duration = 0.24
        let distance = Double(bounds.width) * direction
        func slide(_ layer: CALayer, from: Double, to: Double) {
            let animation = CABasicAnimation(keyPath: "transform.translation.x")
            animation.fromValue = from
            animation.toValue = to
            animation.duration = duration
            animation.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
            animation.fillMode = .forwards
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: "pageSlide")
        }
        // Two composited page surfaces, rather than dozens of view-frame animations.
        slide(incoming, from: distance, to: 0)
        if let outgoing = outgoingPage?.layer {
            let offset = outgoing.presentation()?.transform.m41 ?? 0
            slide(outgoing, from: Double(offset), to: -distance)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.transitionID == token else { return }
            self.outgoingPage?.removeFromSuperview()
            self.outgoingPage = nil
            incoming.removeAnimation(forKey: "pageSlide")
        }
    }

    private func animateFolderTransition(opening: Bool) {
        guard let incoming = pageView.layer else { return }
        let token = transitionID
        let duration = 0.32
        let origin = folderOrigin == .zero ? NSRect(x: bounds.midX, y: bounds.midY, width: 1, height: 1) : folderOrigin
        func animate(_ layer: CALayer, appearing: Bool, zoomed: Bool) {
            let pivot = NSPoint(x: layer.bounds.width * layer.anchorPoint.x, y: layer.bounds.height * layer.anchorPoint.y)
            let scale: CGFloat = zoomed ? 0.12 : 1.06
            var small = CATransform3DMakeTranslation((origin.midX - pivot.x) * (1 - scale), (origin.midY - pivot.y) * (1 - scale), 0)
            small = CATransform3DScale(small, scale, scale, 1)
            let transform = CABasicAnimation(keyPath: "transform")
            transform.fromValue = NSValue(caTransform3D: appearing ? small : CATransform3DIdentity)
            transform.toValue = NSValue(caTransform3D: appearing ? CATransform3DIdentity : small)
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = appearing ? 0 : 1
            opacity.toValue = appearing ? 1 : 0
            let group = CAAnimationGroup()
            group.animations = [transform, opacity]
            group.duration = duration
            group.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.75, 0.25, 1)
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            layer.add(group, forKey: "folderZoom")
        }
        animate(incoming, appearing: true, zoomed: opening)
        if let outgoing = outgoingPage?.layer { animate(outgoing, appearing: false, zoomed: !opening) }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.transitionID == token else { return }
            self.outgoingPage?.removeFromSuperview(); self.outgoingPage = nil
            incoming.removeAnimation(forKey: "folderZoom")
        }
    }

    private func finishDrop(valid: Bool, candidate: String?) {
        let preview = dragPreview
        let target = candidate.flatMap { tiles[$0] }
        let folderDestination = target.flatMap { tile in preview?.superview.map { tile.convert(tile.bounds.insetBy(dx: tile.bounds.width * 0.35, dy: tile.bounds.height * 0.35), to: $0) } }
        let destination = backDropActive ? backRect.map { NSRect(x: $0.midX - 14, y: $0.midY - 14, width: 28, height: 28) } : folderDestination
        let animate = valid && destination != nil && preferences?.reduceMotion == false
        if animate { dragPreview = nil }
        endInternalDrag()
        if valid { model?.commitDrag(folderTarget: candidate) } else { model?.cancelDrag() }
        refresh()
        if animate, let preview, let destination {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.26
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                preview.animator().frame = destination
                preview.animator().alphaValue = 0
            } completionHandler: { preview.removeFromSuperview() }
        }
    }

    private func beginDrag(id: String, tile: LauncherTile, event: NSEvent) {
        guard let model, model.beginDrag(id) != nil, let root = window?.contentView else { return }
        let preview = DragPreviewView(frame: tile.convert(tile.bounds, to: root))
        preview.image = tile.dragImage()
        preview.imageScaling = .scaleProportionallyUpOrDown
        preview.alphaValue = 0.9
        root.addSubview(preview)
        dragPreview = preview
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { [weak self] event in
            guard let self else { return event }
            self.updateInternalDrag(event)
            if event.type == .leftMouseUp {
                let point = self.convert(event.locationInWindow, from: nil)
                let valid = (point.y >= 0 && point.y <= self.bounds.height) || self.backDropActive
                if self.backDropActive { self.model?.folderID = nil; self.model?.previewMove(before: nil) }
                let candidate = self.model?.folderCandidate
                self.finishDrop(valid: valid, candidate: candidate)
            }
            return nil
        }
        updateInternalDrag(event)
        refresh()
    }
    private func updateInternalDrag(_ event: NSEvent) {
        guard model?.drag != nil, let root = window?.contentView else { endInternalDrag(); return }
        let point = root.convert(event.locationInWindow, from: nil)
        if let preview = dragPreview {
            preview.setFrameOrigin(NSPoint(x: point.x - preview.frame.width / 2, y: point.y - preview.frame.height / 2))
        }
        if event.type == .leftMouseUp {
            dragUpdateTask?.cancel(); dragUpdateTask = nil; pendingDragEvent = nil
            processDragLocation(event)
        } else {
            pendingDragEvent = event
            guard dragUpdateTask == nil else { return }
            let task = DispatchWorkItem { [weak self] in
                guard let self else { return }
                self.dragUpdateTask = nil
                guard let latest = self.pendingDragEvent else { return }
                self.pendingDragEvent = nil
                self.processDragLocation(latest)
            }
            dragUpdateTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 / 60.0, execute: task)
        }
    }
    private func processDragLocation(_ event: NSEvent) {
        guard model?.drag != nil, let root = window?.contentView else { return }
        let point = root.convert(event.locationInWindow, from: nil)
        func backButton(in view: NSView) -> FolderBackNativeButton? {
            if let back = view as? FolderBackNativeButton,
               !back.isHidden { return back }
            for child in view.subviews { if let back = backButton(in: child) { return back } }
            return nil
        }
        if cachedBackFolderID != model?.folderID {
            cachedBackButton?.cancelInternalHover()
            cachedBackButton = nil
            cachedBackFolderID = model?.folderID
        }
        if model?.folderID != nil, cachedBackButton?.window !== window {
            cachedBackButton = backButton(in: root)
        }
        let back = model?.folderID != nil ? cachedBackButton.flatMap {
            $0.convert($0.bounds, to: root).contains(point) ? $0 : nil
        } : nil
        if let back { backRect = back.convert(back.bounds, to: root) }
        backDropActive = back != nil || (model?.folderID == nil && backRect?.contains(point) == true)
        if back !== backTarget {
            backTarget?.cancelInternalHover()
            backTarget = back
            back?.beginInternalHover()
        }
        var local = convert(event.locationInWindow, from: nil)
        if backDropActive || local.y < 0 || local.y > bounds.height { stopHoverTasks(); return }
        local.x = min(max(0, local.x), bounds.width)
        updateDrag(at: local)
    }
    fileprivate func endInternalDrag() {
        dragUpdateTask?.cancel(); dragUpdateTask = nil; pendingDragEvent = nil
        cachedBackButton?.cancelInternalHover()
        cachedBackButton = nil; cachedBackFolderID = nil
        if let dragMonitor { NSEvent.removeMonitor(dragMonitor) }
        dragMonitor = nil
        dragPreview?.removeFromSuperview(); dragPreview = nil
        backTarget?.cancelInternalHover(); backTarget = nil
        backRect = nil; backDropActive = false
        stopHoverTasks()
    }
    @discardableResult private func updateDrag(at point: NSPoint) -> NSDragOperation {
        guard let model, let drag = model.drag else { return [] }
        guard Date() >= interactionResumes else { return .move }
        updateEdge(at: point)
        if edgeDirection != 0 {
            clearFolderHover()
            model.previewMoveToPageEdge(forward: edgeDirection > 0)
            return .move
        }
        // Retarget only after pointer movement. Animated neighbours moving under a stationary
        // pointer must not trigger alternating insertions.
        if let last = lastHoverPoint, hypot(point.x - last.x, point.y - last.y) < 3 { return .move }
        lastHoverPoint = point
        guard let target = model.pageIDs.first(where: { frames[$0]?.contains(point) == true }), let frame = frames[target] else {
            clearFolderHover()
            if point.y >= (frames.values.map(\.minY).max() ?? 0) {
                let ids = model.visibleIDs
                let next = (model.currentPage + 1) * model.itemsPerPage
                model.previewMove(before: next < ids.count ? ids[next] : nil)
            }
            return .move
        }
        guard target != drag.itemID else { clearFolderHover(); return .move }
        let center = frame.insetBy(dx: frame.width * 0.26, dy: frame.height * 0.2)
        if center.contains(point), model.folderID == nil, drag.original.folder(drag.itemID) == nil {
            beginFolderHover(target)
        } else {
            clearFolderHover()
            let ids = model.visibleIDs
            if let index = ids.firstIndex(of: target) {
                let anchor = point.x < frame.midX ? target : (index + 1 < ids.count ? ids[index + 1] : nil)
                if anchor != drag.itemID { model.previewMove(before: anchor) }
            }
        }
        return .move
    }
    private func beginFolderHover(_ id: String) {
        guard hoverID != id else { return }
        clearFolderHover()
        hoverID = id
        let existingFolder = model?.layout.folder(id) != nil
        if existingFolder { model?.folderCandidate = id }
        let token = model?.drag?.sessionID
        let task = DispatchWorkItem { [weak self] in
            guard let self, let model = self.model, model.drag?.sessionID == token, self.hoverID == id else { return }
            model.folderCandidate = id
            if model.layout.folder(id) != nil {
                let openTask = DispatchWorkItem { [weak self] in
                    guard let self, self.hoverID == id, let model = self.model, model.drag?.sessionID == token else { return }
                    model.folderID = id
                    model.previewMove(before: nil)
                    model.folderCandidate = nil
                    self.hoverID = nil
                    self.lastHoverPoint = nil
                }
                self.hoverTask = openTask
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: openTask)
            }
        }
        hoverTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + (existingFolder ? 0.0 : 0.55), execute: task)
    }
    private func clearFolderHover() {
        hoverTask?.cancel(); hoverTask = nil; hoverID = nil
        if model?.folderCandidate != nil { model?.folderCandidate = nil }
    }
    private func updateEdge(at point: NSPoint) {
        guard let model else { return }
        let direction = point.x < 48 && model.currentPage > 0 ? -1 : (point.x > bounds.width - 48 && model.currentPage < model.pageCount - 1 ? 1 : 0)
        guard direction != edgeDirection else { return }
        pageTask?.cancel(); pageTask = nil
        edgeDirection = direction
        if direction != 0 { schedulePage(direction) }
    }
    private func schedulePage(_ direction: Int, repeating: Bool = false) {
        let token = model?.drag?.sessionID
        let task = DispatchWorkItem { [weak self] in
            guard let self, let model = self.model, self.edgeDirection == direction, model.drag?.sessionID == token else { return }
            model.changePage(direction)
            model.previewMoveToPageEdge(forward: direction > 0)
            self.lastHoverPoint = nil
            if direction < 0 ? model.currentPage > 0 : model.currentPage < model.pageCount - 1 { self.schedulePage(direction, repeating: true) }
        }
        pageTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + (repeating ? 1.1 : 0.65), execute: task)
    }
    func stopHoverTasks() {
        clearFolderHover(); pageTask?.cancel(); pageTask = nil; edgeDirection = 0; lastHoverPoint = nil
    }
    override func mouseDown(with event: NSEvent) {
        guard Date() >= interactionResumes else { return }
        model?.escape()
    }
    override func scrollWheel(with event: NSEvent) {
        guard model?.drag == nil else { return }
        guard event.momentumPhase.isEmpty else { return }
        if event.phase == .began { scrollAccumulator = 0 }
        let delta = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) ? event.scrollingDeltaX : event.scrollingDeltaY
        scrollAccumulator += delta
        let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 55 : 3
        if abs(scrollAccumulator) > threshold && Date().timeIntervalSince(lastScroll) > 0.18 {
            model?.changePage(scrollAccumulator > 0 ? -1 : 1)
            scrollAccumulator = 0; lastScroll = Date()
        }
    }

    private func menu(for id: String) -> NSMenu {
        let menu = NSMenu()
        guard let model else { return menu }
        func add(_ title: String, action: @escaping () -> Void) {
            let item = ClosureMenuItem(title: title, action: action)
            menu.addItem(item)
        }
        add(model.layout.folder(id) == nil ? "Открыть" : "Открыть папку") { [weak model] in model?.activate(id) }
        if let folder = model.layout.folder(id) {
            add("Переименовать…") { [weak model] in
                guard let model else { return }
                let alert = NSAlert()
                alert.window.level = self.window?.level ?? .modalPanel
                alert.messageText = "Название папки"
                alert.addButton(withTitle: "Сохранить"); alert.addButton(withTitle: "Отмена")
                let field = NSTextField(string: folder.name)
                field.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
                alert.accessoryView = field
                alert.window.initialFirstResponder = field
                if alert.runModal() == .alertFirstButtonReturn { model.renameFolder(id, name: field.stringValue) }
            }
            add("Расформировать папку") { [weak model] in model?.dissolveFolder(id) }
        } else if !model.isSearching {
            if model.folderID != nil { add("На главный экран") { [weak model] in model?.moveItem(id, to: .root) } }
            for folder in model.layout.folders where folder.id != model.folderID {
                add("В папку «\(folder.name)»") { [weak model] in model?.moveItem(id, to: .folder(folder.id)) }
            }
            if model.folderID == nil {
                let create = NSMenuItem(title: "Создать папку с…", action: nil, keyEquivalent: "")
                let choices = NSMenu()
                for target in model.layout.rootItems where target != id && model.app(target) != nil {
                    choices.addItem(ClosureMenuItem(title: model.title(target)) { [weak model] in model?.createFolder(id, with: target) })
                }
                create.submenu = choices
                menu.addItem(create)
            }
        }
        if !model.isSearching {
            add("В начало") { [weak model] in
                guard let model else { return }
                model.moveItem(id, to: model.currentContainer, before: model.visibleIDs.first)
            }
            add("В конец") { [weak model] in guard let model else { return }; model.moveItem(id, to: model.currentContainer) }
        }
        return menu
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void
    init(title: String, action: @escaping () -> Void) {
        handler = action
        super.init(title: title, action: #selector(invoke), keyEquivalent: "")
        target = self
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func invoke() { handler() }
}

final class LauncherTile: NSButton {
    var onActivate: (() -> Void)?
    var onFocus: (() -> Void)?
    var onPointerEnter: (() -> Void)?
    var onDrag: ((NSEvent) -> Void)?
    var onMenu: (() -> NSMenu?)?
    var isSelected = false { didSet { if oldValue != isSelected { needsDisplay = true } } }
    var isFolderTarget = false { didSet { if oldValue != isFolderTarget { needsDisplay = true } } }
    private var itemID = ""
    private var displayName = ""
    private var subtitle: String?
    private var iconSize: CGFloat = 76
    private var icons: [NSImage] = []
    private var imageKeys: [String] = []
    private var folder = false
    private(set) var hovered = false
    private var tracking: NSTrackingArea?
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init() {
        super.init(frame: .zero)
        isBordered = false
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        setButtonType(.momentaryChange)
        target = self; action = #selector(activate)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func activate() { onActivate?() }
    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?() }
        return accepted
    }
    func configure(id: String, model: AppManager, iconSize: Double) {
        let nextName = model.title(id)
        let nextSubtitle = model.isSearching ? model.parentFolderName(id) : nil
        let nextFolder = model.displayedLayout.folder(id) != nil
        var redraw = itemID != id || self.iconSize != iconSize || displayName != nextName || subtitle != nextSubtitle || folder != nextFolder
        itemID = id
        self.iconSize = iconSize
        displayName = nextName
        subtitle = nextSubtitle
        folder = nextFolder
        if redraw {
            setAccessibilityLabel(displayName + (folder ? ", папка" : ""))
            setAccessibilityIdentifier("tile-" + id)
            toolTip = displayName
        }
        let apps = folder ? Array((model.displayedLayout.folder(id)?.appIDs ?? []).prefix(9)).compactMap { model.app($0) } : [model.app(id)].compactMap { $0 }
        let keys = apps.map(\.iconKey)
        if keys != imageKeys {
            redraw = true
            imageKeys = keys
            icons = Array(repeating: NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage(), count: apps.count)
            for (index, app) in apps.enumerated() {
                IconCache.shared.image(for: app) { [weak self] image in
                    guard let self, self.itemID == id, self.imageKeys == keys, self.icons.indices.contains(index) else { return }
                    self.icons[index] = image; self.needsDisplay = true
                }
            }
        }
        if redraw { needsDisplay = true }
    }
    func setPointerHovered(_ value: Bool) {
        guard hovered != value else { return }
        hovered = value
        needsDisplay = true
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        setPointerHovered(false)
        super.viewWillMove(toWindow: newWindow)
    }
    override func viewWillMove(toSuperview newSuperview: NSView?) {
        setPointerHovered(false)
        super.viewWillMove(toSuperview: newSuperview)
    }
    override func updateTrackingAreas() {
        setPointerHovered(false)
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: .zero, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        if let tracking { addTrackingArea(tracking) }
        super.updateTrackingAreas()
    }
    override func mouseEntered(with event: NSEvent) {
        guard let window, window.isKeyWindow, window.isVisible,
              bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil)) else { return }
        onPointerEnter?()
    }
    override func mouseExited(with event: NSEvent) { setPointerHovered(false) }
    override func rightMouseDown(with event: NSEvent) { if let menu = onMenu?() { NSMenu.popUpContextMenu(menu, with: event, for: self) } }
    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { rightMouseDown(with: event); return }
        guard let window else { return }
        let origin = event.locationInWindow
        while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp {
                if bounds.contains(convert(next.locationInWindow, from: nil)) { onActivate?() }
                return
            }
            if hypot(next.locationInWindow.x - origin.x, next.locationInWindow.y - origin.y) >= 5 {
                onDrag?(next); return
            }
        }
    }
    override func draw(_ dirtyRect: NSRect) {
        if hovered || isSelected || isFolderTarget {
            (isFolderTarget ? NSColor.controlAccentColor.withAlphaComponent(0.3) : NSColor.white.withAlphaComponent(isSelected ? 0.18 : 0.08)).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 18, yRadius: 18).fill()
        }
        if isSelected || isFolderTarget {
            (isFolderTarget ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.65)).setStroke()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 17, yRadius: 17)
            path.lineWidth = 2; path.stroke()
        }
        let iconRect = NSRect(x: (bounds.width - iconSize) / 2, y: 8, width: iconSize, height: iconSize)
        if folder {
            NSColor.white.withAlphaComponent(0.16).setFill()
            NSBezierPath(roundedRect: iconRect, xRadius: iconSize * 0.23, yRadius: iconSize * 0.23).fill()
            let size = (iconSize - 16) / 3
            for (index, image) in icons.prefix(9).enumerated() {
                image.draw(in: NSRect(x: iconRect.minX + 8 + CGFloat(index % 3) * size, y: iconRect.minY + 8 + CGFloat(index / 3) * size, width: size - 2, height: size - 2), from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
            }
        } else {
            icons.first?.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
        }
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center; paragraph.lineBreakMode = .byTruncatingTail
        let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.5); shadow.shadowBlurRadius = 3; shadow.shadowOffset = NSSize(width: 0, height: -1)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: NSColor.white, .paragraphStyle: paragraph, .shadow: shadow]
        (displayName as NSString).draw(in: NSRect(x: 3, y: iconRect.maxY + 8, width: bounds.width - 6, height: 31), withAttributes: attributes)
        if let subtitle {
            (subtitle as NSString).draw(in: NSRect(x: 3, y: bounds.height - 17, width: bounds.width - 6, height: 14), withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.white.withAlphaComponent(0.6), .paragraphStyle: paragraph])
        }
    }
    func dragImage() -> NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocusFlipped(true)
        draw(bounds)
        image.unlockFocus()
        return image
    }
}
