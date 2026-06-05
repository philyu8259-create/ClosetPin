import Foundation

private let maximumItemsPerCategory = 12
private let diversifiedCandidatePoolLimit = 48
private let optionalItemVariantLimit = 2

struct RecommendationEngine {
    func recommend(
        input: RecommendationInput,
        items: [ClothingItem],
        feedback: [OutfitFeedback]
    ) -> [OutfitCandidate] {
        guard input.maximumResults > 0 else { return [] }

        let groupedItems = Dictionary(grouping: eligibleItems(from: items, for: input.season)) { item in
            item.resolvedType ?? .accessory
        }
        let itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        let avoidedCoreSignatures = avoidedCoreSignatures(from: feedback, itemsByID: itemsByID, scenario: input.scenario)
        let avoidedItemIDSets = avoidedItemIDSets(from: feedback, scenario: input.scenario)
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
        let bags = filteredAndPreselected(
            groupedItems[.bag] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .bag
        )
        let accessories = filteredAndPreselected(
            groupedItems[.accessory] ?? [],
            threshold: threshold,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            category: .accessory
        )

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
                bags: bags,
                accessories: accessories,
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
                bags: bags,
                accessories: accessories,
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
                bags: bags,
                accessories: accessories,
                targetFormality: targetFormality,
                requiresBlazer: requiresBlazerForMeeting,
                weatherContext: weatherContext
            )
        }

        let rankedCandidates = candidates
            .sorted { lhs, rhs in
                let lhsScore = adjustedScore(
                    for: lhs,
                    avoidedCoreSignatures: avoidedCoreSignatures,
                    avoidedItemIDSets: avoidedItemIDSets
                )
                let rhsScore = adjustedScore(
                    for: rhs,
                    avoidedCoreSignatures: avoidedCoreSignatures,
                    avoidedItemIDSets: avoidedItemIDSets
                )
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.explanationSeed < rhs.explanationSeed
            }

        return diversifiedCandidates(
            from: Array(rankedCandidates.prefix(max(diversifiedCandidatePoolLimit, input.maximumResults))),
            maximumResults: input.maximumResults,
            avoidedCoreSignatures: avoidedCoreSignatures,
            avoidedItemIDSets: avoidedItemIDSets
        )
    }
}

private extension RecommendationEngine {
    func adjustedScore(
        for candidate: OutfitCandidate,
        avoidedCoreSignatures: Set<String>,
        avoidedItemIDSets: [Set<UUID>]
    ) -> Int {
        let candidateItemIDs = Set(candidate.items.map(\.id))
        let isRecentlyRejectedOutfit = avoidedItemIDSets.contains { avoidedIDs in
            avoidedIDs.isSubset(of: candidateItemIDs)
        }
        let recentlyRejectedPenalty = avoidedCoreSignatures.contains(coreSignature(for: candidate.items)) || isRecentlyRejectedOutfit ? 96 : 0
        return candidate.score - recentlyRejectedPenalty
    }

    func diversifiedCandidates(
        from candidates: [OutfitCandidate],
        maximumResults: Int,
        avoidedCoreSignatures: Set<String>,
        avoidedItemIDSets: [Set<UUID>]
    ) -> [OutfitCandidate] {
        guard maximumResults > 0 else { return [] }
        var selected: [OutfitCandidate] = []
        var remaining = candidates

        while selected.count < maximumResults, remaining.isEmpty == false {
            let nextIndex = remaining.indices.max { lhsIndex, rhsIndex in
                let lhs = remaining[lhsIndex]
                let rhs = remaining[rhsIndex]
                let lhsScore = diversifiedSelectionScore(
                    for: lhs,
                    selectedCandidates: selected,
                    avoidedCoreSignatures: avoidedCoreSignatures,
                    avoidedItemIDSets: avoidedItemIDSets
                )
                let rhsScore = diversifiedSelectionScore(
                    for: rhs,
                    selectedCandidates: selected,
                    avoidedCoreSignatures: avoidedCoreSignatures,
                    avoidedItemIDSets: avoidedItemIDSets
                )
                if lhsScore != rhsScore {
                    return lhsScore < rhsScore
                }
                return lhs.explanationSeed > rhs.explanationSeed
            }

            guard let nextIndex else { break }
            selected.append(remaining.remove(at: nextIndex))
        }

        return selected
    }

