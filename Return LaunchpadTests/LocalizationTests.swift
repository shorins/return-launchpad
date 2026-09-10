import XCTest
@testable import Return_Launchpad

@MainActor
final class LocalizationTests: XCTestCase {
    func testSystemUsesPrimaryLanguageAndFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["ru-RU", "en"]), "ru")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["ru_BY"]), "ru")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["fr-FR", "ru"]), "en")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: ["en-US", "ru"]), "en")
        XCTAssertEqual(AppLanguage.system.resolvedCode(preferredLanguages: []), "en")
        XCTAssertEqual(AppLanguage.russian.resolvedCode(preferredLanguages: ["en"]), "ru")
        XCTAssertEqual(AppLanguage.english.resolvedCode(preferredLanguages: ["ru"]), "en")
    }

    func testBothLanguageResourcesAreBundled() {
        XCTAssertEqual(L10n.text("Search apps", languageCode: "ru"), "Поиск приложений")
        XCTAssertEqual(L10n.text("Search apps", languageCode: "en"), "Search apps")
        XCTAssertEqual(L10n.text("Settings — Return Launchpad", languageCode: "ru"), "Настройки — Return Launchpad")
    }

    func testLanguageChoicePersistsAndUpdatesLocalization() {
        let name = UUID().uuidString
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name); L10n.setLanguage(.system) }
        let preferences = LauncherPreferences(defaults: defaults)
        XCTAssertEqual(preferences.language, .system)
        var changes = 0
        preferences.onLanguageChange = { changes += 1 }
        preferences.language = .russian
        XCTAssertEqual(L10n.text("New folder"), "Новая папка")
        XCTAssertEqual(LauncherPreferences(defaults: defaults).language, .russian)
        preferences.language = .english
        XCTAssertEqual(L10n.text("New folder"), "New folder")
        XCTAssertEqual(LauncherPreferences(defaults: defaults).language, .english)
        XCTAssertEqual(changes, 2)
    }
}
