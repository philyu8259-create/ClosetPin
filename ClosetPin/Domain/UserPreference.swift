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

    init(
        id: UUID = UUID(),
        defaultScenario: OutfitScenario = .dailyOffice,
        preferredFormality: Int = 3,
        preferredColors: [String] = [],
        avoidedColors: [String] = [],
        preferredStyles: [String] = [],
        avoidedStyles: [String] = [],
        workplaceDressCode: String = ""
    ) {
        self.id = id
        self.defaultScenarioRawValue = defaultScenario.rawValue
        self.preferredFormality = preferredFormality
        self.preferredColors = preferredColors
        self.avoidedColors = avoidedColors
        self.preferredStyles = preferredStyles
        self.avoidedStyles = avoidedStyles
        self.workplaceDressCode = workplaceDressCode
    }

    var defaultScenario: OutfitScenario { OutfitScenario(rawValue: defaultScenarioRawValue) ?? .dailyOffice }
}
