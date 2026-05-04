import XCTest
@testable import Maurice

final class SpeechRecognitionServiceTests: XCTestCase {

    private var savedLanguage: String?

    override func setUp() {
        super.setUp()
        savedLanguage = UserDefaults.standard.string(forKey: "transcriptionLanguage")
        UserDefaults.standard.removeObject(forKey: "transcriptionLanguage")
    }

    override func tearDown() {
        if let lang = savedLanguage {
            UserDefaults.standard.set(lang, forKey: "transcriptionLanguage")
        } else {
            UserDefaults.standard.removeObject(forKey: "transcriptionLanguage")
        }
        super.tearDown()
    }

    func testResolveLocaleUsesAppSettingsWhenNoOverride() {
        AppSettings.transcriptionLanguage = "en-US"
        let service = SpeechRecognitionService()
        XCTAssertEqual(service.resolveLocale().identifier(.bcp47), "en-US")
    }

    func testResolveLocaleFollowsAppSettingsChangedAfterInit() {
        AppSettings.transcriptionLanguage = "fr-FR"
        let service = SpeechRecognitionService()
        XCTAssertEqual(service.resolveLocale().identifier(.bcp47), "fr-FR")

        AppSettings.transcriptionLanguage = "en-US"
        XCTAssertEqual(
            service.resolveLocale().identifier(.bcp47),
            "en-US",
            "Service must re-read AppSettings.transcriptionLanguage so settings changes apply without restart"
        )
    }

    func testResolveLocaleHonorsExplicitOverride() {
        AppSettings.transcriptionLanguage = "fr-FR"
        let service = SpeechRecognitionService(locale: Locale(identifier: "ja-JP"))
        XCTAssertEqual(service.resolveLocale().identifier(.bcp47), "ja-JP")
    }

    func testResolveLocaleOverrideIsNotAffectedByAppSettings() {
        let service = SpeechRecognitionService(locale: Locale(identifier: "de-DE"))
        AppSettings.transcriptionLanguage = "fr-FR"
        XCTAssertEqual(service.resolveLocale().identifier(.bcp47), "de-DE")
    }
}
