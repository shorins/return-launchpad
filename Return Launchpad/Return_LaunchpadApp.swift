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
        // Подписываемся на уведомления о завершении приложения
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            print("[CustomLaunchpadApp] Приложение завершается, сохраняем данные...")
            // Дополнительное сохранение через главное приложение
            UserDefaults.standard.synchronize()
            if let appGroupDefaults = UserDefaults(suiteName: "group.shorins.return-launchpad") {
                appGroupDefaults.synchronize()
            }
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
