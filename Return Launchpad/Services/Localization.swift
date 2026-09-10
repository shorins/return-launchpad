import Foundation
import Synchronization

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, russian, english
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return L10n.text("System")
        case .russian: return "Русский"
        case .english: return "English"
        }
    }
    func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        switch self {
        case .russian: return "ru"
        case .english: return "en"
        case .system:
            let primary = preferredLanguages.first?.lowercased().replacingOccurrences(of: "_", with: "-") ?? "en"
            return primary == "ru" || primary.hasPrefix("ru-") ? "ru" : "en"
        }
    }
}

/// Explicit resource bundles allow live language changes in both SwiftUI and AppKit.
/// A locked language code also makes background scanner error messages safe to localize.
enum L10n {
    private static let code = Mutex(AppLanguage.system.resolvedCode())
    private static let bundles: [String: Bundle] = ["en", "ru"].reduce(into: [:]) { result, language in
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) {
            result[language] = bundle
        }
    }
    static var languageCode: String { code.withLock { $0 } }
    static func setLanguage(_ language: AppLanguage) {
        let resolved = language.resolvedCode()
        code.withLock { $0 = resolved }
    }
    static func text(_ key: String, languageCode: String? = nil) -> String {
        let language = languageCode ?? self.languageCode
        return bundles[language]?.localizedString(forKey: key, value: key, table: nil) ?? key
    }
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: Locale(identifier: languageCode), arguments: arguments)
    }
}
