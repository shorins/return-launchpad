import AppKit
import SwiftUI

enum MotionStyle: String, CaseIterable, Identifiable {
    case smooth, playful, reduced
    var id: String { rawValue }
    var title: String { switch self { case .smooth: return "Плавные"; case .playful: return "Пружинные"; case .reduced: return "Минимальные" } }
}

@MainActor
final class LauncherPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var motion: MotionStyle { didSet { defaults.set(motion.rawValue, forKey: "motionStyle") } }
    @Published var iconSize: Double { didSet { defaults.set(iconSize, forKey: "iconSize") } }
    @Published var usePointerScreen: Bool { didSet { defaults.set(usePointerScreen, forKey: "usePointerScreen") } }
    @Published var hideOnDeactivate: Bool { didSet { defaults.set(hideOnDeactivate, forKey: "hideOnDeactivate") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        motion = MotionStyle(rawValue: defaults.string(forKey: "motionStyle") ?? "") ?? .smooth
        let size = defaults.double(forKey: "iconSize")
        iconSize = size == 0 ? 76 : min(96, max(56, size))
        usePointerScreen = defaults.object(forKey: "usePointerScreen") as? Bool ?? true
        hideOnDeactivate = defaults.object(forKey: "hideOnDeactivate") as? Bool ?? true
    }
    var reduceMotion: Bool { motion == .reduced || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var animation: Animation { reduceMotion ? .linear(duration: 0.1) : (motion == .playful ? .spring(duration: 0.32, bounce: 0.22) : .smooth(duration: 0.24)) }
    var duration: TimeInterval { reduceMotion ? 0.1 : 0.24 }
}
