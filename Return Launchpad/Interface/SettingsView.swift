import SwiftUI
import KeyboardShortcuts
import ServiceManagement

extension KeyboardShortcuts.Name {
    static let toggleLaunchpad = Self("toggleLaunchpad", initial: .init(.space, modifiers: [.control, .option]))
}

struct LauncherSettingsView: View {
    @ObservedObject var preferences: LauncherPreferences
    @ObservedObject var model: AppManager
    var testing = false
    @State private var loginStatus = SMAppService.mainApp.status
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Picker(L10n.text("Interface language"), selection: $preferences.language) {
                    ForEach(AppLanguage.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("language-picker")
                Text(L10n.text("Russian on a Russian system; English on all others."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label(L10n.text("Language"), systemImage: "globe") }
            Section {
                if testing { LabeledContent(L10n.text("Show / hide"), value: L10n.text("⌃⌥Space")) }
                else { KeyboardShortcuts.Recorder(L10n.text("Show / hide"), name: .toggleLaunchpad) }
                Text(L10n.text("Launchpad stays ready in the background. Press the shortcut again to hide it, or reopen it from the Dock."))
                    .font(.caption).foregroundStyle(.secondary)
                Toggle(L10n.text("Open on the screen with the pointer"), isOn: $preferences.usePointerScreen)
                Toggle(L10n.text("Hide when switching to another app"), isOn: $preferences.hideOnDeactivate)
            } header: { Label(L10n.text("Quick access"), systemImage: "keyboard") }

            Section {
                Picker(L10n.text("Animations"), selection: $preferences.motion) {
                    ForEach(MotionStyle.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                LabeledContent(L10n.text("Icon size")) {
                    Slider(value: $preferences.iconSize, in: 56...96, step: 4).frame(width: 180)
                    Text("\(Int(preferences.iconSize))").monospacedDigit().frame(width: 30)
                }
                Text(L10n.text("System Reduce Motion and Reduce Transparency settings take priority."))
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label(L10n.text("Appearance"), systemImage: "sparkles") }

            Section {
                Toggle(L10n.text("Launch at login"), isOn: Binding(get: { loginStatus == .enabled || loginStatus == .requiresApproval }, set: setLogin))
                    .disabled(testing)
                if loginStatus == .requiresApproval {
                    Button(L10n.text("Allow in macOS Settings…")) { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                Text(L10n.text("Move the app to Applications to enable launch at login.")).font(.caption).foregroundStyle(.secondary)
            } header: { Label(L10n.text("At login"), systemImage: "power") }

            Section {
                LabeledContent(L10n.text("Apps found"), value: "\(model.apps.count)")
                Button(L10n.text("Add application folder…")) { model.chooseApplicationsDirectory() }
                    .disabled(testing)
                Text(L10n.text("Grant access once to your personal Applications folder. You can add other folders too."))
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(L10n.text("Refresh list")) { model.rescanApps() }
                    Button(L10n.text("Sort alphabetically")) { model.alphabetize() }
                }
                if !model.catalogIssues.isEmpty {
                    Text(model.catalogIssues.joined(separator: "\n")).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                Text(L10n.text("Folders and app order save automatically. Undo layout changes with ⌘Z.")).font(.caption).foregroundStyle(.secondary)
            } header: { Label(L10n.text("Apps"), systemImage: "square.grid.3x3") }
        }
        .id(preferences.language)
        .environment(\.locale, Locale(identifier: L10n.languageCode))
        .formStyle(.grouped)
        .frame(width: 540, height: 640)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in loginStatus = SMAppService.mainApp.status }
    }
    private func setLogin(_ enabled: Bool) {
        guard !testing else { return }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch { loginError = error.localizedDescription }
        loginStatus = SMAppService.mainApp.status
    }
}
