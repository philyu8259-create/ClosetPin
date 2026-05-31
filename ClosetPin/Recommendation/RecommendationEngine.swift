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
        let weatherContext = input.tomorrow.weatherContext

        let threshold = requiredFormality(for: input.scenario)
        let targetFormality = targetFormality(for: input)
        let tops = filteredAndPreselected(
            groupedItems[.top] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .top
        )
        let bottoms = filteredAndPreselected(
            groupedItems[.bottom] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .bottom
        )
        let shoes = filteredAndPreselected(
            groupedItems[.shoes] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .shoes
        )
        let blazers = filteredAndPreselected(
            groupedItems[.blazer] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .blazer
        )
        let outerwear = weatherContext?.isCold == true ? filteredAndPreselected(
            groupedItems[.outerwear] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .outerwear
        ) : []

        let isHotMeeting = input.scenario == .importantMeeting && (weatherContext?.isHot == true)
        let requiresBlazerForMeeting = input.scenario == .importantMeeting && !(weatherContext?.isHot == true)
        let blazerCandidatesForMeeting = isHotMeeting ? [] : blazers
        let candidates: [OutfitCandidate]

        switch input.scenario {
        case .dailyOffice, .weekendCasual:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: [],
                outerwear: outerwear,
                targetFormality: targetFormality,
                requiresBlazer: false,
                weatherContext: weatherContext
            )
        case .banquet:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: blazers,
                outerwear: outerwear,
                targetFormality: targetFormality,
                requiresBlazer: false,
                weatherContext: weatherContext
            )
        case .importantMeeting:
            candidates = makeCandidates(
                scenario: input.scenario,
                tops: tops,
                bottoms: bottoms,
                shoes: shoes,
                blazers: blazerCandidatesForMeeting,
                outerwear: outerwear,
                targetFormality: targetFormality,
                requiresBlazer: requiresBlazerForMeeting,
                weatherContext: weatherContext
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
        [.top, .bottom, .shoes, .blazer, .outerwear]
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

    func filteredAndPreselected(
        _ items: [ClothingItem],
        threshold: Int,
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext?,
        category: ClothingType
    ) -> [ClothingItem] {
        items
            .filter { $0.formalityLevel >= threshold }
            .sorted { lhs, rhs in
                let lhsDistance = abs(lhs.formalityLevel - targetFormality)
                let rhsDistance = abs(rhs.formalityLevel - targetFormality)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }
                if let weatherContext {
                    let lhsWeather = weatherContextScore(lhs, type: category, in: weatherContext)
                    let rhsWeather = weatherContextScore(rhs, type: category, in: weatherContext)
                    if lhsWeather != rhsWeather {
                        return lhsWeather > rhsWeather
                    }
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
        outerwear: [ClothingItem],
        targetFormality: Int,
        requiresBlazer: Bool = false,
        weatherContext: TomorrowWeatherContext?
    ) -> [OutfitCandidate] {
        guard !tops.isEmpty, !bottoms.isEmpty, !shoes.isEmpty else { return [] }
        guard !requiresBlazer || !blazers.isEmpty else { return [] }

        var candidates: [OutfitCandidate] = []
        let includeOuterwear = !outerwear.isEmpty

        for top in tops {
            for bottom in bottoms {
                for shoe in shoes {
                    var candidateBases: [[ClothingItem]] = [[top, bottom, shoe]]

                    if includeOuterwear {
                        for layer in outerwear {
                            candidateBases.append([top, bottom, shoe, layer])
                        }
                    }

                    for baseItems in candidateBases {
                        if requiresBlazer {
                            for blazer in blazers {
                                candidates.append(makeCandidate(
                                    scenario: scenario,
                                    items: baseItems + [blazer],
                                    targetFormality: targetFormality,
                                    weatherContext: weatherContext
                                ))
                            }
                        } else {
                            candidates.append(makeCandidate(
                                scenario: scenario,
                                items: baseItems,
                                targetFormality: targetFormality,
                                weatherContext: weatherContext
                            ))

                            for blazer in blazers {
                                candidates.append(makeCandidate(
                                    scenario: scenario,
                                    items: baseItems + [blazer],
                                    targetFormality: targetFormality,
                                    weatherContext: weatherContext
                                ))
                            }
                        }
                    }
                }
            }
        }

        return candidates
    }

    func makeCandidate(
        scenario: OutfitScenario,
        items: [ClothingItem],
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext?
    ) -> OutfitCandidate {
        OutfitCandidate(
            id: stableIdentifier(scenario: scenario, items: items),
            items: items,
            score: score(scenario: scenario, items: items, targetFormality: targetFormality, weatherContext: weatherContext),
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

    func score(
        scenario: OutfitScenario,
        items: [ClothingItem],
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext? = nil
    ) -> Int {
        let formalityScore = items.reduce(0) { total, item in
            total + max(0, 5 - abs(item.formalityLevel - targetFormality)) * 10
        }
        let weatherPreferenceScore = items.reduce(0) { total, item in
            total + weatherSuitabilityScore(for: item, type: item.resolvedType ?? .accessory, in: weatherContext)
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

        return formalityScore + scenarioBonus + weatherPreferenceScore - colorVarietyPenalty
    }

    func weatherContextScore(_ item: ClothingItem, type: ClothingType, in context: TomorrowWeatherContext) -> Int {
        weatherSuitabilityScore(for: item, type: type, in: context)
    }

    func weatherSuitabilityScore(for item: ClothingItem, type: ClothingType, in context: TomorrowWeatherContext?) -> Int {
        guard let context else { return 0 }

        var score = 0

        if context.isCold {
            score += max(0, item.warmthLevel) * 3
            if type == .outerwear {
                score += 10
            }
        }

        if context.isHot {
            if type == .outerwear || type == .blazer {
                score -= 14
            }
            if item.warmthLevel > 2 {
                score -= (item.warmthLevel - 2) * 2
            }
        }

        if context.isWindy {
            score += min(item.warmthLevel, 3)
            if type == .outerwear {
                score += 6
            }
        }

        if context.isRainLikely && type == .shoes {
            score += item.isRainSafeShoe ? 12 : -12
            if item.isRainFragileShoe {
                score -= 8
            }
        }

        return score
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

private extension ClothingItem {
    var isRainSafeShoe: Bool {
        let rainSafeKeywords = ["waterproof", "water-resistant", "rain", "boot", "boots", "hiking", "outdoor", "gore-tex", "防水", "雨靴", "靴"]
        return searchableWeatherText.contains { tag in
            let normalized = tag.lowercased()
            return rainSafeKeywords.contains { normalized.contains($0) }
        }
    }

    var isRainFragileShoe: Bool {
        let rainFragileKeywords = ["suede", "canvas", "satin", "麂皮", "帆布", "缎面"]
        return searchableWeatherText.contains { tag in
            let normalized = tag.lowercased()
            return rainFragileKeywords.contains { normalized.contains($0) }
        }
    }

    var searchableWeatherText: [String] {
        styleTags + [material, notes, color]
    }
}
