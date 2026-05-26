import Foundation

struct LooksHistoryEntry: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case saved
        case worn
    }

    let id: String
    let kind: Kind
    let date: Date
    let scenario: OutfitScenario
    let itemCount: Int
    let itemSummary: String
    let explanation: String
    let score: Int?

    static func makeEntries(
        outfits: [Outfit],
        feedback: [OutfitFeedback],
        items: [ClothingItem]
    ) -> [LooksHistoryEntry] {
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })

        let savedEntries = outfits
            .filter { $0.savedAt != nil }
            .map { outfit in
                LooksHistoryEntry(
                    id: "saved-\(outfit.id.uuidString)",
                    kind: .saved,
                    date: outfit.savedAt ?? outfit.dateContext,
                    scenario: outfit.scenario,
                    itemCount: outfit.itemIds.count,
                    itemSummary: itemSummary(for: outfit.itemIds, itemsByID: itemsByID),
                    explanation: outfit.explanation,
                    score: outfit.score
                )
            }

        let wornEntries = feedback
            .filter { $0.feedbackType == .wore }
            .map { feedback in
                LooksHistoryEntry(
                    id: "worn-\(feedback.id.uuidString)",
                    kind: .worn,
                    date: feedback.createdAt,
                    scenario: feedback.scenario,
                    itemCount: feedback.itemIds.count,
                    itemSummary: itemSummary(for: feedback.itemIds, itemsByID: itemsByID),
                    explanation: L10n.text("looks.worn.explanation"),
                    score: nil
                )
            }

        return (savedEntries + wornEntries).sorted { lhs, rhs in
            if lhs.date == rhs.date {
                return lhs.id < rhs.id
            }
            return lhs.date > rhs.date
        }
    }

    private static func itemSummary(
        for itemIds: [UUID],
        itemsByID: [UUID: ClothingItem]
    ) -> String {
        let names = itemIds.compactMap { itemID -> String? in
            guard let item = itemsByID[itemID] else { return nil }
            return "\(item.color) \(item.type.displayName)"
        }

        guard !names.isEmpty else {
            return L10n.text("looks.items.unavailable")
        }

        return names.prefix(3).joined(separator: ", ")
    }
}
