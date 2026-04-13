import XCTest
@testable import Maurice

final class LocalizationTests: XCTestCase {

    private var savedAppLanguage: String?
    private var savedAppleLanguages: [String]?

    override func setUp() {
        super.setUp()
        savedAppLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        savedAppleLanguages = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        UserDefaults.standard.removeObject(forKey: "appLanguage")
        UserDefaults.standard.removeObject(forKey: "AppleLanguages")
    }

    override func tearDown() {
        if let lang = savedAppLanguage {
            UserDefaults.standard.set(lang, forKey: "appLanguage")
        } else {
            UserDefaults.standard.removeObject(forKey: "appLanguage")
        }
        if let langs = savedAppleLanguages {
            UserDefaults.standard.set(langs, forKey: "AppleLanguages")
        } else {
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        super.tearDown()
    }

    // MARK: - AppSettings.appLanguage

    func testAppLanguageDefaultIsSystem() {
        XCTAssertEqual(AppSettings.appLanguage, "system")
    }

    func testAppLanguageGetSet() {
        AppSettings.appLanguage = "fr"
        XCTAssertEqual(AppSettings.appLanguage, "fr")
    }

    func testAppLanguageRoundTrips() {
        for lang in ["system", "en", "fr"] {
            AppSettings.appLanguage = lang
            XCTAssertEqual(AppSettings.appLanguage, lang)
        }
    }

    // MARK: - applyLanguage

    func testApplyLanguageSystemClearsOverride() {
        // Set a known override first
        AppSettings.appLanguage = "en"
        let before = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(before, ["en"])

        // Setting system should change it (remove our single-element override)
        AppSettings.appLanguage = "system"
        let after = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertNotEqual(after, ["en"], "Override should no longer be ['en']")
    }

    func testApplyLanguageFrSetsAppleLanguages() {
        AppSettings.appLanguage = "fr"
        let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(langs, ["fr"])
    }

    func testApplyLanguageEnSetsAppleLanguages() {
        AppSettings.appLanguage = "en"
        let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(langs, ["en"])
    }

    func testApplyLanguageCalledOnSet() {
        AppSettings.appLanguage = "fr"
        let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(langs, ["fr"])

        AppSettings.appLanguage = "en"
        let langsAfter = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
        XCTAssertEqual(langsAfter, ["en"])
    }

    // MARK: - SettingsSection

    func testSettingsSectionAllCasesCount() {
        XCTAssertEqual(SettingsSection.allCases.count, 8)
    }

    func testSettingsSectionIdMatchesRawValue() {
        for section in SettingsSection.allCases {
            XCTAssertEqual(section.id, section.rawValue)
        }
    }

    func testSettingsSectionLocalizedNameNotEmpty() {
        for section in SettingsSection.allCases {
            XCTAssertFalse(section.localizedName.isEmpty, "\(section) has empty localizedName")
        }
    }

    func testSettingsSectionIconNotEmpty() {
        for section in SettingsSection.allCases {
            XCTAssertFalse(section.icon.isEmpty, "\(section) has empty icon")
        }
    }

    func testSettingsSectionIconsAreUnique() {
        let icons = SettingsSection.allCases.map(\.icon)
        XCTAssertEqual(icons.count, Set(icons).count, "Icons should be unique")
    }

    // MARK: - PersonSection

    func testPersonSectionAllCasesCount() {
        XCTAssertEqual(PersonSection.allCases.count, 5)
    }

    func testPersonSectionLocalizedNameNotEmpty() {
        for section in PersonSection.allCases {
            XCTAssertFalse(section.localizedName.isEmpty, "\(section) has empty localizedName")
        }
    }

    func testPersonSectionIconNotEmpty() {
        for section in PersonSection.allCases {
            XCTAssertFalse(section.icon.isEmpty, "\(section) has empty icon")
        }
    }

    func testPersonSectionOneOnOneLocalizedNameIs1dash1() {
        XCTAssertEqual(PersonSection.oneOnOne.localizedName, "1-1")
    }

    // MARK: - Localizable.xcstrings integrity

    func testLocalizableFileExists() {
        let mainBundle = Bundle.main
        let testBundle = Bundle(for: type(of: self))
        XCTAssertNotNil(
            mainBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "fr")
            ?? mainBundle.url(forResource: "Localizable", withExtension: "xcstrings")?.path
            ?? testBundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: "fr"),
            "French localization should exist"
        )
    }

    func testKeyStringsResolveInEnglish() {
        // These are critical UI keys — verify they resolve to non-empty strings
        let keys = [
            "Welcome to Maurice",
            "Meetings",
            "People",
            "Tasks",
            "Settings",
            "Cancel",
            "Delete",
            "Create",
            "Search...",
        ]
        for key in keys {
            let resolved = String(localized: String.LocalizationValue(key))
            XCTAssertFalse(resolved.isEmpty, "Key '\(key)' resolved to empty string")
        }
    }
}
