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
    /// Логгер для отладки persistence операций
    private let logger = PersistenceLogger.shared
    /// Многоуровневая стратегия UserDefaults для максимальной совместимости
    private let persistenceStrategy: PersistenceStrategy
    
    /// Уникальный идентификатор экземпляра
    private let instanceId = UUID()
    
    /// Имя текущего пользователя для создания уникальных ключей
    private let currentUser = NSUserName()
    
    /// Ключи для хранения данных с учетом пользователя
    private var customOrderEnabledKey: String { "\(currentUser)_isCustomOrderEnabled" }
    private var userAppOrderKey: String { "\(currentUser)_userAppOrder" }
    
    /// Структура для управления стратегией persistence
    private struct PersistenceStrategy {
        let primary: UserDefaults
        let fallback: UserDefaults
        let description: String
        
        init() {
            // Попытка использовать app group (идеально для развития)
            if let appGroupDefaults = UserDefaults(suiteName: "group.shorins.return-launchpad") {
                self.primary = appGroupDefaults
                self.fallback = UserDefaults.standard
                self.description = "App Group + Standard fallback"
            } else {
                // Fallback на стандартные UserDefaults
                self.primary = UserDefaults.standard
                self.fallback = UserDefaults.standard
                self.description = "Standard UserDefaults only"
            }
        }
        
        func set(_ value: Any?, forKey key: String) {
            let logger = PersistenceLogger.shared
            logger.logUserDefaultsOperation("SET", key: key, value: value, storage: "primary")
            
            primary.set(value, forKey: key)
            primary.synchronize()
            
            // Дублируем в fallback для надежности
            if primary !== fallback {
                logger.logUserDefaultsOperation("SET_FALLBACK", key: key, value: value, storage: "fallback")
                fallback.set(value, forKey: key)
                fallback.synchronize()
            }
            
            logger.log(.info, "✅ Data written to both storages for key: \(key)")
        }
        
        func bool(forKey key: String) -> Bool {
            let logger = PersistenceLogger.shared
            
            // Сначала пробуем primary
            if primary.object(forKey: key) != nil {
                let value = primary.bool(forKey: key)
                logger.logUserDefaultsOperation("GET_PRIMARY", key: key, value: value, storage: "primary")
                return value
            }
            
            // Если в primary нет данных, пробуем fallback
            let fallbackValue = fallback.bool(forKey: key)
            logger.logUserDefaultsOperation("GET_FALLBACK", key: key, value: fallbackValue, storage: "fallback")
            return fallbackValue
        }
        
        func string(forKey key: String) -> String? {
            let logger = PersistenceLogger.shared
            
            // Сначала пробуем primary
            if let value = primary.string(forKey: key) {
                logger.logUserDefaultsOperation("GET_PRIMARY", key: key, value: value, storage: "primary")
                return value
            }
            
            // Если в primary нет данных, пробуем fallback
            if let fallbackValue = fallback.string(forKey: key) {
                logger.logUserDefaultsOperation("GET_FALLBACK", key: key, value: fallbackValue, storage: "fallback")
                return fallbackValue
            }
            
            logger.log(.warning, "⚠️ No data found for key: \(key) in any storage")
            return nil
        }
        
        /// Миграция данных между сторажами для обеспечения совместимости
        func migrateDataIfNeeded(enabledKey: String, orderKey: String) {
            // Проверяем, есть ли данные в fallback, которых нет в primary
            if primary !== fallback {
                if primary.object(forKey: enabledKey) == nil && fallback.object(forKey: enabledKey) != nil {
                    let migratedEnabled = fallback.bool(forKey: enabledKey)
                    primary.set(migratedEnabled, forKey: enabledKey)
                    print("[PersistenceStrategy] Мигрирован isCustomOrderEnabled: \(migratedEnabled)")
                }
                
                if primary.string(forKey: orderKey) == nil, let migratedOrder = fallback.string(forKey: orderKey) {
                    primary.set(migratedOrder, forKey: orderKey)
                    print("[PersistenceStrategy] Мигрирован userAppOrder: \(migratedOrder.count) символов")
                }
                
                primary.synchronize()
            }
        }
        
        /// Проверка целостности данных
        func validateData(enabledKey: String, orderKey: String) -> (isValid: Bool, issues: [String]) {
            var issues: [String] = []
            
            // Проверяем JSON строку
            if let orderJSON = string(forKey: orderKey), !orderJSON.isEmpty {
                if let data = orderJSON.data(using: .utf8) {
                    do {
                        _ = try JSONDecoder().decode([String].self, from: data)
                    } catch {
                        issues.append("Невалидный JSON в userAppOrder")
                    }
                } else {
                    issues.append("Не удается преобразовать userAppOrder в Data")
                }
            }
            
            return (isValid: issues.isEmpty, issues: issues)
        }
    }
    
    /// Включен ли пользовательский порядок (по умолчанию false - алфавитный)
    @Published var isCustomOrderEnabled: Bool = false {
        didSet {
            logger.log(.info, "💾 Instance \(instanceId.uuidString.prefix(8)) - Custom Order State Changed: \(oldValue) → \(isCustomOrderEnabled)")
            persistenceStrategy.set(isCustomOrderEnabled, forKey: customOrderEnabledKey)
            logger.log(.info, "✅ Instance \(instanceId.uuidString.prefix(8)) - Сохранено для пользователя \(currentUser): isCustomOrderEnabled=\(isCustomOrderEnabled)")
        }
    }
    
    /// Порядок приложений как JSON строка для группового хранения
    @Published private var userOrderJSON: String = "" {
        didSet {
            logger.log(.info, "📝 User Order JSON Changed: \(oldValue.count) → \(userOrderJSON.count) characters")
            persistenceStrategy.set(userOrderJSON, forKey: userAppOrderKey)
            logger.log(.info, "✅ Сохранен порядок для пользователя \(currentUser): \(userDefinedOrder.count) элементов")
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
        // Инициализируем стратегию persistence
        self.persistenceStrategy = PersistenceStrategy()
        
        // Логируем создание экземпляра
        PersistenceLogger.shared.log(.info, "🏢 AppOrderManager Instance Created: \(instanceId.uuidString.prefix(8))")
        
        // Выполняем миграцию данных для обеспечения совместимости
        persistenceStrategy.migrateDataIfNeeded(enabledKey: customOrderEnabledKey, orderKey: userAppOrderKey)
        
        // Проверяем целостность данных
        let validation = persistenceStrategy.validateData(enabledKey: customOrderEnabledKey, orderKey: userAppOrderKey)
        if !validation.isValid {
            print("[AppOrderManager] Обнаружены проблемы с данными: \(validation.issues.joined(separator: ", "))")
            // Очищаем поврежденные данные
            persistenceStrategy.set(false, forKey: customOrderEnabledKey)
            persistenceStrategy.set("", forKey: userAppOrderKey)
        }
        
        // Загружаем данные для текущего пользователя БЕЗ триггера didSet
        let savedOrderEnabled = persistenceStrategy.bool(forKey: customOrderEnabledKey)
        let savedOrderJSON = persistenceStrategy.string(forKey: userAppOrderKey) ?? ""
        
        // Устанавливаем значения напрямую, чтобы избежать сохранения во время загрузки
        self._isCustomOrderEnabled = Published(initialValue: savedOrderEnabled)
        self._userOrderJSON = Published(initialValue: savedOrderJSON)
        
        print("[AppOrderManager] Инициализация для пользователя \(currentUser):")
        print("[AppOrderManager] Persistence strategy: \(persistenceStrategy.description)")
        print("[AppOrderManager] Data validation: \(validation.isValid ? "OK" : "FIXED")")
        print("[AppOrderManager] isCustomOrderEnabled=\(isCustomOrderEnabled), количество сохраненных приложений: \(userDefinedOrder.count)")
        
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
        persistenceStrategy.set(isCustomOrderEnabled, forKey: customOrderEnabledKey)
        persistenceStrategy.set(userOrderJSON, forKey: userAppOrderKey)
        print("[AppOrderManager] Принудительное сохранение выполнено (стратегия: \(persistenceStrategy.description))")
    }
    
    /// Обработчик завершения приложения
    @objc private func appWillTerminate() {
        print("[AppOrderManager] Приложение завершается, сохраняем данные...")
        forceSave()
    }
    
    /// Включает пользовательский порядок (переключает с алфавитного)
    func enableCustomOrder() {
        logger.log(.info, "🔄 Instance \(instanceId.uuidString.prefix(8)) - enableCustomOrder() called, current: \(isCustomOrderEnabled)")
        isCustomOrderEnabled = true
        logger.log(.info, "🔄 Instance \(instanceId.uuidString.prefix(8)) - enableCustomOrder() complete, new: \(isCustomOrderEnabled)")
        // Данные автоматически сохраняются через didSet
    }
    
    /// Включает пользовательский порядок и сохраняет текущие позиции приложений
    func enableCustomOrderWithCurrentPositions(_ apps: [AppInfo]) {
        // Сначала сохраняем текущие позиции
        let currentOrder = apps.map { $0.bundleIdentifier }
        userDefinedOrder = currentOrder
        
        // Затем включаем пользовательский режим
        isCustomOrderEnabled = true
        
        print("[AppOrderManager] Включен пользовательский порядок с сохранением \(currentOrder.count) позиций")
        
        // Принудительно сохраняем данные
        forceSave()
    }
    
    /// Проверяет, что пользовательская конфигурация правильно загружена
    func verifyInitialization() -> (customOrderEnabled: Bool, savedItemsCount: Int) {
        let savedEnabled = persistenceStrategy.bool(forKey: customOrderEnabledKey)
        let savedJSON = persistenceStrategy.string(forKey: userAppOrderKey) ?? ""
        let savedCount = userDefinedOrder.count
        
        print("[AppOrderManager] Проверка инициализации:")
        print("[AppOrderManager] Persistence strategy: \(persistenceStrategy.description)")
        print("[AppOrderManager] Сохраненное состояние: isCustomOrderEnabled=\(savedEnabled)")
        print("[AppOrderManager] Текущее состояние: isCustomOrderEnabled=\(isCustomOrderEnabled)")
        print("[AppOrderManager] Количество сохраненных элементов: \(savedCount)")
        
        return (customOrderEnabled: isCustomOrderEnabled, savedItemsCount: savedCount)
    }
    
    /// Возвращает к алфавитному порядку
    func resetToAlphabetical() {
        isCustomOrderEnabled = false
        userDefinedOrder = []
        // Данные автоматически сохраняются через didSet
    }
    
    /// Применяет текущий порядок к существующему массиву приложений без пересканирования
    func applyCurrentOrder(_ apps: [AppInfo]) -> [AppInfo] {
        print("[AppOrderManager] applyCurrentOrder вызван для \(apps.count) приложений")
        return sortApps(apps)
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
        logger.logDragDrop("START \(instanceId.uuidString.prefix(8))", fromIndex: sourceIndex, toIndex: destinationIndex, appName: apps[sourceIndex].name)
        logger.log(.info, "🏢 Instance \(instanceId.uuidString.prefix(8)) - isCustomOrderEnabled BEFORE: \(isCustomOrderEnabled)")
        
        // Автоматически включаем пользовательский порядок при первом перетаскивании
        if !isCustomOrderEnabled {
            logger.log(.info, "⚡️ Instance \(instanceId.uuidString.prefix(8)) - Автоматическое включение пользовательского порядка")
            enableCustomOrder()
            logger.log(.info, "⚡️ Instance \(instanceId.uuidString.prefix(8)) - isCustomOrderEnabled AFTER enableCustomOrder: \(isCustomOrderEnabled)")
        }
        
        var reorderedApps = apps
        let movedApp = reorderedApps.remove(at: sourceIndex)
        reorderedApps.insert(movedApp, at: destinationIndex)
        
        // Обновляем пользовательский порядок
        let newOrder = reorderedApps.map { $0.bundleIdentifier }
        let oldOrderCount = userDefinedOrder.count
        userDefinedOrder = newOrder
        
        logger.logDragDrop("COMPLETE", appName: movedApp.name)
        logger.log(.info, "💾 Обновлен порядок: \(oldOrderCount) → \(newOrder.count) элементов")
        
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