import XCTest
@testable import ClosetPin

final class LocalizationTests: XCTestCase {
    func testSimplifiedChineseTodayTabTranslationLoadsFromBundle() throws {
        let appBundle = try XCTUnwrap(
            Bundle.allBundles.first { $0.bundleIdentifier == "com.phil.closetpin" }
        )
        let zhPath = try XCTUnwrap(appBundle.path(forResource: "zh-Hans", ofType: "lproj"))
        let zhBundle = try XCTUnwrap(Bundle(path: zhPath))

        XCTAssertEqual(L10n.string("tab.today", bundle: zhBundle), "今日")
    }
}
