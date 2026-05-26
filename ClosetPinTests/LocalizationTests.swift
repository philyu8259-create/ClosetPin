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

        let expectedValues: [(color: String, notes: String)] = [
            ("白色", "白色衬衫"),
            ("浅蓝色", "浅蓝色衬衫"),
            ("炭灰色", "炭灰色 Polo 衫"),
            ("海军蓝", "海军蓝下装"),
            ("黑色", "黑色下装"),
            ("炭灰色", "炭灰色西装外套"),
            ("黑色", "黑色鞋子"),
            ("棕色", "棕色鞋子"),
            ("黑色", "通勤包")
        ]

        XCTAssertEqual(items.count, expectedValues.count)

        for (item, expected) in zip(items, expectedValues) {
            XCTAssertEqual(item.color, expected.color)
            XCTAssertEqual(item.notes, expected.notes)
            XCTAssertEqual(item.storageLocation, "示例通勤胶囊衣橱")
            XCTAssertFalse(item.color.hasPrefix("seed."))
            XCTAssertFalse(item.notes.hasPrefix("seed."))
            XCTAssertFalse(item.storageLocation.hasPrefix("seed."))
        }
    }

    @MainActor
    func testSimplifiedChineseSampleCapsuleColorsSurviveTodayRecommendationExplanation() throws {
        let zhBundle = try localizedBundle("zh-Hans")
        let items = SeedData.workCapsuleItems(bundle: zhBundle)
        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 1),
            items: items,
            feedback: []
        )
        let candidate = try XCTUnwrap(candidates.first)

        let explanation = TodayRecommendationExplanation.text(for: candidate, scenario: .dailyOffice)

        for item in candidate.items {
            XCTAssertTrue(
                explanation.contains(item.color),
                "Expected explanation to keep zh-Hans color \(item.color), got: \(explanation)"
            )
        }
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
