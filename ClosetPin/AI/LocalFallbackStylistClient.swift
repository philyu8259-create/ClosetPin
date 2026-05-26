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
              color.range(of: #"^[A-Za-z]+(?:[ -][A-Za-z]+)*$"#, options: .regularExpression) != nil
        else {
            return nil
        }

        let rejectedNouns = Set(
            ClothingType.allCases.map(\.rawValue) + ["dress", "tie", "suit", "watch"]
        )
        let words = color
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)

        guard !words.contains(where: { rejectedNouns.contains($0) }) else {
            return nil
        }

        return color
    }
}
