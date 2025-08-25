//
//  ContentView.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appManager: AppManager
    @State private var searchText: String = ""
    @State private var hoverId: UUID?
    @State private var currentPage: Int = 0
    @FocusState private var isSearchFocused: Bool
    
    // Drag & Drop состояния - Pure iPhone style
    @State private var draggedItem: AppInfo?
    @State private var isInDragMode: Bool = false
    @State private var draggedItemOriginalIndex: Int?
    @State private var targetDropIndex: Int?  // Where we want to drop
    @State private var stablePageApps: [AppInfo] = []  // Stable layout during drag
    @State private var dropAnimationOffset: CGSize = .zero

    // Фильтрует приложения на основе текста в поиске
    private var filteredApps: [AppInfo] {
        if searchText.isEmpty {
            return appManager.apps
        } else {
            return appManager.apps.filter {
                $0.name.lowercased().contains(searchText.lowercased())
            }
        }
    }

    // Основной UI
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Фон с эффектом размытия
                VisualEffectBlur()
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        // Если поиск активен, просто убираем фокус
                        if isSearchFocused {
                            isSearchFocused = false
                        } else {
                            // Если поиск не активен, закрываем приложение
                            NSApplication.shared.terminate(nil)
                        }
                    }

                VStack(spacing: 0) {
                    // Поле для поиска
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            TextField("Найти приложение...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .font(.title2)
                                .padding()
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(12)
                                .frame(maxWidth: 450)
                                .focused($isSearchFocused)
                                .onChange(of: searchText) { oldValue, newValue in
                                    currentPage = 0 // Сбрасываем страницу при новом поиске
                                }
                            
                            // Индикатор режима упорядочивания
                            if appManager.isCustomOrderEnabled || appManager.hasNewApps {
                                HStack(spacing: 12) {
                                    if appManager.isCustomOrderEnabled {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.up.arrow.down")
                                            Text("Пользовательский порядок")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue.opacity(0.9))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    
                                    if appManager.hasNewApps {
                                        let stats = appManager.getOrderingStats()
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus.circle")
                                            Text("Новых: \(stats.newApps)")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.green.opacity(0.9))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.green.opacity(0.2))
                                        .cornerRadius(8)
                                    }
                                    
                                    // Кнопка сброса к алфавитному порядку
                                    if appManager.isCustomOrderEnabled {
                                        Button("Алфавит") {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                appManager.resetToAlphabeticalOrder()
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.8))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.3))
                                        .cornerRadius(8)
                                        .buttonStyle(.plain)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        Spacer()
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 15)

                    // Проверяем, есть ли что показывать
                    if !filteredApps.isEmpty {
                        let itemsPerPage = calculateItemsPerPage(geometry: geometry, totalApps: filteredApps.count)
                        let pageCount = (filteredApps.count + itemsPerPage - 1) / itemsPerPage
                        
                        let pageApps = appsForPage(currentPage, itemsPerPage: itemsPerPage)
                        
                        // Сетка с иконками - Professional drag & drop with insertion points
                        HStack {
                            Spacer()
                            dragDropGridView(pageApps: pageApps, geometry: geometry, itemsPerPage: itemsPerPage)
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                        .animation(.easeInOut(duration: 0.2), value: filteredApps)
                        
                        // Подсказка о перетаскивании
                        if !appManager.isCustomOrderEnabled && searchText.isEmpty && !isInDragMode {
                            Text("Перетащите иконки, чтобы изменить порядок")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                                .padding(.top, 8)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        
                        Spacer() // Прижимает навигацию к низу
                        
                        // Блок навигации по страницам
                        if pageCount > 1 {
                            HStack {
                                Spacer()
                                HStack {
                                    Button(action: { if currentPage > 0 { currentPage -= 1 } }) {
                                        Image(systemName: "chevron.left")
                                    }.disabled(currentPage == 0)
                                    
                                    Text("\(currentPage + 1) из \(pageCount)")
                                        .font(.body).foregroundColor(.white.opacity(0.8))
                                    
                                    Button(action: { if currentPage < pageCount - 1 { currentPage += 1 } }) {
                                        Image(systemName: "chevron.right")
                                    }.disabled(currentPage >= pageCount - 1)
                                }
                                .buttonStyle(.plain)
                                .font(.title2)
                                .padding()
                                .background(Color.black.opacity(0.2))
                                .cornerRadius(15)
                                Spacer()
                            }
                            .padding(.bottom, 20)
                        }
                        
                    } else {
                        // Сообщение, если ничего не найдено
                        Spacer()
                        Text("Ничего не найдено")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                }
            }
            .background(KeyboardHandler(currentPage: $currentPage, pageCount: { () -> Int in
                if filteredApps.isEmpty { return 0 }
                let itemsPerPage = calculateItemsPerPage(geometry: geometry, totalApps: filteredApps.count)
                return (filteredApps.count + itemsPerPage - 1) / itemsPerPage
            }, isSearchFocused: Binding(
                get: { isSearchFocused },
                set: { _ in } // Only read access needed
            )))
        }
        .onAppear {
            // Этот блок настраивает окно, чтобы оно было полноэкранным и поверх всего
            if let window = NSApplication.shared.windows.first {
                window.level = .floating
                window.setFrame(NSScreen.main!.frame, display: true)
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
    }

    /// Pure iPhone-style drag & drop grid - each icon position is a drop target
    private func dragDropGridView(pageApps: [AppInfo], geometry: GeometryProxy, itemsPerPage: Int) -> some View {
        let columns = createGridColumns(geometry: geometry, totalItems: pageApps.count)
        let itemsPerRow = columns.count
        
        // Use stable layout during drag - no complex flowing, just stable positions
        let displayApps = isInDragMode ? stablePageApps : pageApps
        
        return VStack(spacing: 20) {
            ForEach(0..<Int(ceil(Double(displayApps.count) / Double(itemsPerRow))), id: \.self) { rowIndex in
                HStack(spacing: 20) {
                    ForEach(0..<itemsPerRow, id: \.self) { colIndex in
                        let appIndex = rowIndex * itemsPerRow + colIndex
                        
                        // Each position is a direct drop target - true iPhone style
                        if appIndex < displayApps.count {
                            let app = displayApps[appIndex]
                            
                            appIconView(app: app)
                                .offset(dropAnimationOffset)
                                .onDrag {
                                    print("🎯 DRAG STARTED: \(app.name) at index \(appIndex)")
                                    draggedItem = app
                                    draggedItemOriginalIndex = appIndex
                                    stablePageApps = pageApps  // Capture stable layout
                                    isInDragMode = true
                                    dropAnimationOffset = .zero
                                    return NSItemProvider(object: app.bundleIdentifier as NSString)
                                }
                                .onDrop(of: [.text], delegate: PureIPhoneDropDelegate(
                                    targetIndex: appIndex,
                                    app: app,
                                    displayApps: displayApps,
                                    appManager: appManager,
                                    draggedItem: $draggedItem,
                                    draggedItemOriginalIndex: $draggedItemOriginalIndex,
                                    isInDragMode: $isInDragMode,
                                    stablePageApps: $stablePageApps,
                                    dropAnimationOffset: $dropAnimationOffset,
                                    currentPage: currentPage,
                                    itemsPerPage: itemsPerPage  // ✅ ИСПРАВЛЕНО: используем переданный параметр
                                ))
                                .opacity(draggedItem?.id == app.id ? 0.1 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggedItem?.id)
                                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: dropAnimationOffset)
                        } else {
                            // Empty space for incomplete rows  
                            Spacer()
                                .frame(width: 140, height: 120)
                        }
                    }
                }
            }
        }
    }
    

    

    

    
    private func appIconView(app: AppInfo) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .opacity(draggedItem?.id == app.id ? 0.5 : 1.0) // Прозрачность при перетаскивании

            Text(app.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(height: 32)
        }
        .frame(width: 120, height: 120)
        .padding(10)
        .background(hoverId == app.id ? Color.white.opacity(0.2) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(isInDragMode ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .cornerRadius(15)
        .scaleEffect(hoverId == app.id ? 1.05 : 1.0)
        .rotationEffect(.degrees(draggedItem?.id == app.id ? 5 : 0))
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: draggedItem?.id)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: hoverId)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isInDragMode)
        .onHover { isHovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                hoverId = isHovering ? app.id : nil
            }
        }
        .onTapGesture {
            if !isInDragMode {
                NSWorkspace.shared.open(app.url)
                NSApplication.shared.terminate(nil)
            }
        }
        .onChange(of: draggedItem) { oldValue, newValue in
            if newValue == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInDragMode = false
                }
            }
        }
    }
    
    /// Создает колонки для сетки на основе размера экрана
    private func createGridColumns(geometry: GeometryProxy, totalItems: Int? = nil) -> [GridItem] {
        let availableWidth = geometry.size.width - 80 // Учитываем горизонтальные отступы
        let itemWidth: CGFloat = 140 // Ширина одной иконки с отступами
        let spacing: CGFloat = 20
        
        let maxColumns = max(1, Int((availableWidth + spacing) / (itemWidth + spacing)))
        
        // Если указано количество элементов, адаптируем количество колонок
        if let totalItems = totalItems {
            // Для маленьких результатов поиска используем меньше колонок для центрирования
            let columns = min(maxColumns, totalItems)
            // Используем фиксированный размер вместо .flexible() для сохранения одинаковых отступов
            return Array(repeating: GridItem(.fixed(itemWidth), spacing: spacing), count: columns)
        }
        
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: maxColumns)
    }
    
    /// Рассчитывает, сколько иконок помещается на одной странице
    private func calculateItemsPerPage(geometry: GeometryProxy, totalApps: Int) -> Int {
        // Высота поля поиска + отступы
        let searchAreaHeight: CGFloat = 95
        // Высота навигации + отступы (всегда резервируем место для пагинации)
        let navigationHeight: CGFloat = 80
        // Вертикальные отступы сетки
        let gridPadding: CGFloat = 40
        
        let availableHeight = geometry.size.height - searchAreaHeight - navigationHeight - gridPadding
        let availableWidth = geometry.size.width - 80 // Горизонтальные отступы
        
        // Размер одной иконки с учетом отступов и текста
        let itemHeight: CGFloat = 120 // 80 (иконка) + 20 (текст) + 20 (отступы)
        let itemWidth: CGFloat = 140
        let spacing: CGFloat = 20
        
        let columns = max(1, Int((availableWidth + spacing) / (itemWidth + spacing)))
        let rows = max(1, Int((availableHeight + spacing) / (itemHeight + spacing)))
        
        // Убираем один ряд если получается больше 1 страницы, чтобы гарантированно оставить место для навигации
        let itemsPerPage = columns * rows
        
        if totalApps > itemsPerPage {
            // Если будет больше одной страницы, убираем последний ряд
            return max(columns, columns * (rows - 1))
        }
        
        return itemsPerPage
    }
    
    /// Возвращает срез массива приложений для конкретной страницы
    private func appsForPage(_ page: Int, itemsPerPage: Int) -> [AppInfo] {
        let startIndex = page * itemsPerPage
        let endIndex = min(startIndex + itemsPerPage, filteredApps.count)
        
        if startIndex >= endIndex { return [] }
        
        return Array(filteredApps[startIndex..<endIndex])
    }
}

