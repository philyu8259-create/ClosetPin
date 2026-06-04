import SwiftUI

enum ColorResolver {
    enum SwatchKind: Hashable {
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
            guard words.allSatisfy({
                allowedEnglishColorTokens.contains($0)
                    || allowedEnglishModifiers.contains($0)
                    || allowedEnglishPatternTokens.contains($0)
            }),
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

    static func localizedDisplayColor(from rawColor: String, locale: Locale = .current) -> String? {
        guard let color = safeDisplayColor(from: rawColor) else { return nil }

        if shouldDisplayChineseColor(for: locale),
           let chineseColor = chineseDisplayAlias(for: color) {
            return chineseColor
        }

        return color
    }

    private static func shouldDisplayChineseColor(for locale: Locale) -> Bool {
        let languageCode = locale.language.languageCode?.identifier.lowercased() ?? ""
        if languageCode.hasPrefix("zh") {
            return true
        }

        let identifierLocale = locale.identifier.lowercased()
        if identifierLocale.hasPrefix("zh") || identifierLocale.hasPrefix("zh-") {
            return true
        }

        return false
    }

    static func swatchKind(for rawColor: String) -> SwatchKind {
        let words = normalizedWords(rawColor)
        if words.contains("green") || rawColor.contains("绿色") || rawColor.contains("绿") {
            return .green
        }
        if words.contains("navy") || rawColor.contains("藏青") || rawColor.contains("海军蓝") {
            return .navy
        }
        if words.contains("blue") || rawColor.contains("蓝") {
            return .blue
        }
        if words.contains("black") || rawColor.contains("黑") {
            return .black
        }
        if words.contains("brown") || words.contains("tan") || words.contains("camel") || rawColor.contains("棕") || rawColor.contains("驼") {
            return .brown
        }
        if words.contains("red") || words.contains("burgundy") || words.contains("maroon") || words.contains("pink") || rawColor.contains("红") || rawColor.contains("粉") {
            return .red
        }

        return switch normalizedSwatchAlias(rawColor) {
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

    private static func normalizedWords(_ rawColor: String) -> [String] {
        rawColor
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split { $0 == " " || $0 == "-" || $0 == "/" || $0 == "," }
            .map(String.init)
    }

    private static func chineseDisplayAlias(for rawColor: String) -> String? {
        let words = normalizedWords(rawColor)
        if let pattern = words.first(where: { allowedEnglishPatternTokens.contains($0) && !["solid", "plain"].contains($0) }) {
            let colorWords = words.filter { allowedEnglishColorTokens.contains($0) }
            if colorWords.isEmpty == false {
                let colors = colorWords
                    .prefix(2)
                    .compactMap(chineseColorTokenAlias)
                    .joined()
                if colors.isEmpty == false {
                    return "\(colors)\(chinesePatternTokenAlias(pattern))"
                }
            }
        }

        let colorWords = words.filter { allowedEnglishColorTokens.contains($0) }
        if colorWords.isEmpty == false {
            let colors = colorWords
                .prefix(2)
                .compactMap(chineseColorTokenAlias)
                .joined()
            if colors.isEmpty == false {
                let modifiers = words
                    .filter { allowedEnglishModifiers.contains($0) }
                    .prefix(1)
                    .map(chineseModifierTokenAlias)
                    .joined()
                return "\(modifiers)\(colors)色"
            }
        }

        return switch normalizedSwatchAlias(rawColor) {
        case "black":
            "黑色"
        case "white":
            "白色"
        case "ivory":
            "象牙白"
        case "cream":
            "奶油色"
        case "beige":
            "米色"
        case "navy":
            "海军蓝"
        case "blue":
            "蓝色"
        case "lightblue":
            "浅蓝色"
        case "darkblue", "deepblue":
            "深蓝色"
        case "charcoal":
            "炭灰色"
        case "gray", "grey":
            "灰色"
        case "silver":
            "银色"
        case "brown":
            "棕色"
        case "tan":
            "黄褐色"
        case "camel":
            "驼色"
        case "khaki":
            "卡其色"
        case "green":
            "绿色"
        case "olive":
            "橄榄绿"
        case "red":
            "红色"
        case "burgundy", "maroon":
            "酒红色"
        case "pink":
            "粉色"
        case "purple":
            "紫色"
        case "yellow":
            "黄色"
        case "gold":
            "金色"
        case "orange":
            "橙色"
        case "teal", "turquoise":
            "蓝绿色"
        default:
            nil
        }
    }

    private static func chineseColorTokenAlias(_ token: String) -> String? {
        switch token {
        case "black":
            "黑"
        case "white":
            "白"
        case "ivory", "cream":
            "米白"
        case "beige", "tan", "khaki":
            "卡其"
        case "gray", "grey", "charcoal", "silver":
            "灰"
        case "navy":
            "藏青"
        case "blue", "teal", "turquoise", "denim":
            "蓝"
        case "green", "olive":
            "绿"
        case "brown", "camel":
            "棕"
        case "red", "burgundy", "maroon":
            "红"
        case "pink":
            "粉"
        case "purple":
            "紫"
        case "yellow", "gold":
            "黄"
        case "orange":
            "橙"
        default:
            nil
        }
    }

    private static func chinesePatternTokenAlias(_ token: String) -> String {
        switch token {
        case "plaid", "check", "checked", "checkered", "tartan", "gingham":
            "格纹"
        case "striped", "stripe", "stripes":
            "条纹"
        case "floral":
            "花纹"
        case "solid", "plain":
            "纯色"
        default:
            "图案"
        }
    }

    private static func chineseModifierTokenAlias(_ token: String) -> String {
        switch token {
        case "light", "pale", "soft":
            "浅"
        case "dark", "deep":
            "深"
        case "dusty", "muted":
            "灰调"
        case "bright":
            "亮"
        default:
            ""
        }
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
        "light", "dark", "pale", "deep", "soft", "bright", "muted", "dusty"
    ]

    private static let allowedEnglishPatternTokens: Set<String> = [
        "solid", "plain", "plaid", "check", "checked", "checkered", "tartan", "gingham",
        "striped", "stripe", "stripes", "floral"
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
