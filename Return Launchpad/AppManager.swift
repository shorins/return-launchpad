//
//  AppManager.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

// AppManager.swift
import Foundation
import SwiftUI

class AppManager: ObservableObject {
    @Published var apps: [AppInfo] = []
    @Published var hasNewApps: Bool = false
    @Published var isCustomOrderEnabled: Bool = false
    
    private var appScanner = AppScanner()
    private var orderManager = AppOrderManager()
    
    init() {
        PersistenceLogger.shared.log(.info, "🔄 AppManager Instance Created (ID: \(ObjectIdentifier(self)))")
        PersistenceLogger.shared.log(.info, "🔄 AppOrderManager Instance: \(ObjectIdentifier(orderManager))")
        
        // Sync the initial state
        self.isCustomOrderEnabled = orderManager.isCustomOrderEnabled
        
        loadApps()
        
        // Проверяем, что пользовательская конфигурация правильно загружена
        let verification = orderManager.verifyInitialization()
        print("[AppManager] Инициализация завершена: customOrder=\(verification.customOrderEnabled), savedItems=\(verification.savedItemsCount)")
        // @AppStorage в AppOrderManager автоматически обновляет UI
    }
    
    /// Загружает и сортирует приложения
    private func loadApps() {
        print("[AppManager] Начинаем загрузку приложений...")
        let scannedApps = appScanner.scanApps()
        print("[AppManager] Найдено \(scannedApps.count) приложений")
        print("[AppManager] Режим пользовательского порядка: \(orderManager.isCustomOrderEnabled)")
        
        let sortedApps = orderManager.sortApps(scannedApps)
        print("[AppManager] Приложения отсортированы, первые 3: \(sortedApps.prefix(3).map { $0.name })")
        
        DispatchQueue.main.async {
            self.apps = sortedApps
            self.hasNewApps = self.orderManager.hasNewApps(in: scannedApps)
            print("[AppManager] UI обновлен, итоговый порядок: \(self.apps.prefix(3).map { $0.name })")
        }
    }
    
    /// Обновляет порядок приложений без повторного сканирования
    private func refreshAppOrder() {
        let sortedApps = orderManager.applyCurrentOrder(apps)
        DispatchQueue.main.async {
            self.apps = sortedApps
            print("[AppManager] Порядок обновлен, первые 3: \(self.apps.prefix(3).map { $0.name })")
        }
    }
    
    /// Перемещает приложение с одной позиции на другую
    func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
        PersistenceLogger.shared.logDragDrop("MANAGER_START", fromIndex: sourceIndex, toIndex: destinationIndex, appName: apps[sourceIndex].name)
        PersistenceLogger.shared.log(.info, "🔍 BEFORE moveApp: isCustomOrderEnabled=\(orderManager.isCustomOrderEnabled)")
        
        let reorderedApps = orderManager.moveApp(from: sourceIndex, to: destinationIndex, in: apps)
        
        PersistenceLogger.shared.log(.info, "🔍 AFTER moveApp: isCustomOrderEnabled=\(orderManager.isCustomOrderEnabled)")
        PersistenceLogger.shared.logDragDrop("MANAGER_COMPLETE", appName: apps[sourceIndex].name)
        
        DispatchQueue.main.async {
            self.apps = reorderedApps
            self.isCustomOrderEnabled = self.orderManager.isCustomOrderEnabled // Sync the UI state
            self.hasNewApps = false // Сбрасываем флаг после пользовательского действия
            PersistenceLogger.shared.log(.info, "🔍 UI Updated: apps count=\(self.apps.count)")
        }
    }
    
    /// Пересканирует приложения (например, при обновлении системы)
    func rescanApps() {
        loadApps()
    }
    
    /// Возвращает к алфавитному порядку
    func resetToAlphabeticalOrder() {
        orderManager.resetToAlphabetical()
        refreshAppOrder()
        DispatchQueue.main.async {
            self.isCustomOrderEnabled = self.orderManager.isCustomOrderEnabled
            self.hasNewApps = false
        }
    }
    
    /// Включает пользовательский порядок
    func enableCustomOrder() {
        orderManager.enableCustomOrder()
        self.isCustomOrderEnabled = orderManager.isCustomOrderEnabled
    }
    
    /// Возвращает статистику упорядочивания
    func getOrderingStats() -> (customOrder: Int, newApps: Int, total: Int) {
        return orderManager.getOrderingStats(for: apps)
    }
}
