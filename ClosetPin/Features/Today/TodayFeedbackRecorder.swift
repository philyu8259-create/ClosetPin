import Foundation
import SwiftData

struct TodayFeedbackRecorder {
    struct RecordResult {
        let feedback: OutfitFeedback
        let outfit: Outfit?
    }

    func record(
        _ feedbackType: FeedbackType,
        candidate: OutfitCandidate,
        scenario: OutfitScenario,
        season: SeasonTag,
        explanation: String,
        in modelContext: ModelContext,
        now: Date = Date()
    ) throws -> RecordResult {
        let itemIds = candidate.items.map(\.id)
        let outfit = makeOutfitIfNeeded(
            feedbackType: feedbackType,
            itemIds: itemIds,
            candidate: candidate,
            scenario: scenario,
            season: season,
            explanation: explanation,
            now: now
        )

        if let outfit {
            modelContext.insert(outfit)
        }

        let feedback = OutfitFeedback(
            outfitId: outfit?.id,
            feedbackType: feedbackType,
            itemIds: itemIds,
            scenario: scenario
        )
        modelContext.insert(feedback)

        if feedbackType == .wore {
            markItemsWorn(candidate.items, at: now)
        }

        try modelContext.save()
        return RecordResult(feedback: feedback, outfit: outfit)
    }

    private func makeOutfitIfNeeded(
        feedbackType: FeedbackType,
        itemIds: [UUID],
        candidate: OutfitCandidate,
        scenario: OutfitScenario,
        season: SeasonTag,
        explanation: String,
        now: Date
    ) -> Outfit? {
        guard feedbackType == .saved else { return nil }

        return Outfit(
            itemIds: itemIds,
            scenario: scenario,
            dateContext: now,
            weatherNote: season.displayName,
            score: candidate.score,
            explanation: explanation,
            savedAt: now
        )
    }

    private func markItemsWorn(_ items: [ClothingItem], at date: Date) {
        for item in items {
            item.lastWornAt = date
            item.wearCount += 1
            item.updatedAt = date
        }
    }
}
