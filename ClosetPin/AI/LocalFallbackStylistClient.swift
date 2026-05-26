import Foundation

struct LocalFallbackStylistClient: AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
        guard !candidate.items.isEmpty else {
            return L10n.text("recommendation.explanation.empty")
        }

        let itemSummary = summary(for: candidate.items)

        switch scenario {
        case .dailyOffice:
            return L10n.string("recommendation.explanation.daily_office.format", arguments: itemSummary)
        case .importantMeeting:
            return L10n.string("recommendation.explanation.important_meeting.format", arguments: itemSummary)
        }
    }

    private func summary(for items: [ClothingItem]) -> String {
        let descriptions = items.map { item in
            let type = (item.resolvedType ?? item.type).summaryName

            guard let color = ColorResolver.safeDisplayColor(from: item.color) else {
                return type
            }

            return "\(color) \(type)"
        }

        return descriptions.joined(separator: ", ")
    }
}
