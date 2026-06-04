import Foundation
import SwiftData

@Model
final class UserPreference {
    var id: UUID
    var defaultScenarioRawValue: String
    var preferredFormality: Int
    var preferredColors: [String]
    var avoidedColors: [String]
    var preferredStyles: [String]
    var avoidedStyles: [String]
    var workplaceDressCode: String
    var cloudPhotoRecognitionEnabled: Bool = true
    var tomorrowWeatherEnabled: Bool = false
    var tomorrowWeatherLocationName: String = ""
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        defaultScenario: OutfitScenario = .dailyOffice,
        preferredFormality: Int = 3,
        preferredColors: [String] = [],
        avoidedColors: [String] = [],
        preferredStyles: [String] = [],
        avoidedStyles: [String] = [],
        workplaceDressCode: String = "",
        cloudPhotoRecognitionEnabled: Bool = true,
        tomorrowWeatherEnabled: Bool = false,
        tomorrowWeatherLocationName: String = "",
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.defaultScenarioRawValue = defaultScenario.rawValue
        self.preferredFormality = preferredFormality
        self.preferredColors = preferredColors
        self.avoidedColors = avoidedColors
        self.preferredStyles = preferredStyles
        self.avoidedStyles = avoidedStyles
        self.workplaceDressCode = workplaceDressCode
        self.cloudPhotoRecognitionEnabled = cloudPhotoRecognitionEnabled
        self.tomorrowWeatherEnabled = tomorrowWeatherEnabled
        self.tomorrowWeatherLocationName = tomorrowWeatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }

    var defaultScenario: OutfitScenario { OutfitScenario(rawValue: defaultScenarioRawValue) ?? .dailyOffice }
    var canRequestTomorrowWeather: Bool {
        tomorrowWeatherEnabled && !tomorrowWeatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func applySettings(
        defaultScenario: OutfitScenario,
        preferredFormality: Int,
        workplaceDressCode: String,
        cloudPhotoRecognitionEnabled: Bool,
        tomorrowWeatherEnabled: Bool = false,
        tomorrowWeatherLocationName: String = "",
        updatedAt: Date = Date()
    ) {
        self.defaultScenarioRawValue = defaultScenario.rawValue
        self.preferredFormality = min(max(preferredFormality, 1), 5)
        self.workplaceDressCode = workplaceDressCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.cloudPhotoRecognitionEnabled = cloudPhotoRecognitionEnabled
        self.tomorrowWeatherEnabled = tomorrowWeatherEnabled
        self.tomorrowWeatherLocationName = tomorrowWeatherLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.updatedAt = updatedAt
    }
}
