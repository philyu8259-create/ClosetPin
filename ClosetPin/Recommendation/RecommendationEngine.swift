import Foundation

private let maximumItemsPerCategory = 12

struct RecommendationEngine {
    func recommend(
        input: RecommendationInput,
        items: [ClothingItem],
        feedback _: [OutfitFeedback]
    ) -> [OutfitCandidate] {
        guard input.maximumResults > 0 else { return [] }

        let groupedItems = Dictionary(grouping: eligibleItems(from: items, for: input.season)) { item in
            item.resolvedType ?? .accessory
        }

        let threshold = requiredFormality(for: input.scenario)
        let tops = filteredAndPreselected(groupedItems[.top] ?? [], threshold: threshold)
        let bottoms = filteredAndPreselected(groupedItems[.bottom] ?? [], threshold: threshold)
        let shoes = filteredAndPreselected(groupedItems[.shoes] ?? [], threshold: threshold)
        let blazers = filteredAndPreselected(groupedItems[.blazer] ?? [], threshold: threshold)

        let candidates: [OutfitCandidate]
        switch input.scenario {
        case .dailyOffice:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: []
            )
        case .importantMeeting:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: blazers
            )
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.explanationSeed < rhs.explanationSeed
            }
            .prefix(input.maximumResults)
            .map { $0 }
    }
}

private extension RecommendationEngine {
    func eligibleItems(from items: [ClothingItem], for season: SeasonTag) -> [ClothingItem] {
        items.filter { item in
            guard let type = item.resolvedType else { return false }

            return item.resolvedStatus == .available
                && item.seasons.contains(season)
                && recommendableTypes.contains(type)
        }
    }

    var recommendableTypes: Set<ClothingType> {
        [.top, .bottom, .shoes, .blazer]
    }

    func requiredFormality(for scenario: OutfitScenario) -> Int {
        switch scenario {
        case .dailyOffice:
            2
        case .importantMeeting:
            4
        }
    }

    func filteredAndPreselected(_ items: [ClothingItem], threshold: Int) -> [ClothingItem] {
        items
            .filter { $0.formalityLevel >= threshold }
            .sorted { lhs, rhs in
                if lhs.formalityLevel != rhs.formalityLevel {
                    return lhs.formalityLevel > rhs.formalityLevel
                }
                if lhs.color != rhs.color {
                    return lhs.color < rhs.color
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(maximumItemsPerCategory)
            .map { $0 }
    }

    func makeCandidates(
        scenario: OutfitScenario,
        tops: [ClothingItem],
        bottoms: [ClothingItem],
        shoes: [ClothingItem],
        blazers: [ClothingItem]
    ) -> [OutfitCandidate] {
        guard !tops.isEmpty, !bottoms.isEmpty, !shoes.isEmpty else { return [] }

        // Candidate generation stays bounded by the per-category preselection above
        // while still letting the final sort pick the best MVP results.
        var candidates: [OutfitCandidate] = []

        if scenario == .importantMeeting {
            guard !blazers.isEmpty else { return [] }

            for top in tops {
                for bottom in bottoms {
                    for shoe in shoes {
                        for blazer in blazers {
                            candidates.append(makeCandidate(scenario: scenario, items: [top, bottom, shoe, blazer]))
                        }
                    }
                }
            }
        } else {
            for top in tops {
                for bottom in bottoms {
                    for shoe in shoes {
                        candidates.append(makeCandidate(scenario: scenario, items: [top, bottom, shoe]))
                    }
                }
            }
        }

        return candidates
    }

    func makeCandidate(scenario: OutfitScenario, items: [ClothingItem]) -> OutfitCandidate {
        OutfitCandidate(
            id: stableIdentifier(scenario: scenario, items: items),
            items: items,
            score: score(scenario: scenario, items: items),
            explanationSeed: explanationSeed(scenario: scenario, items: items)
        )
    }

    func score(scenario: OutfitScenario, items: [ClothingItem]) -> Int {
        let formalityScore = items.reduce(0) { total, item in
            total + item.formalityLevel * 10
        }
        let scenarioBonus = switch scenario {
        case .dailyOffice:
            12
        case .importantMeeting:
            24
        }
        let uniqueColorCount = Set(items.map(\.color)).count
        let colorVarietyPenalty = max(0, uniqueColorCount - 2) * 2

        return formalityScore + scenarioBonus - colorVarietyPenalty
    }

    func explanationSeed(scenario: OutfitScenario, items: [ClothingItem]) -> String {
        let itemTokens = items.map { item in
            let type = item.resolvedType?.rawValue ?? "unknown"
            return "\(type):\(item.color):f\(item.formalityLevel):id\(item.id.uuidString)"
        }

        return "scenario=\(scenario.rawValue);items=\(itemTokens.joined(separator: ","))"
    }

    func stableIdentifier(scenario: OutfitScenario, items: [ClothingItem]) -> String {
        let itemIDs = items.map(\.id.uuidString).joined(separator: "|")
        return "\(scenario.rawValue):\(itemIDs)"
    }
}