/// Обработчик клавиатурных событий для навигации
struct KeyboardHandler: NSViewRepresentable {
    @Binding var currentPage: Int
    let pageCount: () -> Int
    @Binding var isSearchFocused: Bool
    
    func makeNSView(context: Context) -> NSView {
        let view = KeyboardEventView()
        view.onKeyDown = { event in
            // Отключаем навигацию клавишами, если поиск активен
            guard !isSearchFocused else { return }
            
            let totalPages = pageCount()
            guard totalPages > 1 else { return }
            
            switch event.keyCode {
            case 123: // Левая стрелка
                if currentPage > 0 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage -= 1
                    }
                }
            case 124: // Правая стрелка
                if currentPage < totalPages - 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage += 1
                    }
                }
            default:
                break
            }
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Кастомная NSView для обработки клавиатурных событий
class KeyboardEventView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        onKeyDown?(event)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}

/// Обертка для нативного эффекта размытия фона
struct VisualEffectBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Pure iPhone-style Drop Delegate - drop directly on any icon position
struct PureIPhoneDropDelegate: SwiftUI.DropDelegate {
    let targetIndex: Int
    let app: AppInfo
    let displayApps: [AppInfo]
    let appManager: AppManager
    @Binding var draggedItem: AppInfo?
    @Binding var draggedItemOriginalIndex: Int?
    @Binding var isInDragMode: Bool
    @Binding var stablePageApps: [AppInfo]
    @Binding var dropAnimationOffset: CGSize
    let currentPage: Int
    let itemsPerPage: Int
    
