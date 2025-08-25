//
//  AppInfo.swift
//  Return Launchpad
//
//  Created by Сергей Шорин on 22.08.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct AppInfo: Identifiable, Hashable, Transferable, Codable {
    let id = UUID()
    let name: String
    let icon: NSImage
    let url: URL
    let bundleIdentifier: String
    
    // MARK: - Codable Implementation (для NSImage нужна специальная обработка)
    private enum CodingKeys: String, CodingKey {
        case name, url, iconData, bundleIdentifier
        // id исключен из кодирования, так как генерируется автоматически
    }
    
    init(name: String, icon: NSImage, url: URL, bundleIdentifier: String) {
        self.name = name
        self.icon = icon
        self.url = url
        self.bundleIdentifier = bundleIdentifier
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(URL.self, forKey: .url)
        bundleIdentifier = try container.decode(String.self, forKey: .bundleIdentifier)
        
        let iconData = try container.decode(Data.self, forKey: .iconData)
        guard let decodedIcon = NSImage(data: iconData) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid icon data")
            )
        }
        icon = decodedIcon
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(bundleIdentifier, forKey: .bundleIdentifier)
        
        guard let iconData = icon.tiffRepresentation else {
            throw EncodingError.invalidValue(icon, 
                EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Cannot encode icon to data")
            )
        }
        try container.encode(iconData, forKey: .iconData)
    }
    
    // MARK: - Transferable Protocol Implementation
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .appInfo)
    }
    
    // MARK: - Hashable Implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(url.path) // Используем путь как уникальный идентификатор
    }
    
    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.url.path == rhs.url.path
    }
}

// MARK: - Custom UTType for AppInfo
extension UTType {
    static let appInfo = UTType(exportedAs: "com.returnlaunchpad.appinfo")
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
                          let bundleId = bundle.bundleIdentifier,
                          let iconName = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String,
                          let iconPath = bundle.path(forResource: iconName, ofType: "icns"),
                          let icon = NSImage(contentsOfFile: iconPath)
                    else {
                        // Если не удалось получить иконку стандартным путем, берем ее из Workspace
                        let genericIcon = NSWorkspace.shared.icon(forFile: url.path)
                        let name = url.deletingPathExtension().lastPathComponent
                        // Пытаемся получить bundleIdentifier даже для generic случая
                        let bundleId = Bundle(url: url)?.bundleIdentifier ?? url.deletingPathExtension().lastPathComponent
                        foundApps.append(AppInfo(name: name, icon: genericIcon, url: url, bundleIdentifier: bundleId))
                        continue
                    }

                    foundApps.append(AppInfo(name: appName, icon: icon, url: url, bundleIdentifier: bundleId))
                }
            }
        }
        return foundApps
    }
}
