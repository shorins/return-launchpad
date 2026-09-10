import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var model: AppManager
    @ObservedObject var preferences: LauncherPreferences
    @FocusState private var searchFocused: Bool
    @State private var renaming = false
    @State private var folderName = ""
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        ZStack {
            if reduceTransparency { Color(red: 0.12, green: 0.14, blue: 0.18) }
            else {
                VisualEffectBackground()
                LinearGradient(colors: [.black.opacity(0.28), Color(red: 0.09, green: 0.12, blue: 0.19).opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            VStack(spacing: 0) {
                header.padding(.horizontal, 36).padding(.top, 28)
                search.padding(.top, 24).padding(.bottom, 12)
                // Keep grid geometry identical before, during, and after a folder transition.
                ZStack {
                    if let folder = model.currentFolder, !model.isSearching {
                        ZStack {
                            if model.drag != nil {
                                FolderBackButton(model: model, isDragging: true, folderName: folder.name, reduceMotion: preferences.reduceMotion)
                                    .frame(width: 320, height: 34)
                            } else {
                                HStack(spacing: 10) {
                                    Button { model.folderID = nil } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "arrow.left").font(.system(size: 16))
                                            Text(folder.name).font(.system(size: 13, weight: .medium))
                                                .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                                        }
                                        .fixedSize(horizontal: true, vertical: false)
                                    }
                                    .accessibilityIdentifier("folder-back")
                                    .accessibilityLabel("Все приложения, " + folder.name)
                                    .launcherInteractionRegion()
                                    Button { folderName = folder.name; renaming = true } label: {
                                        Image(systemName: "pencil").font(.system(size: 13))
                                            .frame(width: 24, height: 30)
                                    }
                                    .accessibilityIdentifier("folder-rename")
                                    .help("Переименовать папку").launcherInteractionRegion()
                                }
                                .buttonStyle(.plain)
                                .fixedSize(horizontal: true, vertical: false)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .frame(height: 40)
                .animation(preferences.animation, value: model.folderID)
                ZStack {
                    LauncherGrid(model: model, preferences: preferences)
                    if model.visibleIDs.isEmpty {
                        VStack(spacing: 12) {
                            if model.isLoading { ProgressView().controlSize(.large); Text("Загружаем приложения…") }
                            else {
                                Image(systemName: model.isSearching ? "magnifyingglass" : "square.grid.3x3").font(.system(size: 36, weight: .light))
                                Text(model.isSearching ? "Ничего не найдено" : "Приложения не найдены").font(.title3)
                                if model.isSearching { Text("Попробуйте другое название").foregroundStyle(.secondary) }
                                else { Button("Обновить список") { model.rescanApps() }.launcherInteractionRegion() }
                            }
                        }.foregroundStyle(.white.opacity(0.8))
                    }
                }
                footer.padding(.horizontal, 36).padding(.bottom, 64)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { searchFocused = true }
        .onChange(of: model.presentationID) { searchFocused = true }
        .alert("Return Launchpad", isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })) {
            Button("Понятно", role: .cancel) { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
        .alert("Название папки", isPresented: $renaming) {
            TextField("Название", text: $folderName)
            Button("Сохранить") { if let id = model.folderID { model.renameFolder(id, name: folderName) } }
            Button("Отмена", role: .cancel) {}
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.3x3.fill").font(.system(size: 21, weight: .medium)).foregroundStyle(.white.opacity(0.85))
                Text("Launchpad").font(.system(size: 18, weight: .semibold, design: .rounded))
            }
            Spacer()
            Text("\(model.apps.count) приложений").font(.subheadline).foregroundStyle(.white.opacity(0.5))
            Button { model.onSettings?() } label: { Image(systemName: "slider.horizontal.3").frame(width: 34, height: 34) }
                .help("Настройки · ⌘,").accessibilityLabel("Настройки").accessibilityIdentifier("settings-button").launcherInteractionRegion()
            Button { model.onDismiss?() } label: { Image(systemName: "xmark").frame(width: 34, height: 34) }
                .help("Скрыть · Esc").accessibilityLabel("Скрыть Launchpad").accessibilityIdentifier("hide-button").launcherInteractionRegion()
        }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.8))
    }
    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.55))
            TextField("Поиск приложений", text: $model.searchText)
                .textFieldStyle(.plain).font(.system(size: 18)).focused($searchFocused)
                .accessibilityIdentifier("app-search")
                .onSubmit { model.activateSelection() }
            if !model.searchText.isEmpty {
                Button { model.searchText = ""; searchFocused = true } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .buttonStyle(.plain).accessibilityLabel("Очистить поиск")
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(width: 420)
        .launcherInteractionRegion()
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(searchFocused ? 0.3 : 0.12), lineWidth: 1))
    }
    private var footer: some View {
        HStack {
            Group {
                if model.drag != nil {
                    Text(model.folderCandidate != nil ? "Отпустите, чтобы поместить в папку" : "К краю — на другую страницу · Esc — отмена")
                } else if !model.catalogIssues.isEmpty {
                    Button { model.onSettings?() } label: { Label("Не все источники доступны", systemImage: "exclamationmark.circle") }.buttonStyle(.plain).launcherInteractionRegion()
                } else {
                    Text(model.isSearching ? "↵ Открыть · Esc Очистить" : "Перетащите приложения, чтобы организовать их")
                }
            }.font(.caption).foregroundStyle(.white.opacity(0.45)).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Button { model.changePage(-1) } label: { Image(systemName: "chevron.left").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .disabled(model.currentPage == 0).accessibilityLabel("Предыдущая страница").accessibilityIdentifier("previous-page").launcherInteractionRegion()
                if model.pageCount <= 12 {
                    HStack(spacing: 2) {
                        ForEach(0..<model.pageCount, id: \.self) { page in
                            Button { model.changePage(page - model.currentPage) } label: {
                                Circle().fill(.white.opacity(page == model.currentPage ? 0.95 : 0.25))
                                    .frame(width: 7, height: 7).frame(width: 28, height: 28).contentShape(Rectangle())
                            }.accessibilityLabel("Страница \(page + 1)").accessibilityIdentifier("page-\(page)")
                                .accessibilityValue(page == model.currentPage ? "Текущая" : "").launcherInteractionRegion()
                        }
                    }
                } else { Text("\(model.currentPage + 1) / \(model.pageCount)").monospacedDigit() }
                Button { model.changePage(1) } label: { Image(systemName: "chevron.right").frame(width: 28, height: 28).contentShape(Rectangle()) }
                    .disabled(model.currentPage >= model.pageCount - 1).accessibilityLabel("Следующая страница").accessibilityIdentifier("next-page").launcherInteractionRegion()
            }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.75))
            HStack(spacing: 12) {
                Button { model.undo() } label: { Image(systemName: "arrow.uturn.backward") }.disabled(!model.canUndo).help("Отменить · ⌘Z").accessibilityLabel("Отменить изменение").launcherInteractionRegion()
                Menu {
                    Button("По алфавиту") { model.alphabetize() }
                    Button("Обновить приложения") { model.rescanApps() }
                    Button("Настройки…") { model.onSettings?() }
                } label: { Image(systemName: "ellipsis.circle") }.menuStyle(.borderlessButton).fixedSize().launcherInteractionRegion()
            }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.55)).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: 32)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}


/// Explicit hit regions for SwiftUI controls, whose backing views are not always NSControl.
final class LauncherInteractionRegionView: NSView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
private struct LauncherInteractionRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> LauncherInteractionRegionView { LauncherInteractionRegionView() }
    func updateNSView(_ view: LauncherInteractionRegionView, context: Context) {}
}
private extension View {
    func launcherInteractionRegion() -> some View { background(LauncherInteractionRegion()) }
}
