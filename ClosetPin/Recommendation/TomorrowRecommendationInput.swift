import Foundation

struct TomorrowRecommendationInput: Equatable {
    let weatherContext: TomorrowWeatherContext?

    init(weatherContext: TomorrowWeatherContext? = nil) {
        self.weatherContext = weatherContext
    }
}
