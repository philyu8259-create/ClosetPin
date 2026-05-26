import Foundation
import SwiftData

@Model
final class OutfitFeedback {
    var id: UUID
    var outfitId: UUID?
    var feedbackTypeRawValue: String
    var itemIds: [UUID]
    var scenarioRawValue: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        outfitId: UUID? = nil,
        feedbackType: FeedbackType,
        itemIds: [UUID],
        scenario: OutfitScenario
    ) {
        self.id = id
        self.outfitId = outfitId
        self.feedbackTypeRawValue = feedbackType.rawValue
        self.itemIds = itemIds
        self.scenarioRawValue = scenario.rawValue
        self.createdAt = Date()
    }

    var feedbackType: FeedbackType { FeedbackType(rawValue: feedbackTypeRawValue) ?? .skipped }
    var scenario: OutfitScenario { OutfitScenario(rawValue: scenarioRawValue) ?? .dailyOffice }
}
