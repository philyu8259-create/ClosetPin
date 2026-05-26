import Foundation

struct TodayRecommendationExplanation {
    @MainActor
    static func text(for candidate: OutfitCandidate, scenario: OutfitScenario) -> String {
        let snapshots = candidate.items.map(TodayOutfitItemSnapshot.init(item:))
        return text(for: snapshots, scenario: scenario)
    }

    static func text(for items: [TodayOutfitItemSnapshot], scenario: OutfitScenario) -> String {
        guard !items.isEmpty else {
            return L10n.text("recommendation.explanation.empty")
        }

        let itemSummary = items.map(\.displayText).joined(separator: ", ")

        switch scenario {
        case .dailyOffice:
            return L10n.string("recommendation.explanation.daily_office.format", arguments: itemSummary)
        case .importantMeeting:
            return L10n.string("recommendation.explanation.important_meeting.format", arguments: itemSummary)
        }
    }
}

struct TodayOutfitItemSnapshot: Sendable {
    let typeRawValue: String
    let color: String

    init(type: ClothingType, color: String) {
        self.typeRawValue = type.rawValue
        self.color = color
    }

    @MainActor
    init(item: ClothingItem) {
        typeRawValue = item.type.rawValue
        color = item.color
    }

    fileprivate var displayText: String {
        guard let sanitizedColor else {
            return typeRawValue
        }

        return "\(sanitizedColor) \(summaryName)"
    }

    private var summaryName: String {
        ClothingType(rawValue: typeRawValue)?.summaryName ?? typeRawValue
    }

    private var sanitizedColor: String? {
        let color = color.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !color.isEmpty,
              color.allSatisfy({ $0.isLetter || $0 == " " || $0 == "-" })
        else {
            return nil
        }

        let words = color
            .lowercased()
            .split { $0 == " " || $0 == "-" }
            .map(String.init)

        guard !words.isEmpty,
              !words.contains(where: { Self.rejectedClothingNouns.contains($0) }),
              words.allSatisfy({ Self.allowedColorTokens.contains($0) || Self.allowedModifiers.contains($0) }),
              words.contains(where: { Self.allowedColorTokens.contains($0) })
        else {
            return nil
        }

        return color
    }

    private static let allowedColorTokens: Set<String> = [
        "black", "white", "gray", "grey", "navy", "blue", "red", "burgundy",
        "pink", "purple", "green", "olive", "yellow", "cream", "beige", "tan",
        "brown", "camel", "orange", "ivory", "charcoal", "silver", "gold",
        "denim", "khaki", "teal", "turquoise", "maroon"
    ]

    private static let allowedModifiers: Set<String> = [
        "light", "dark", "pale", "deep", "soft", "bright", "muted"
    ]

    private static let rejectedClothingNouns: Set<String> = Set(
        ClothingType.allCases.map(\.rawValue) + [
            "shirt", "pants", "trousers", "jeans", "skirt", "jacket", "coat",
            "scarf", "boots", "heels", "dress", "tie", "suit", "watch"
        ]
    )
}
