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
    
    private var appScanner = AppScanner()
    private var orderManager = AppOrderManager()
    
    init() {
        loadApps()
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
        let sortedApps = orderManager.sortApps(apps)
        DispatchQueue.main.async {
            self.apps = sortedApps
        }
    }
    
    /// Перемещает приложение с одной позиции на другую
    func moveApp(from sourceIndex: Int, to destinationIndex: Int) {
        let reorderedApps = orderManager.moveApp(from: sourceIndex, to: destinationIndex, in: apps)
        DispatchQueue.main.async {
            self.apps = reorderedApps
            self.hasNewApps = false // Сбрасываем флаг после пользовательского действия
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
            self.hasNewApps = false
        }
    }
    
    /// Включает пользовательский порядок
    func enableCustomOrder() {
        orderManager.enableCustomOrder()
    }
    
    /// Возвращает статистику упорядочивания
    func getOrderingStats() -> (customOrder: Int, newApps: Int, total: Int) {
        return orderManager.getOrderingStats(for: apps)
    }
    
    /// Проверяет, включен ли пользовательский порядок
    var isCustomOrderEnabled: Bool {
        return orderManager.isCustomOrderEnabled
    }
}
