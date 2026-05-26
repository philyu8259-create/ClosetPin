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
        guard let color = ColorResolver.safeDisplayColor(from: color) else {
            return typeRawValue
        }

        return "\(color) \(summaryName)"
    }

    private var summaryName: String {
        ClothingType(rawValue: typeRawValue)?.summaryName ?? typeRawValue
    }
}
