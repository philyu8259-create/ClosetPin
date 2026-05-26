import Foundation

struct LocalFallbackStylistClient: AIStylistClient {
    func explain(candidate: OutfitCandidate, scenario: OutfitScenario) async throws -> String {
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
            let color = item.color.trimmingCharacters(in: .whitespacesAndNewlines)
            let type = (item.resolvedType ?? item.type).rawValue

            if color.isEmpty {
                return type
            }

            return "\(color) \(type)"
        }

        return descriptions.joined(separator: ", ")
    }
}
