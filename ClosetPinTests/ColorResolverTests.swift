import XCTest
@testable import ClosetPin

final class ColorResolverTests: XCTestCase {
    func testSwatchKindRecognizesEnglishAndSimplifiedChineseAliases() {
        let cases: [(String, ColorResolver.SwatchKind)] = [
            ("white", .white),
            ("白色", .white),
            ("light blue", .blue),
            ("浅蓝色", .blue),
            ("navy", .navy),
            ("海军蓝", .navy),
            ("藏青色", .navy),
            ("charcoal", .black),
            ("炭灰色", .black),
            ("brown", .brown),
            ("棕色", .brown),
            ("beige", .white),
            ("米色", .white),
            ("olive", .green),
            ("橄榄绿", .green),
            ("black green plaid", .green),
            ("green plaid", .green),
            ("burgundy", .red),
            ("酒红色", .red)
        ]

        for (rawColor, expectedKind) in cases {
            XCTAssertEqual(ColorResolver.swatchKind(for: rawColor), expectedKind, rawColor)
        }
    }

    func testSafeDisplayColorAllowsKnownChineseColorAliases() {
        let allowedColors = ["白色", "浅蓝色", "海军蓝", "藏青色", "炭灰色", "黑色", "棕色", "米色", "橄榄绿", "酒红色"]

        for color in allowedColors {
            XCTAssertEqual(ColorResolver.safeDisplayColor(from: color), color)
        }
    }

    func testSafeDisplayColorRejectsChineseClothingNounsAndNonColorPhrases() {
        let rejectedColors = [
            "蓝色衬衫",
            "黑色裤子",
            "红色半裙",
            "米色外套",
            "灰色西装",
            "黑色领带",
            "绿色连衣裙",
            "棕色鞋",
            "黑色包",
            "红色围巾",
            "金色手表",
            "适合办公"
        ]

        for color in rejectedColors {
            XCTAssertNil(ColorResolver.safeDisplayColor(from: color), color)
        }
    }

    func testLocalizedDisplayColorUsesCurrentLocaleForChineseOutput() {
        let chineseLocale = Locale(identifier: "zh-Hans")

        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "Ivory", locale: chineseLocale), "象牙白")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "Charcoal", locale: chineseLocale), "炭灰色")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "Navy", locale: chineseLocale), "海军蓝")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "black", locale: chineseLocale), "黑色")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "white", locale: chineseLocale), "白色")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "black green plaid", locale: chineseLocale), "黑绿格纹")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "green plaid", locale: chineseLocale), "绿格纹")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "navy striped", locale: chineseLocale), "藏青条纹")
    }

    func testLocalizedDisplayColorKeepsEnglishForNonChineseLocale() {
        let englishLocale = Locale(identifier: "en_US")

        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "Ivory", locale: englishLocale), "Ivory")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "charcoal", locale: englishLocale), "charcoal")
        XCTAssertEqual(ColorResolver.localizedDisplayColor(from: "navy", locale: englishLocale), "navy")
    }
}
