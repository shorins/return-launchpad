//
//  AppManager.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

// AppManager.swift
import Foundation

class AppManager: ObservableObject {
    @Published var apps: [AppInfo] = []
    private var appScanner = AppScanner()

    init() {
        // Просто сканируем приложения при создании объекта
        self.apps = appScanner.scanApps()
    }
}
