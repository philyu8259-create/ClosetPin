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
        let targetFormality = targetFormality(for: input)
        let tops = filteredAndPreselected(groupedItems[.top] ?? [], threshold: threshold, targetFormality: targetFormality)
        let bottoms = filteredAndPreselected(groupedItems[.bottom] ?? [], threshold: threshold, targetFormality: targetFormality)
        let shoes = filteredAndPreselected(groupedItems[.shoes] ?? [], threshold: threshold, targetFormality: targetFormality)
        let blazers = filteredAndPreselected(groupedItems[.blazer] ?? [], threshold: threshold, targetFormality: targetFormality)

        let candidates: [OutfitCandidate]
        switch input.scenario {
        case .dailyOffice, .weekendCasual:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: [],
                targetFormality: targetFormality
            )
        case .banquet:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: blazers,
                targetFormality: targetFormality,
                requiresBlazer: false
            )
        case .importantMeeting:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: blazers,
                targetFormality: targetFormality,
                requiresBlazer: true
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
        case .weekendCasual:
            1
        case .dailyOffice:
            2
        case .importantMeeting, .banquet:
            4
        }
    }

    func targetFormality(for input: RecommendationInput) -> Int {
        let preferredFormality = input.preferredFormality.map { min(max($0, 1), 5) }
        let fallback = switch input.scenario {
        case .weekendCasual:
            2
        case .dailyOffice:
            3
        case .importantMeeting, .banquet:
            5
        }
        return max(requiredFormality(for: input.scenario), preferredFormality ?? fallback)
    }

    func filteredAndPreselected(_ items: [ClothingItem], threshold: Int, targetFormality: Int) -> [ClothingItem] {
        items
            .filter { $0.formalityLevel >= threshold }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.formalityLevel - targetFormality)
                let rhsDistance = abs(rhs.formalityLevel - targetFormality)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
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
        blazers: [ClothingItem],
        targetFormality: Int,
        requiresBlazer: Bool = false
    ) -> [OutfitCandidate] {
        guard !tops.isEmpty, !bottoms.isEmpty, !shoes.isEmpty else { return [] }

        // Candidate generation stays bounded by the per-category preselection above
        // while still letting the final sort pick the best MVP results.
        var candidates: [OutfitCandidate] = []

        if requiresBlazer {
            guard !blazers.isEmpty else { return [] }

            for top in tops {
                for bottom in bottoms {
                    for shoe in shoes {
                        for blazer in blazers {
                            candidates.append(makeCandidate(
                                scenario: scenario,
                                items: [top, bottom, shoe, blazer],
                                targetFormality: targetFormality
                            ))
                        }
                    }
                }
            }
        } else {
            for top in tops {
                for bottom in bottoms {
                    for shoe in shoes {
                        candidates.append(makeCandidate(
                            scenario: scenario,
                            items: [top, bottom, shoe],
                            targetFormality: targetFormality
                        ))

                        for blazer in blazers {
                            candidates.append(makeCandidate(
                                scenario: scenario,
                                items: [top, bottom, shoe, blazer],
                                targetFormality: targetFormality
                            ))
                        }
                    }
                }
            }
        }

        return candidates
    }

    func makeCandidate(scenario: OutfitScenario, items: [ClothingItem], targetFormality: Int) -> OutfitCandidate {
        OutfitCandidate(
            id: stableIdentifier(scenario: scenario, items: items),
            items: items,
            score: score(scenario: scenario, items: items, targetFormality: targetFormality),
            explanationSeed: explanationSeed(scenario: scenario, items: items)
        )
    }

    func score(scenario: OutfitScenario, items: [ClothingItem]) -> Int {
        let fallbackFormality = switch scenario {
        case .weekendCasual:
            2
        case .dailyOffice:
            3
        case .importantMeeting, .banquet:
            5
        }
        return score(scenario: scenario, items: items, targetFormality: fallbackFormality)
    }

    func score(scenario: OutfitScenario, items: [ClothingItem], targetFormality: Int) -> Int {
        let formalityScore = items.reduce(0) { total, item in
            total + max(0, 5 - abs(item.formalityLevel - targetFormality)) * 10
        }
        let scenarioBonus = switch scenario {
        case .weekendCasual:
            8
        case .dailyOffice:
            12
        case .importantMeeting:
            24
        case .banquet:
            20
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
