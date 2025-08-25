//
//  AppOrderManager.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

import Foundation
import SwiftUI
import AppKit

/// Менеджер для управления пользовательским порядком приложений
class AppOrderManager: ObservableObject {
    /// UserDefaults для группы приложений
    private let appGroupDefaults = UserDefaults(suiteName: "group.shorins.return-launchpad") ?? UserDefaults.standard
    
    /// Имя текущего пользователя для создания уникальных ключей
    private let currentUser = NSUserName()
    
    /// Ключи для хранения данных с учетом пользователя
    private var customOrderEnabledKey: String { "\(currentUser)_isCustomOrderEnabled" }
    private var userAppOrderKey: String { "\(currentUser)_userAppOrder" }
    
    /// Включен ли пользовательский порядок (по умолчанию false - алфавитный)
    @Published var isCustomOrderEnabled: Bool = false {
        didSet {
            appGroupDefaults.set(isCustomOrderEnabled, forKey: customOrderEnabledKey)
            appGroupDefaults.synchronize() // Принудительная синхронизация
            print("[AppOrderManager] Сохранено для пользователя \(currentUser): isCustomOrderEnabled=\(isCustomOrderEnabled)")
        }
    }
    
    /// Порядок приложений как JSON строка для группового хранения
    @Published private var userOrderJSON: String = "" {
        didSet {
            appGroupDefaults.set(userOrderJSON, forKey: userAppOrderKey)
            appGroupDefaults.synchronize() // Принудительная синхронизация
            print("[AppOrderManager] Сохранен порядок для пользователя \(currentUser): \(userDefinedOrder.count) элементов")
        }
    }
    