    func diversifiedSelectionScore(
        for candidate: OutfitCandidate,
        selectedCandidates: [OutfitCandidate],
        avoidedCoreSignatures: Set<String>,
        avoidedItemIDSets: [Set<UUID>]
    ) -> Int {
        let feedbackAdjustedScore = adjustedScore(
            for: candidate,
            avoidedCoreSignatures: avoidedCoreSignatures,
            avoidedItemIDSets: avoidedItemIDSets
        )
        guard selectedCandidates.isEmpty == false else { return feedbackAdjustedScore }

        let similarityPenalty = selectedCandidates
            .map { outfitSimilarityPenalty(candidate.items, $0.items) }
            .max() ?? 0
        return feedbackAdjustedScore - similarityPenalty
    }

    func outfitSimilarityPenalty(_ lhs: [ClothingItem], _ rhs: [ClothingItem]) -> Int {
        let lhsByType = itemsByResolvedType(lhs)
        let rhsByType = itemsByResolvedType(rhs)
        var penalty = 0

        if lhsByType[.top]?.id == rhsByType[.top]?.id {
            penalty += 12
        }
        if lhsByType[.bottom]?.id == rhsByType[.bottom]?.id {
            penalty += 36
        }
        if lhsByType[.shoes]?.id == rhsByType[.shoes]?.id {
            penalty += 32
        }
        if lhsByType[.outerwear]?.id == rhsByType[.outerwear]?.id || lhsByType[.blazer]?.id == rhsByType[.blazer]?.id {
            penalty += 10
        }
        if lhsByType[.bag]?.id == rhsByType[.bag]?.id {
            penalty += 6
        }
        if lhsByType[.accessory]?.id == rhsByType[.accessory]?.id {
            penalty += 6
        }

        return penalty
    }

