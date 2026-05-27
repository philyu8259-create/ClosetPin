import Foundation

struct RecommendationInput {
    let scenario: OutfitScenario
    let season: SeasonTag
    let maximumResults: Int
    let preferredFormality: Int?

    init(
        scenario: OutfitScenario,
        season: SeasonTag,
        maximumResults: Int,
        preferredFormality: Int? = nil
    ) {
        self.scenario = scenario
        self.season = season
        self.maximumResults = maximumResults
        self.preferredFormality = preferredFormality
    }
}