    /// Порядок приложений, определенный пользователем (массив bundleIdentifier)
    private var userDefinedOrder: [String] {
        get {
            guard !userOrderJSON.isEmpty,
                  let data = userOrderJSON.data(using: .utf8),
                  let order = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return order
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                userOrderJSON = jsonString
            }
        }
    }
    
    init() {
        // Загружаем данные для текущего пользователя
        isCustomOrderEnabled = appGroupDefaults.bool(forKey: customOrderEnabledKey)
        userOrderJSON = appGroupDefaults.string(forKey: userAppOrderKey) ?? ""
        print("[AppOrderManager] Инициализация для пользователя \(currentUser):")
        print("[AppOrderManager] isCustomOrderEnabled=\(isCustomOrderEnabled), количество сохраненных приложений: \(userDefinedOrder.count)")
        print("[AppOrderManager] Используем групповое хранилище: group.shorins.return-launchpad")
        
        // Подписываемся на уведомления о завершении приложения
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
        
        // Настраиваем периодическое сохранение каждые 30 секунд
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
            self.forceSave()
        }
    }
    
    deinit {
        // Сохраняем данные при уничтожении объекта
        forceSave()
        NotificationCenter.default.removeObserver(self)
        print("[AppOrderManager] Объект уничтожен, данные сохранены")
    }
    
    /// Принудительное сохранение всех данных
    func forceSave() {
        appGroupDefaults.set(isCustomOrderEnabled, forKey: customOrderEnabledKey)
        appGroupDefaults.set(userOrderJSON, forKey: userAppOrderKey)
        appGroupDefaults.synchronize()
        print("[AppOrderManager] Принудительное сохранение выполнено")
    }
    
    /// Обработчик завершения приложения
    @objc private func appWillTerminate() {
        print("[AppOrderManager] Приложение завершается, сохраняем данные...")
        forceSave()
    }
    
    /// Включает пользовательский порядок (переключает с алфавитного)
    func enableCustomOrder() {
        isCustomOrderEnabled = true
        // Данные автоматически сохраняются через didSet
    }
    
    /// Возвращает к алфавитному порядку
    func resetToAlphabetical() {
        isCustomOrderEnabled = false
        userDefinedOrder = []
        // Данные автоматически сохраняются через didSet
    }
    
    /// Сортирует массив приложений согласно выбранному режиму
    func sortApps(_ apps: [AppInfo]) -> [AppInfo] {
        print("[AppOrderManager] sortApps вызван: isCustomOrderEnabled=\(isCustomOrderEnabled), userDefinedOrder.count=\(userDefinedOrder.count)")
        
        if !isCustomOrderEnabled || userDefinedOrder.isEmpty {
            // Алфавитный порядок (по умолчанию)
            print("[AppOrderManager] Используем алфавитный порядок")
            return apps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        }
        
        // Пользовательский порядок
        print("[AppOrderManager] Используем пользовательский порядок (сохранено \(userDefinedOrder.count) элементов)")
        return sortByUserOrder(apps)
    }
    
    /// Сортирует приложения по пользовательскому порядку
    private func sortByUserOrder(_ apps: [AppInfo]) -> [AppInfo] {
        var sortedApps: [AppInfo] = []
        var remainingApps = apps
        let currentOrder = userDefinedOrder
        
        // Сначала добавляем приложения в пользовательском порядке по bundleIdentifier
        for bundleId in currentOrder {
            if let index = remainingApps.firstIndex(where: { $0.bundleIdentifier == bundleId }) {
                sortedApps.append(remainingApps.remove(at: index))
            }
        }
        
        // Затем добавляем новые приложения (которых нет в пользовательском порядке) в алфавитном порядке
        let newApps = remainingApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
        sortedApps.append(contentsOf: newApps)
        
        // Обновляем пользовательский порядок, включая новые приложения
        updateUserOrderWithNewApps(sortedApps)
        
        return sortedApps
    }
    
    /// Обновляет пользовательский порядок, добавляя новые приложения в конец
    private func updateUserOrderWithNewApps(_ apps: [AppInfo]) {
        let newOrder = apps.map { $0.bundleIdentifier }
        if newOrder != userDefinedOrder {
            userDefinedOrder = newOrder
            // Данные автоматически сохраняются через didSet
        }
    }
    
    /// Перемещает приложение в новую позицию (для drag & drop)
    func moveApp(from sourceIndex: Int, to destinationIndex: Int, in apps: [AppInfo]) -> [AppInfo] {
        // Автоматически включаем пользовательский порядок при первом перетаскивании
        if !isCustomOrderEnabled {
            print("[AppOrderManager] Включаем пользовательский порядок")
            enableCustomOrder()
        }
        
        var reorderedApps = apps
        let movedApp = reorderedApps.remove(at: sourceIndex)
        reorderedApps.insert(movedApp, at: destinationIndex)
        
        // Обновляем пользовательский порядок
        let newOrder = reorderedApps.map { $0.bundleIdentifier }
        userDefinedOrder = newOrder
        print("[AppOrderManager] Сохранен новый порядок: \(newOrder.prefix(3))...") // Показываем первые 3 для краткости
        // Принудительно сохраняем данные после drag & drop
        forceSave()
        
        return reorderedApps
    }
    
    /// Возвращает индекс приложения в пользовательском порядке
    func getUserOrderIndex(for app: AppInfo) -> Int? {
        return userDefinedOrder.firstIndex(of: app.bundleIdentifier)
    }
    
    /// Проверяет, есть ли новые приложения, не включенные в пользовательский порядок
    func hasNewApps(in apps: [AppInfo]) -> Bool {
        let currentBundleIds = Set(apps.map { $0.bundleIdentifier })
        let savedBundleIds = Set(userDefinedOrder)
        return !currentBundleIds.isSubset(of: savedBundleIds)
    }
    
    /// Получает статистику порядка для отладки
    func getOrderingStats(for apps: [AppInfo]) -> (customOrder: Int, newApps: Int, total: Int) {
        let customOrderCount = userDefinedOrder.count
        let totalApps = apps.count
        let newAppsCount = totalApps - customOrderCount
        
        return (customOrder: customOrderCount, newApps: max(0, newAppsCount), total: totalApps)
    }
}