    func dropEntered(info: DropInfo) {
        // Only update target if it's different from current position
        guard let draggedItem = draggedItem,
              draggedItem.id != app.id else { return }
        
        print("🎯 iPhone DROP ENTERED: \(app.name) at position \(targetIndex)")
        // No additional state needed - visual flow happens automatically
    }
    
    func dropExited(info: DropInfo) {
        print("🚪 iPhone DROP EXITED: \(app.name)")
    }
    
    func performDrop(info: DropInfo) -> Bool {
        print("📍 iPhone PURE DROP on \(app.name) at position \(targetIndex)")
        
        guard let draggedItem = draggedItem,
              let originalIndex = draggedItemOriginalIndex,
              draggedItem.id != app.id else {
            print("❌ Invalid drop - same app or missing data")
            return false
        }
        
        print("🔄 iPhone Moving \(draggedItem.name) from local index \(originalIndex) to local index \(targetIndex)")
        
        // КРИТИЧЕСКОЕ ИСПРАВЛЕНИЕ: Правильный расчет глобальных индексов
        // Получаем стартовый индекс текущей страницы в общем массиве
        let pageStartIndex = currentPage * itemsPerPage
        let globalOriginalIndex = pageStartIndex + originalIndex
        let globalTargetIndex = pageStartIndex + targetIndex
        
        print("🌍 CRITICAL INDEX DEBUG:")
        print("   • Current page: \(currentPage)")
        print("   • Items per page (CONSISTENT): \(itemsPerPage)")
        print("   • Page start index: \(pageStartIndex)")
        print("   • Local original: \(originalIndex) → Global: \(globalOriginalIndex)")
        print("   • Local target: \(targetIndex) → Global: \(globalTargetIndex)")
        print("   • Total apps in manager: \(appManager.apps.count)")
        print("   • Apps on this page: \(displayApps.count)")
        print("   • Expected range: \(pageStartIndex)..<\(pageStartIndex + itemsPerPage)")
        
        // Дополнительная проверка: убеждаемся, что перемещение имеет смысл
        if originalIndex == targetIndex {
            print("⚠️ Same position drop - no action needed")
            // Сбрасываем состояние drag без изменений
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.draggedItem = nil
                self.draggedItemOriginalIndex = nil
                isInDragMode = false
                stablePageApps = []
            }
            return true
        }
        
        // Add drop animation from mouse position
        let mouseLocation = info.location
        dropAnimationOffset = CGSize(width: mouseLocation.x - 70, height: mouseLocation.y - 60)
        
        // Perform the actual move with boundary checking
        if globalOriginalIndex < appManager.apps.count && globalTargetIndex < appManager.apps.count {
            print("✅ EXECUTING iPhone appManager.moveApp(\(globalOriginalIndex) → \(globalTargetIndex))")
            appManager.moveApp(from: globalOriginalIndex, to: globalTargetIndex)
        } else {
            print("❌ Invalid global indices: source=\(globalOriginalIndex), target=\(globalTargetIndex), total=\(appManager.apps.count)")
        }
        
        // Animate to final position then reset
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            dropAnimationOffset = .zero
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.draggedItem = nil
            self.draggedItemOriginalIndex = nil
            isInDragMode = false
            stablePageApps = []  // Clear stable layout
        }
        
        return true
    }
}
