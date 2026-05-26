import Foundation

struct LocalFallbackStylistClient: AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
        guard !candidate.items.isEmpty else {
            return "No outfit items were available to explain."
        }

        let itemSummary = summary(for: candidate.items)

        switch scenario {
        case .dailyOffice:
            return "A practical, balanced office option with \(itemSummary), easy to wear on a workday."
        case .importantMeeting:
            return "A more formal, polished office option with \(itemSummary), suitable for a higher-stakes work moment."
        }
    }

    private func summary(for items: [ClothingItem]) -> String {
        let descriptions = items.map { item in
            let type = (item.resolvedType ?? item.type).rawValue

            guard let color = sanitizedColor(from: item.color) else {
                return type
            }

            return "\(color) \(type)"
        }

        return descriptions.joined(separator: ", ")
    }

    private func sanitizedColor(from rawColor: String) -> String? {
        let color = rawColor.trimmingCharacters(in: .whitespacesAndNewlines)

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
