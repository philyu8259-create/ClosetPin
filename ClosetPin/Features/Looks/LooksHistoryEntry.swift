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
    let visualItems: [OutfitVisualItem]
    let explanation: String
    let score: Int?

    static func makeEntries(
        outfits: [Outfit],
        feedback: [OutfitFeedback],
        items: [ClothingItem]
    ) -> [LooksHistoryEntry] {
        let itemsByID = deduplicatedItemsByID(from: items)

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
                    visualItems: visualItems(for: outfit.itemIds, itemsByID: itemsByID),
                    explanation: explanation(for: outfit, itemsByID: itemsByID),
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
                    visualItems: visualItems(for: feedback.itemIds, itemsByID: itemsByID),
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
            return item.displayTitle
        }

        guard !names.isEmpty else {
            return L10n.text("looks.items.unavailable")
        }

        return names.prefix(3).joined(separator: ", ")
    }

    private static func visualItems(
        for itemIds: [UUID],
        itemsByID: [UUID: ClothingItem]
    ) -> [OutfitVisualItem] {
        OutfitVisualItem.makeItems(from: itemIds.compactMap { itemsByID[$0] })
    }

    private static func explanation(
        for outfit: Outfit,
        itemsByID: [UUID: ClothingItem]
    ) -> String {
        let snapshots = outfit.itemIds.compactMap { itemID -> TodayOutfitItemSnapshot? in
            guard let item = itemsByID[itemID] else { return nil }
            return TodayOutfitItemSnapshot(type: item.type, color: item.color)
        }

        guard !snapshots.isEmpty else {
            return outfit.explanation
        }

        return TodayRecommendationExplanation.text(for: snapshots, scenario: outfit.scenario)
    }

    private static func deduplicatedItemsByID(from items: [ClothingItem]) -> [UUID: ClothingItem] {
        var itemsByID: [UUID: ClothingItem] = [:]

        for item in items {
            itemsByID[item.id] = item
        }

        return itemsByID
    }
}
