import CoreLocation
import Foundation
#if canImport(WeatherKit)
import WeatherKit
#endif

struct TomorrowWeatherSnapshot: Equatable, Sendable {
    let context: TomorrowWeatherContext
    let locationName: String
    let attributionName: String?
    let attributionURL: URL?
}

@MainActor
protocol TomorrowWeatherProviding {
    func tomorrowWeather(for locationName: String, referenceDate: Date) async throws -> TomorrowWeatherSnapshot
}

enum TomorrowWeatherProviderError: LocalizedError {
    case missingLocation
    case locationNotFound
    case weatherUnavailable

    var errorDescription: String? {
        switch self {
        case .missingLocation:
            "Add a city to enable tomorrow weather."
        case .locationNotFound:
            "That city could not be found."
        case .weatherUnavailable:
            "Tomorrow weather is unavailable right now."
        }
    }
}

enum TomorrowWeatherConditionMapper {
    static func condition(from rawValue: String) -> TomorrowWeatherCondition {
        switch normalized(rawValue) {
        case "clear", "mostlyclear", "hot":
            .clear
        case "partlycloudy":
            .partlyCloudy
        case "mostlycloudy", "cloudy", "foggy", "haze", "smoky":
            .cloudy
        case "drizzle", "freezingdrizzle", "sunshowers":
            .lightRain
        case "rain", "heavyrain", "freezingrain", "sleet", "hail":
            .rain
        case "isolatedthunderstorms", "scatteredthunderstorms", "thunderstorms", "strongstorms", "tropicalstorm", "hurricane":
            .thunderstorms
        case "snow", "heavysnow", "blowingsnow", "blizzard", "flurries", "sunflurries", "wintrymix", "frigid":
            .snow
        case "breezy", "windy", "blowingdust":
            .wind
        default:
            .unknown
        }
    }

    private static func normalized(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}

@MainActor
struct WeatherKitTomorrowWeatherProvider: TomorrowWeatherProviding {
    private let geocoder = CLGeocoder()

    func tomorrowWeather(for locationName: String, referenceDate: Date = Date()) async throws -> TomorrowWeatherSnapshot {
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLocation.isEmpty else {
            throw TomorrowWeatherProviderError.missingLocation
        }

#if canImport(WeatherKit)
        let placemarks = try await geocoder.geocodeAddressString(trimmedLocation)
        guard let location = placemarks.first?.location else {
            throw TomorrowWeatherProviderError.locationNotFound
        }

        let calendar = Calendar.current
        let tomorrowStart = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: referenceDate) ?? referenceDate)
        let dayAfterTomorrow = calendar.date(byAdding: .day, value: 1, to: tomorrowStart) ?? tomorrowStart.addingTimeInterval(86_400)
        return try await Self.fetchWeatherSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            locationName: trimmedLocation,
            tomorrowStart: tomorrowStart,
            dayAfterTomorrow: dayAfterTomorrow
        )
#else
        throw TomorrowWeatherProviderError.weatherUnavailable
#endif
    }

#if canImport(WeatherKit)
    private nonisolated static func fetchWeatherSnapshot(
        latitude: Double,
        longitude: Double,
        locationName: String,
        tomorrowStart: Date,
        dayAfterTomorrow: Date
    ) async throws -> TomorrowWeatherSnapshot {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        let forecast = try await WeatherService.shared.weather(
            for: location,
            including: .daily(startDate: tomorrowStart, endDate: dayAfterTomorrow)
        )

        guard let tomorrow = forecast.forecast.first else {
            throw TomorrowWeatherProviderError.weatherUnavailable
        }

        let attribution = try? await WeatherService.shared.attribution
        return TomorrowWeatherSnapshot(
            context: TomorrowWeatherContext(
                condition: TomorrowWeatherConditionMapper.condition(from: tomorrow.condition.rawValue),
                minTemperatureCelsius: Int(tomorrow.lowTemperature.converted(to: .celsius).value.rounded()),
                maxTemperatureCelsius: Int(tomorrow.highTemperature.converted(to: .celsius).value.rounded()),
                precipitationProbability: Int((tomorrow.precipitationChance * 100).rounded()),
                windSpeedKph: Int(tomorrow.wind.speed.converted(to: .kilometersPerHour).value.rounded())
            ),
            locationName: locationName,
            attributionName: attribution?.serviceName,
            attributionURL: attribution?.legalPageURL
        )
    }
#endif
}
