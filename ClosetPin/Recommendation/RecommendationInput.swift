import Foundation

struct RecommendationInput {
    let scenario: OutfitScenario
    let season: SeasonTag
    let tomorrow: TomorrowRecommendationInput
    let maximumResults: Int
    let preferredFormality: Int?

    init(
        scenario: OutfitScenario,
        season: SeasonTag,
        tomorrow: TomorrowRecommendationInput = TomorrowRecommendationInput(),
        maximumResults: Int,
        preferredFormality: Int? = nil
    ) {
        self.scenario = scenario
        self.season = season
        self.tomorrow = tomorrow
        self.maximumResults = maximumResults
        self.preferredFormality = preferredFormality
    }
}
