import AppKit
import SwiftUI
import QuartzCore

struct FolderBackButton: NSViewRepresentable {
    var model: AppManager
    var isDragging: Bool
    var folderName: String
    var reduceMotion = false
    func makeNSView(context: Context) -> FolderBackNativeButton {
        let button = FolderBackNativeButton()
        button.model = model
        button.configureDropZone(active: isDragging, folderName: folderName, reduceMotion: reduceMotion)
        return button
    }
    func updateNSView(_ button: FolderBackNativeButton, context: Context) {
        button.model = model
        button.configureDropZone(active: isDragging, folderName: folderName, reduceMotion: reduceMotion)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: FolderBackNativeButton, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 320, height: proposal.height ?? 34)
    }
    static func dismantleNSView(_ button: FolderBackNativeButton, coordinator: ()) { button.cancelInternalHover() }
}

final class FolderBackNativeButton: NSButton {
    weak var model: AppManager?
    private var hover: DispatchWorkItem?
    private(set) var dropMode = false
    private var folderName = ""
    private var highlightedDrop = false
    private var reduceMotion = false
    init() {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: "Все приложения")
        imagePosition = .imageOnly
        isBordered = false
        wantsLayer = true
        layer?.cornerRadius = 11
        font = .systemFont(ofSize: 13, weight: .medium)
        target = self
        action = #selector(goBack)
        toolTip = "Все приложения. Перетащите сюда иконку, чтобы вынести её из папки."
        setAccessibilityIdentifier("folder-back")
        setAccessibilityLabel("Все приложения")
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        // Draw the symbol and title as one centered group, with real inner padding.
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph
        ]
        let measured = (title as NSString).size(withAttributes: attributes)
        let textWidth = min(measured.width, max(0, bounds.width - 56))
        let groupWidth = 16 + 8 + textWidth
        let left = bounds.midX - groupWidth / 2
        let symbol = NSImage(systemSymbolName: "arrow.left", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(paletteColors: [.white]))
        symbol?.draw(in: NSRect(x: left, y: bounds.midY - 8, width: 16, height: 16),
                     from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
        (title as NSString).draw(in: NSRect(x: left + 24, y: bounds.midY - measured.height / 2,
                                          width: textWidth, height: measured.height), withAttributes: attributes)
    }
    @objc private func goBack() { model?.folderID = nil }
    func configureDropZone(active: Bool, folderName: String, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let changed = dropMode != active || self.folderName != folderName
        self.folderName = folderName
        dropMode = active
        if !active {
            hover?.cancel(); hover = nil
            highlightedDrop = false
            layer?.removeAnimation(forKey: "dropHighlight")
        }
        if changed || !active { updateAppearance() }
    }
    private func updateAppearance() {
        title = dropMode ? (highlightedDrop ? "Отпустите — на главный экран" : "Перетащите на главный экран") : folderName
        imagePosition = .imageLeading
        contentTintColor = .white
        setAccessibilityLabel(dropMode ? title : "Все приложения")
        needsDisplay = true
        let old = layer?.presentation()?.backgroundColor ?? layer?.backgroundColor
        let color = dropMode ? NSColor.controlAccentColor.withAlphaComponent(highlightedDrop ? 0.42 : 0.18).cgColor : NSColor.clear.cgColor
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer?.backgroundColor = color
        layer?.borderWidth = dropMode ? 1.5 : 0
        layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(highlightedDrop ? 1 : 0.65).cgColor
        CATransaction.commit()
        if dropMode, !reduceMotion, let old {
            let fade = CABasicAnimation(keyPath: "backgroundColor")
            fade.fromValue = old; fade.toValue = color; fade.duration = 0.16
            layer?.add(fade, forKey: "dropHighlight")
        }
    }
    func cancelInternalHover() {
        hover?.cancel(); hover = nil
        if highlightedDrop { highlightedDrop = false; updateAppearance() }
    }
    func beginInternalHover() {
        guard dropMode, let token = model?.drag?.sessionID else { return }
        highlightedDrop = true; updateAppearance()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.model?.drag?.sessionID == token else { return }
            self.model?.folderID = nil
            self.model?.previewMove(before: nil)
        }
        hover?.cancel(); hover = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55, execute: work)
    }
    override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { cancelInternalHover(); layer?.removeAllAnimations() }; super.viewWillMove(toWindow: newWindow) }
}
