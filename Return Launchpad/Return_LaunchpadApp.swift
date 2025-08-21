//
//  Return_LaunchpadApp.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

import SwiftUI

@main
struct CustomLaunchpadApp: App {
    // Создаем единственный экземпляр AppManager
    @StateObject private var appManager = AppManager()

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
