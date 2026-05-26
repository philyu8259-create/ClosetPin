import Foundation
import SwiftData

@Model
final class Outfit {
    var id: UUID
    var itemIds: [UUID]
    var scenarioRawValue: String
    var dateContext: Date
    var weatherNote: String
    var score: Int
    var explanation: String
    var createdAt: Date
    var savedAt: Date?
    var wornAt: Date?

    init(
        id: UUID = UUID(),
        itemIds: [UUID],
        scenario: OutfitScenario,
        dateContext: Date,
        weatherNote: String,
        score: Int,
        explanation: String,
        savedAt: Date? = nil,
        wornAt: Date? = nil
    ) {
        self.id = id
        self.itemIds = itemIds
        self.scenarioRawValue = scenario.rawValue
        self.dateContext = dateContext
        self.weatherNote = weatherNote
        self.score = score
        self.explanation = explanation
        self.createdAt = Date()
        self.savedAt = savedAt
        self.wornAt = wornAt
    }

    var scenario: OutfitScenario { OutfitScenario(rawValue: scenarioRawValue) ?? .dailyOffice }
}
