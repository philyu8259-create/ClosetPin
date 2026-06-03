import Foundation

enum TomorrowWeatherPreview {
    static let environmentKey = "CLOSETPIN_TOMORROW_WEATHER_PREVIEW"
    static let launchArgumentKey = "-\(environmentKey)"
    static let inlineLaunchArgumentPrefix = "--closetpin-tomorrow-weather="

    static var context: TomorrowWeatherContext? {
#if DEBUG
        guard let rawContext = ProcessInfo.processInfo.environment[environmentKey]
            ?? UserDefaults.standard.string(forKey: environmentKey)
            ?? rawContextFromArguments else {
            return nil
        }

        return context(from: rawContext)
#else
        nil
#endif
    }

    static func context(from rawContext: String) -> TomorrowWeatherContext? {
        if let presetContext = presetContext(for: rawContext) {
            return presetContext
        }

        guard let payloadData = rawContext.data(using: .utf8) else { return nil }
        guard let payload = try? JSONDecoder().decode(TomorrowWeatherPreviewPayload.self, from: payloadData) else {
            return nil
        }

        return payload.weatherContext
    }

    static func weatherSummary(for context: TomorrowWeatherContext) -> String {
        L10n.string(
            "today.tomorrow.weather_summary.format",
            arguments: context.condition.localizedName,
            context.minTemperatureCelsius,
            context.maxTemperatureCelsius,
            context.precipitationProbability,
            context.windSpeedKph
        )
    }

    static func preparationTips(for context: TomorrowWeatherContext) -> [String] {
        var tips: [String] = []

        if context.isCold {
            tips.append(L10n.text("today.tomorrow.prep.tip.outerwear"))
        }

        if context.isRainLikely {
            tips.append(L10n.text("today.tomorrow.prep.tip.rain_shoes"))
        }

        if context.isHot {
            tips.append(L10n.text("today.tomorrow.prep.tip.no_blazer"))
        } else if !context.isCold && !context.isRainLikely {
            tips.append(L10n.text("today.tomorrow.prep.tip.light_layer"))
        }

        if context.isWindy {
            tips.append(L10n.text("today.tomorrow.prep.tip.wind"))
        }

        if tips.count < 2 {
            tips.append(L10n.text("today.tomorrow.prep.tip.neutral"))
        }

        return Array(tips.prefix(3))
    }

    private static func presetContext(for rawContext: String) -> TomorrowWeatherContext? {
        switch rawContext
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_") {
        case "rain", "rainy_commute":
            TomorrowWeatherContext(
                condition: .rain,
                minTemperatureCelsius: 11,
                maxTemperatureCelsius: 18,
                precipitationProbability: 70,
                windSpeedKph: 22
            )
        case "cold", "cold_morning":
            TomorrowWeatherContext(
                condition: .cloudy,
                minTemperatureCelsius: 3,
                maxTemperatureCelsius: 10,
                precipitationProbability: 20,
                windSpeedKph: 18
            )
        case "hot", "hot_day":
            TomorrowWeatherContext(
                condition: .clear,
                minTemperatureCelsius: 27,
                maxTemperatureCelsius: 34,
                precipitationProbability: 10,
                windSpeedKph: 12
            )
        default:
            nil
        }
    }

    private static var rawContextFromArguments: String? {
        if let inlineArgument = CommandLine.arguments.first(where: { $0.hasPrefix(inlineLaunchArgumentPrefix) }) {
            return String(inlineArgument.dropFirst(inlineLaunchArgumentPrefix.count))
        }

        guard let index = CommandLine.arguments.firstIndex(of: launchArgumentKey),
              CommandLine.arguments.indices.contains(index + 1) else {
            return nil
        }

        return CommandLine.arguments[index + 1]
    }
}

struct TomorrowWeatherPreviewPayload: Decodable {
    let condition: TomorrowWeatherCondition
    let minTemperatureCelsius: Int
    let maxTemperatureCelsius: Int
    let precipitationProbability: Int
    let windSpeedKph: Int

    var weatherContext: TomorrowWeatherContext {
        TomorrowWeatherContext(
            condition: condition,
            minTemperatureCelsius: minTemperatureCelsius,
            maxTemperatureCelsius: maxTemperatureCelsius,
            precipitationProbability: precipitationProbability,
            windSpeedKph: windSpeedKph
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawCondition = try container.decode(String.self, forKey: .condition)
        condition = TomorrowWeatherCondition(debugValue: rawCondition) ?? .unknown
        minTemperatureCelsius = try container.decode(Int.self, forKey: .minTemperatureCelsius)
        maxTemperatureCelsius = try container.decode(Int.self, forKey: .maxTemperatureCelsius)
        precipitationProbability = try container.decode(Int.self, forKey: .precipitationProbability)
        windSpeedKph = try container.decode(Int.self, forKey: .windSpeedKph)
    }

    enum CodingKeys: String, CodingKey {
        case condition
        case minTemperatureCelsius
        case maxTemperatureCelsius
        case precipitationProbability
        case windSpeedKph
    }
}

extension TomorrowWeatherCondition {
    var localizedName: String {
        switch self {
        case .clear:
            L10n.text("today.tomorrow.condition.clear")
        case .partlyCloudy:
            L10n.text("today.tomorrow.condition.partly_cloudy")
        case .cloudy:
            L10n.text("today.tomorrow.condition.cloudy")
        case .lightRain:
            L10n.text("today.tomorrow.condition.light_rain")
        case .rain:
            L10n.text("today.tomorrow.condition.rain")
        case .thunderstorms:
            L10n.text("today.tomorrow.condition.thunderstorms")
        case .snow:
            L10n.text("today.tomorrow.condition.snow")
        case .wind:
            L10n.text("today.tomorrow.condition.wind")
        case .unknown:
            L10n.text("today.tomorrow.condition.unknown")
        }
    }
}

extension TomorrowWeatherCondition {
    init?(debugValue: String) {
        let normalized = debugValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")

        if let exact = TomorrowWeatherCondition(rawValue: normalized) {
            self = exact
            return
        }

        switch normalized {
        case "partly cloudy", "partlycloudy", "partly_cloud", "partly_cloudy", "partlycloud":
            self = .partlyCloudy
        case "light rain", "lightrain", "light_rain", "drizzle":
            self = .lightRain
        case "heavy rain", "rain", "raining":
            self = .rain
        case "storm", "stormy", "thunderstorm", "thunder_storm":
            self = .thunderstorms
        case "windy":
            self = .wind
        case "clear sky", "sun":
            self = .clear
        case "overcast":
            self = .cloudy
        case "snowy":
            self = .snow
        default:
            self = .unknown
            return
        }
    }
}
