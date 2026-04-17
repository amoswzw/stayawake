import XCTest
@testable import stayawake

final class LocalizationTests: XCTestCase {
    func testEachLanguageHasDistinctStatusAwake() {
        var seen: [String: AppLanguage] = [:]
        for lang in AppLanguage.allCases where lang != .system {
            let value = L10n.s("status.awake", language: lang)
            XCTAssertFalse(value.isEmpty, "empty for \(lang)")
            XCTAssertNotEqual(value, "status.awake", "not found for \(lang)")
            if let prior = seen[value] {
                XCTFail("\(lang) produced same string as \(prior): \(value)")
            }
            seen[value] = lang
        }
    }

    func testSimplifiedAndTraditionalChineseAreDistinct() {
        let keys = ["status.awake", "menu.settings", "settings.tab.general", "logs.action.stop"]
        for key in keys {
            let hans = L10n.s(key, language: .simplifiedChinese)
            let hant = L10n.s(key, language: .traditionalChinese)
            XCTAssertNotEqual(hans, hant, "same string for \(key): \(hans)")
        }
    }
}
