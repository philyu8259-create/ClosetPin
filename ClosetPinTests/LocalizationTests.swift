import XCTest
@testable import ClosetPin

final class LocalizationTests: XCTestCase {
    func testSimplifiedChineseTodayTabTranslationLoadsFromBundle() throws {
        let zhBundle = try localizedBundle("zh-Hans")

        XCTAssertEqual(L10n.string("tab.today", bundle: zhBundle), "今日")
    }

    func testEnglishAndSimplifiedChineseLocalizableKeySetsMatch() throws {
        let enStrings = try stringsDictionary(named: "Localizable", language: "en")
        let zhStrings = try stringsDictionary(named: "Localizable", language: "zh-Hans")

        XCTAssertEqual(Set(enStrings.allKeys as? [String] ?? []), Set(zhStrings.allKeys as? [String] ?? []))
    }

    func testInfoPlistStringsContainPhotoAndCameraUsageDescriptions() throws {
        for language in ["en", "zh-Hans"] {
            let strings = try stringsDictionary(named: "InfoPlist", language: language)

            XCTAssertNotNil(strings["NSPhotoLibraryUsageDescription"], "\(language) photo library usage description is missing")
            XCTAssertNotNil(strings["NSCameraUsageDescription"], "\(language) camera usage description is missing")
        }
    }

    func testSampleCapsuleUsesSimplifiedChineseLocalizedValues() throws {
        let zhBundle = try localizedBundle("zh-Hans")
        let items = SeedData.workCapsuleItems(bundle: zhBundle)

        XCTAssertEqual(items.first?.color, "白色")
        XCTAssertEqual(items.first?.notes, "白色衬衫")
        XCTAssertEqual(items.first?.storageLocation, "示例通勤胶囊衣橱")
    }

    private func localizedBundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(appBundle.path(forResource: language, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }

    private func stringsDictionary(named name: String, language: String) throws -> NSDictionary {
        let bundle = try localizedBundle(language)
        let path = try XCTUnwrap(bundle.path(forResource: name, ofType: "strings"))
        return try XCTUnwrap(NSDictionary(contentsOfFile: path))
    }

    private var appBundle: Bundle {
        get throws {
            try XCTUnwrap(Bundle.allBundles.first { $0.bundleIdentifier == "com.phil.closetpin" })
        }
    }
}
