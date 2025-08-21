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
                        // Клик на фон теперь полностью закрывает приложение
                        NSApplication.shared.terminate(nil)
                    }

                VStack(spacing: 0) {
                    // Поле для поиска
                    TextField("Найти приложение...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .font(.title2)
                        .padding()
                        .background(Color.black.opacity(0.25))
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        .padding(.bottom, 15)
                        .frame(maxWidth: 450)
                        .onChange(of: searchText) { oldValue, newValue in
                            currentPage = 0 // Сбрасываем страницу при новом поиске
                        }

                    // Проверяем, есть ли что показывать
                    if !filteredApps.isEmpty {
                        let itemsPerPage = calculateItemsPerPage(geometry: geometry, totalApps: filteredApps.count)
                        let pageCount = (filteredApps.count + itemsPerPage - 1) / itemsPerPage
                        
                        let pageApps = appsForPage(currentPage, itemsPerPage: itemsPerPage)
                        
                        // Сетка с иконками
                        HStack {
                            Spacer()
                            LazyVGrid(columns: createGridColumns(geometry: geometry, totalItems: pageApps.count), spacing: 20) {
                                ForEach(pageApps) { app in
                                    appIconView(app: app)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                        .animation(.easeInOut(duration: 0.2), value: filteredApps)
                        
                        Spacer() // Прижимает навигацию к низу
                        
                        // Блок навигации по страницам
                        if pageCount > 1 {
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

    /// Вспомогательная View для отображения одной иконки
    private func appIconView(app: AppInfo) -> some View {
        VStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)

            Text(app.name)
                .font(.caption)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                .frame(height: 32) // Фиксированная высота для текста
        }
        .frame(width: 120, height: 120) // Фиксированный размер контейнера
        .padding(10)
        .background(hoverId == app.id ? Color.white.opacity(0.2) : Color.clear)
        .cornerRadius(15)
        .scaleEffect(hoverId == app.id ? 1.05 : 1.0)
        .onHover { isHovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                hoverId = isHovering ? app.id : nil
            }
        }
        .onTapGesture {
            NSWorkspace.shared.open(app.url)
            NSApplication.shared.terminate(nil) // Закрываем лаунчпад после запуска
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
