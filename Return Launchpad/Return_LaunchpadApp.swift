//
//  Return_LaunchpadApp.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

import SwiftUI
import AppKit

@main
struct CustomLaunchpadApp: App {
    // Создаем единственный экземпляр AppManager
    @StateObject private var appManager = AppManager()
    
    init() {
        // Логируем старт приложения
        PersistenceLogger.shared.logAppLifecycle("App Initialization Started")
        print("🔍 [RLPAD-DEBUG] [IMMEDIATE] App is starting up - this should appear in logs!")
        
        // Test logging with multiple approaches
        PersistenceLogger.shared.log(.critical, "CRITICAL TEST - App Starting")
        PersistenceLogger.shared.log(.info, "INFO TEST - App Starting")
        
        // Подписываемся на уведомления о завершении приложения
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            PersistenceLogger.shared.logAppLifecycle("App Will Terminate - Final Save")
            print("[CustomLaunchpadApp] Приложение завершается, сохраняем данные...")
            // Дополнительное сохранение через главное приложение
            UserDefaults.standard.synchronize()
            if let appGroupDefaults = UserDefaults(suiteName: "group.shorins.return-launchpad") {
                appGroupDefaults.synchronize()
            }
            PersistenceLogger.shared.logAppLifecycle("App Termination Complete")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Передаем appManager в наше ContentView
            ContentView()
                .environmentObject(appManager)
        }
        // Убираем стандартную рамку и заголовок окна
        .windowStyle(.hiddenTitleBar)
    }
}
