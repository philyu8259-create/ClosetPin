import Foundation

enum TomorrowWeatherCondition: String, Codable {
    case clear
    case partlyCloudy
    case cloudy
    case lightRain
    case rain
    case thunderstorms
    case snow
    case wind
    case unknown

    var isRainLike: Bool {
        switch self {
        case .lightRain, .rain, .thunderstorms:
            true
        default:
            false
        }
    }
}

struct TomorrowWeatherContext: Equatable {
    let condition: TomorrowWeatherCondition
    let minTemperatureCelsius: Int
    let maxTemperatureCelsius: Int
    let precipitationProbability: Int
    let windSpeedKph: Int

    init(
        condition: TomorrowWeatherCondition,
        minTemperatureCelsius: Int,
        maxTemperatureCelsius: Int,
        precipitationProbability: Int,
        windSpeedKph: Int
    ) {
        self.condition = condition
        self.minTemperatureCelsius = minTemperatureCelsius
        self.maxTemperatureCelsius = maxTemperatureCelsius
        self.precipitationProbability = precipitationProbability
        self.windSpeedKph = windSpeedKph
    }
}

extension TomorrowWeatherContext {
    var isCold: Bool {
        maxTemperatureCelsius <= 12
    }

    var isHot: Bool {
        minTemperatureCelsius >= 26
    }

    var isRainLikely: Bool {
        condition.isRainLike || precipitationProbability >= 45
    }

    var isWindy: Bool {
        windSpeedKph >= 28
    }
}
