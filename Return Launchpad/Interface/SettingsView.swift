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
                if testing { LabeledContent("Открыть / скрыть", value: "⌃⌥Пробел") }
                else { KeyboardShortcuts.Recorder("Открыть / скрыть", name: .toggleLaunchpad) }
                Text("Launchpad остаётся готовым в строке меню. Нажмите сочетание ещё раз, чтобы скрыть окно.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Открывать на экране с указателем", isOn: $preferences.usePointerScreen)
                Toggle("Скрывать при переключении в другое приложение", isOn: $preferences.hideOnDeactivate)
            } header: { Label("Быстрый доступ", systemImage: "keyboard") }

            Section {
                Picker("Анимации", selection: $preferences.motion) {
                    ForEach(MotionStyle.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                LabeledContent("Размер иконок") {
                    Slider(value: $preferences.iconSize, in: 56...96, step: 4).frame(width: 180)
                    Text("\(Int(preferences.iconSize))").monospacedDigit().frame(width: 30)
                }
                Text("Системные настройки уменьшения движения и прозрачности имеют приоритет.")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Label("Внешний вид", systemImage: "sparkles") }

            Section {
                Toggle("Запускать при входе в macOS", isOn: Binding(get: { loginStatus == .enabled || loginStatus == .requiresApproval }, set: setLogin))
                    .disabled(testing)
                if loginStatus == .requiresApproval {
                    Button("Разрешить в настройках macOS…") { SMAppService.openSystemSettingsLoginItems() }
                }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                Text("Для автозапуска переместите приложение в папку «Программы».").font(.caption).foregroundStyle(.secondary)
            } header: { Label("При входе в систему", systemImage: "power") }

            Section {
                LabeledContent("Найдено приложений", value: "\(model.apps.count)")
                Button("Добавить папку приложений…") { model.chooseApplicationsDirectory() }
                    .disabled(testing)
                Text("Для приложений из личной папки Applications разрешите её чтение один раз. Можно добавить и другие папки.")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Обновить список") { model.rescanApps() }
                    Button("Упорядочить по алфавиту") { model.alphabetize() }
                }
                if !model.catalogIssues.isEmpty {
                    Text(model.catalogIssues.joined(separator: "\n")).font(.caption).foregroundStyle(.orange).textSelection(.enabled)
                }
                Text("Папки и порядок сохраняются автоматически. Изменение порядка можно отменить: ⌘Z.").font(.caption).foregroundStyle(.secondary)
            } header: { Label("Приложения", systemImage: "square.grid.3x3") }
        }
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
