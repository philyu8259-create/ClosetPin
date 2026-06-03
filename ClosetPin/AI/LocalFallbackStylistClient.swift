import Foundation

struct LocalFallbackStylistClient: AIStylistClient {
    @MainActor
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
        case .weekendCasual:
            return L10n.string("recommendation.explanation.weekend_casual.format", arguments: itemSummary)
        case .banquet:
            return L10n.string("recommendation.explanation.banquet.format", arguments: itemSummary)
        }
    }

    private func summary(for items: [ClothingItem]) -> String {
        let fallbackLocale = Locale(identifier: "en_US")

        let descriptions = items.map { item in
            let type = (item.resolvedType ?? item.type).summaryName

            guard let color = ColorResolver.localizedDisplayColor(from: item.color, locale: fallbackLocale) else {
                return type
            }

            return "\(color) \(type)"
        }

        return descriptions.joined(separator: ", ")
    }
}
