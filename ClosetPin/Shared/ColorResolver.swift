import SwiftUI

enum ColorResolver {
    enum SwatchKind: Equatable {
        case black
        case white
        case navy
        case blue
        case gray
        case brown
        case green
        case red
        case accent
    }

    static func safeDisplayColor(from rawColor: String) -> String? {
        let color = rawColor.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !color.isEmpty,
              color.allSatisfy({ $0.isLetter || $0 == " " || $0 == "-" })
        else {
            return nil
        }

        let lowercasedColor = color.lowercased()
        let words = lowercasedColor
            .split { $0 == " " || $0 == "-" }
            .map(String.init)

        guard !words.isEmpty,
              !containsRejectedClothingNoun(in: lowercasedColor)
        else {
            return nil
        }

        if lowercasedColor.unicodeScalars.allSatisfy(\.isASCII) {
            guard words.allSatisfy({ allowedEnglishColorTokens.contains($0) || allowedEnglishModifiers.contains($0) }),
                  words.contains(where: { allowedEnglishColorTokens.contains($0) })
            else {
                return nil
            }

            return color
        }

        let compactColor = lowercasedColor
            .filter { $0 != " " && $0 != "-" }

        guard allowedChineseColors.contains(compactColor) else {
            return nil
        }

        return color
    }

    static func swatchKind(for rawColor: String) -> SwatchKind {
        switch normalizedSwatchAlias(rawColor) {
        case "black", "charcoal", "黑色", "炭灰色", "深灰色":
            .black
        case "white", "ivory", "cream", "beige", "白色", "象牙白", "米白色", "米色":
            .white
        case "navy", "海军蓝", "藏青色", "深蓝色":
            .navy
        case "blue", "lightblue", "teal", "turquoise", "蓝色", "浅蓝色", "蓝绿色", "青色":
            .blue
        case "gray", "grey", "silver", "灰色", "银色":
            .gray
        case "brown", "tan", "camel", "棕色", "咖啡色", "驼色", "卡其色":
            .brown
        case "green", "olive", "绿色", "橄榄绿", "橄榄色":
            .green
        case "red", "burgundy", "maroon", "pink", "purple", "红色", "酒红色", "粉色", "紫色":
            .red
        default:
            .accent
        }
    }

    static func swatchColor(for rawColor: String) -> Color {
        switch swatchKind(for: rawColor) {
        case .black:
            .black
        case .white:
            .white
        case .navy:
            Color(red: 0.03, green: 0.09, blue: 0.22)
        case .blue:
            .blue
        case .gray:
            .gray
        case .brown:
            .brown
        case .green:
            .green
        case .red:
            .red
        case .accent:
            DesignSystem.accent.opacity(0.35)
        }
    }

    private static func normalizedSwatchAlias(_ rawColor: String) -> String {
        rawColor
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .filter { $0 != " " && $0 != "-" }
    }

    private static func containsRejectedClothingNoun(in color: String) -> Bool {
        let words = color
            .split { $0 == " " || $0 == "-" }
            .map(String.init)

        if words.contains(where: { rejectedEnglishClothingNouns.contains($0) }) {
            return true
        }

        return rejectedChineseClothingNouns.contains { color.contains($0) }
    }

    private static let allowedEnglishColorTokens: Set<String> = [
        "black", "white", "gray", "grey", "navy", "blue", "red", "burgundy",
        "pink", "purple", "green", "olive", "yellow", "cream", "beige", "tan",
        "brown", "camel", "orange", "ivory", "charcoal", "silver", "gold",
        "denim", "khaki", "teal", "turquoise", "maroon"
    ]

    private static let allowedEnglishModifiers: Set<String> = [
        "light", "dark", "pale", "deep", "soft", "bright", "muted"
    ]

    private static let allowedChineseColors: Set<String> = [
        "白色", "象牙白", "米白色", "米色", "奶油色",
        "浅蓝色", "蓝色", "海军蓝", "藏青色", "深蓝色", "蓝绿色", "青色",
        "炭灰色", "深灰色", "灰色", "银色",
        "黑色", "棕色", "咖啡色", "驼色", "卡其色",
        "绿色", "橄榄绿", "橄榄色",
        "红色", "酒红色", "粉色", "紫色", "黄色", "金色", "橙色"
    ]

    private static let rejectedEnglishClothingNouns: Set<String> = Set(
        ClothingType.allCases.map(\.rawValue) + [
            "shirt", "pants", "trousers", "jeans", "skirt", "jacket", "coat",
            "scarf", "boots", "heels", "dress", "tie", "suit", "watch"
        ]
    )

    private static let rejectedChineseClothingNouns: Set<String> = [
        "衬衫", "裤子", "半裙", "外套", "西装", "领带", "连衣裙", "鞋", "包", "围巾", "手表"
    ]
}

private extension Unicode.Scalar {
    var isASCII: Bool {
        value < 128
    }
}
