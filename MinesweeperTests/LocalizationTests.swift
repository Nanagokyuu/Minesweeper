import XCTest
@testable import Minesweeper

final class LocalizationTests: XCTestCase {
    @MainActor
    func testEveryKeyHasTextInEveryLanguage() {
        for key in LocalizedKey.allCases {
            for language in AppLanguage.allCases {
                XCTAssertFalse(
                    key.localized(for: language).isEmpty,
                    "\(key) is empty for \(language.rawValue)"
                )
            }
        }
    }
}
