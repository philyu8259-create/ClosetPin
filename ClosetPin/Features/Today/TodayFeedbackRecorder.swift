import Foundation
import SwiftData

struct TodayFeedbackRecorder {
    enum RecordOutcome: Equatable {
        case recorded
        case alreadyRecorded
    }

    struct RecordResult {
        let feedback: OutfitFeedback
        let outfit: Outfit?
        let outcome: RecordOutcome
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

        if feedbackType.isIdempotentForSameDay,
           let existingFeedback = try existingFeedback(
            feedbackType: feedbackType,
            itemIds: itemIds,
            scenario: scenario,
            in: modelContext,
            now: now
            ) {
            let existingOutfit = try existingFeedback.outfitId.flatMap { outfitId in
                try storedOutfit(with: outfitId, in: modelContext)
            }
            return RecordResult(
                feedback: existingFeedback,
                outfit: existingOutfit,
                outcome: .alreadyRecorded
            )
        }

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
        feedback.createdAt = now
        modelContext.insert(feedback)

        if feedbackType == .wore {
            markItemsWorn(candidate.items, at: now)
        }

        try modelContext.save()
        return RecordResult(feedback: feedback, outfit: outfit, outcome: .recorded)
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

    private func existingFeedback(
        feedbackType: FeedbackType,
        itemIds: [UUID],
        scenario: OutfitScenario,
        in modelContext: ModelContext,
        now: Date
    ) throws -> OutfitFeedback? {
        let targetItemIDs = Set(itemIds)
        let calendar = Calendar.current
        let feedback = try modelContext.fetch(FetchDescriptor<OutfitFeedback>())

        return feedback
            .filter { existing in
                existing.feedbackType == feedbackType
                    && existing.scenario == scenario
                    && Set(existing.itemIds) == targetItemIDs
                    && calendar.isDate(existing.createdAt, inSameDayAs: now)
            }
            .sorted { $0.createdAt > $1.createdAt }
            .first
    }

    private func storedOutfit(with id: UUID, in modelContext: ModelContext) throws -> Outfit? {
        let outfits = try modelContext.fetch(FetchDescriptor<Outfit>())
        return outfits.first { $0.id == id }
    }

    private func markItemsWorn(_ items: [ClothingItem], at date: Date) {
        for item in items {
            item.lastWornAt = date
            item.wearCount += 1
            item.updatedAt = date
        }
    }
}

private extension FeedbackType {
    var isIdempotentForSameDay: Bool {
        switch self {
        case .wore, .saved:
            true
        case .liked, .disliked, .skipped, .swapped:
            // Preference signals can be repeated for now; Wore and Save alter
            // durable counts/records and are guarded per candidate, scenario, and local day.
            false
        }
    }
}
