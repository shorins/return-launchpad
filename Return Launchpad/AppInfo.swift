//
//  AppInfo.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

import SwiftUI

struct AppInfo: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: NSImage
    let url: URL
}

// AppScanner.swift - Сервис для поиска приложений
import SwiftUI

class AppScanner {
    func scanApps() -> [AppInfo] {
        var foundApps: [AppInfo] = []
        let fileManager = FileManager.default
        // URL-ы директорий для поиска
        let appDirectories = [
            "/Applications",
            fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first?.path
        ].compactMap { $0 }

        for dir in appDirectories {
            if let appUrls = try? fileManager.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                for url in appUrls where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
                          let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
                          let iconPath = bundle.path(forResource: iconName, ofType: "icns"),
                          let icon = NSImage(contentsOfFile: iconPath)
                    else {
                        // Если не удалось получить иконку стандартным путем, берем ее из Workspace
                        let genericIcon = NSWorkspace.shared.icon(forFile: url.path)
                        let name = url.deletingPathExtension().lastPathComponent
                        foundApps.append(AppInfo(name: name, icon: genericIcon, url: url))
                        continue
                    }

                    foundApps.append(AppInfo(name:appName, icon: icon, url: url))
                }
            }
        }
        return foundApps.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }
}