    func itemsByResolvedType(_ items: [ClothingItem]) -> [ClothingType: ClothingItem] {
        Dictionary(items.map { ($0.resolvedType ?? .accessory, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func avoidedCoreSignatures(
        from feedback: [OutfitFeedback],
        itemsByID: [UUID: ClothingItem],
        scenario: OutfitScenario
    ) -> Set<String> {
        let avoidTypes: Set<FeedbackType> = [.disliked, .skipped, .swapped]

        return Set(feedback
            .filter { $0.scenario == scenario && avoidTypes.contains($0.feedbackType) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .compactMap { feedback in
                let feedbackItems = feedback.itemIds.compactMap { itemsByID[$0] }
                return coreSignature(for: feedbackItems)
            })
    }

    func avoidedItemIDSets(from feedback: [OutfitFeedback], scenario: OutfitScenario) -> [Set<UUID>] {
        let avoidTypes: Set<FeedbackType> = [.disliked, .skipped, .swapped]

        return feedback
            .filter { $0.scenario == scenario && avoidTypes.contains($0.feedbackType) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(12)
            .map { Set($0.itemIds) }
    }

    func coreSignature(for items: [ClothingItem]) -> String {
        let byType = itemsByResolvedType(items)
        return [
            byType[.top]?.id.uuidString ?? "no-top",
            byType[.bottom]?.id.uuidString ?? "no-bottom",
            byType[.shoes]?.id.uuidString ?? "no-shoes"
        ].joined(separator: "|")
    }

    func eligibleItems(from items: [ClothingItem], for season: SeasonTag) -> [ClothingItem] {
        items.filter { item in
            guard let type = item.resolvedType else { return false }

            return item.resolvedStatus == .available
                && item.seasons.contains(season)
                && recommendableTypes.contains(type)
        }
    }

    var recommendableTypes: Set<ClothingType> {
        [.top, .bottom, .shoes, .blazer, .outerwear, .bag, .accessory]
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
        bags: [ClothingItem],
        accessories: [ClothingItem],
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
                                for variant in enrichedItems(
                                    baseItems + [blazer],
                                    bags: bags,
                                    accessories: accessories,
                                    targetFormality: targetFormality,
                                    weatherContext: weatherContext
                                ) {
                                    candidates.append(makeCandidate(
                                        scenario: scenario,
                                        items: variant,
                                        targetFormality: targetFormality,
                                        weatherContext: weatherContext
                                    ))
                                }
                            }
                        } else {
                            for variant in enrichedItems(
                                baseItems,
                                bags: bags,
                                accessories: accessories,
                                targetFormality: targetFormality,
                                weatherContext: weatherContext
                            ) {
                                candidates.append(makeCandidate(
                                    scenario: scenario,
                                    items: variant,
                                    targetFormality: targetFormality,
                                    weatherContext: weatherContext
                                ))
                            }
                            for blazer in blazers {
                                for variant in enrichedItems(
                                    baseItems + [blazer],
                                    bags: bags,
                                    accessories: accessories,
                                    targetFormality: targetFormality,
                                    weatherContext: weatherContext
                                ) {
                                    candidates.append(makeCandidate(
                                        scenario: scenario,
                                        items: variant,
                                        targetFormality: targetFormality,
                                        weatherContext: weatherContext
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        return candidates
    }

    func enrichedItems(
        _ baseItems: [ClothingItem],
        bags: [ClothingItem],
        accessories: [ClothingItem],
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext?
    ) -> [[ClothingItem]] {
        let topBags = topOptionalItems(
            from: bags,
            excluding: baseItems,
            targetFormality: targetFormality,
            weatherContext: weatherContext
        )
        let topAccessories = topOptionalItems(
            from: accessories,
            excluding: baseItems,
            targetFormality: targetFormality,
            weatherContext: weatherContext
        )
        var enriched: [[ClothingItem]] = []

        let bagChoices: [ClothingItem?] = [nil] + topBags.map { Optional($0) }
        let accessoryChoices: [ClothingItem?] = [nil] + topAccessories.map { Optional($0) }

        for bag in bagChoices {
            for accessory in accessoryChoices {
                var variant = baseItems
                if let bag {
                    variant.append(bag)
                }
                if let accessory {
                    variant.append(accessory)
                }
                enriched.append(variant)
            }
        }

        return enriched
    }

    func topOptionalItems(
        from options: [ClothingItem],
        excluding selectedItems: [ClothingItem],
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext?,
        maximum: Int = optionalItemVariantLimit
    ) -> [ClothingItem] {
        let selectedIDs = Set(selectedItems.map(\.id))

        return options
            .filter { !selectedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let lhsScore = optionalItemScore(lhs, selectedItems: selectedItems, targetFormality: targetFormality, weatherContext: weatherContext)
                let rhsScore = optionalItemScore(rhs, selectedItems: selectedItems, targetFormality: targetFormality, weatherContext: weatherContext)
                if lhsScore != rhsScore {
                    return lhsScore > rhsScore
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
            .prefix(maximum)
            .map { $0 }
    }

    func bestOptionalItem(
        from options: [ClothingItem],
        excluding selectedItems: [ClothingItem],
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext?
    ) -> ClothingItem? {
        return topOptionalItems(
            from: options,
            excluding: selectedItems,
            targetFormality: targetFormality,
            weatherContext: weatherContext,
            maximum: 1
        ).first
    }

    func optionalItemScore(
        _ item: ClothingItem,
        selectedItems: [ClothingItem],
        targetFormality: Int,
        weatherContext: TomorrowWeatherContext?
    ) -> Int {
        let type = item.resolvedType ?? .accessory
        let formalityFit = max(0, 5 - abs(item.formalityLevel - targetFormality)) * 4
        let weatherFit = weatherSuitabilityScore(for: item, type: type, in: weatherContext)
        let repeatedColorBonus = selectedItems.contains { $0.displayColor == item.displayColor } ? 4 : 0
        let neutralBonus = ColorResolver.localizedDisplayColor(from: item.color) != nil ? 2 : 0

        return formalityFit + weatherFit + repeatedColorBonus + neutralBonus
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
        let colorHarmonyScore = colorHarmonyScore(for: items)

        return formalityScore + scenarioBonus + weatherPreferenceScore + colorHarmonyScore - colorVarietyPenalty
    }

    func colorHarmonyScore(for items: [ClothingItem]) -> Int {
        let swatchKinds = items.map { ColorResolver.swatchKind(for: $0.color) }
        let uniqueKinds = Set(swatchKinds)
        let accentKinds = uniqueKinds.filter { !neutralSwatchKinds.contains($0) }
        let neutralCount = swatchKinds.filter { neutralSwatchKinds.contains($0) }.count
        var score = 0

        if neutralCount >= 2 {
            score += 8
        }
        if accentKinds.count <= 1 {
            score += 8
        } else {
            score -= (accentKinds.count - 1) * 7
        }
        if uniqueKinds.count <= 3 {
            score += 4
        } else {
            score -= (uniqueKinds.count - 3) * 4
        }

        return score
    }

    var neutralSwatchKinds: Set<ColorResolver.SwatchKind> {
        [.black, .white, .navy, .gray, .brown]
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
