import Foundation

struct TomorrowRecommendationInput: Equatable, Sendable {
    let weatherContext: TomorrowWeatherContext?

    init(weatherContext: TomorrowWeatherContext? = nil) {
        self.weatherContext = weatherContext
    }
}
