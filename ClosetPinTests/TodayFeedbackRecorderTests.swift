import SwiftData
import XCTest
@testable import ClosetPin

@MainActor
final class TodayFeedbackRecorderTests: XCTestCase {
    func testWoreRecordsFeedbackAndUpdatesCandidateItems() throws {
        let context = try makeInMemoryModelContext()
        let items = [
            clothingItem(id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!, type: .top),
            clothingItem(id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!, type: .bottom),
            clothingItem(id: UUID(uuidString: "10000000-0000-0000-0000-000000000003")!, type: .shoes)
        ]
        items.forEach(context.insert)
        try context.save()
        let candidate = OutfitCandidate(id: "dailyOffice:test", items: items, score: 72, explanationSeed: "seed")
        let wornAt = Date(timeIntervalSince1970: 42)

        let result = try TodayFeedbackRecorder().record(
            .wore,
            candidate: candidate,
            scenario: .dailyOffice,
            season: .spring,
            explanation: "A practical office option.",
            in: context,
            now: wornAt
        )

        XCTAssertEqual(result.outcome, .recorded)
        let outfit = try XCTUnwrap(result.outfit)
        XCTAssertEqual(outfit.itemIds, items.map(\.id))
        XCTAssertEqual(outfit.scenario, .dailyOffice)
        XCTAssertEqual(outfit.weatherNote, SeasonTag.spring.displayName)
        XCTAssertEqual(outfit.score, 72)
        XCTAssertEqual(outfit.explanation, "A practical office option.")
        XCTAssertNil(outfit.savedAt)
        XCTAssertEqual(outfit.wornAt, wornAt)
        XCTAssertEqual(result.feedback.feedbackType, .wore)
        XCTAssertEqual(result.feedback.scenario, .dailyOffice)
        XCTAssertEqual(result.feedback.itemIds, items.map(\.id))
        XCTAssertEqual(result.feedback.outfitId, outfit.id)
        XCTAssertEqual(items.map(\.wearCount), [1, 1, 1])
        XCTAssertEqual(items.map(\.lastWornAt), [wornAt, wornAt, wornAt])

        let fetchedOutfits = try context.fetch(FetchDescriptor<Outfit>())
        let fetchedFeedback = try context.fetch(FetchDescriptor<OutfitFeedback>())
        XCTAssertEqual(fetchedOutfits.count, 1)
        XCTAssertEqual(fetchedFeedback.count, 1)
        XCTAssertEqual(fetchedFeedback.first?.feedbackType, .wore)
        XCTAssertEqual(fetchedFeedback.first?.outfitId, fetchedOutfits.first?.id)
    }

    func testSavePersistsOutfitAndSavedFeedback() throws {
        let context = try makeInMemoryModelContext()
        let items = [
            clothingItem(id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!, type: .top),
            clothingItem(id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!, type: .bottom),
            clothingItem(id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!, type: .shoes)
        ]
        items.forEach(context.insert)
        try context.save()
        let candidate = OutfitCandidate(id: "dailyOffice:save", items: items, score: 80, explanationSeed: "seed")
        let savedAt = Date(timeIntervalSince1970: 99)

        let result = try TodayFeedbackRecorder().record(
            .saved,
            candidate: candidate,
            scenario: .dailyOffice,
            season: .spring,
            explanation: "A polished office mix.",
            in: context,
            now: savedAt
        )

        XCTAssertEqual(result.outcome, .recorded)
        let outfit = try XCTUnwrap(result.outfit)
        XCTAssertEqual(outfit.itemIds, items.map(\.id))
        XCTAssertEqual(outfit.scenario, .dailyOffice)
        XCTAssertEqual(outfit.weatherNote, SeasonTag.spring.displayName)
        XCTAssertEqual(outfit.score, 80)
        XCTAssertEqual(outfit.explanation, "A polished office mix.")
        XCTAssertEqual(outfit.savedAt, savedAt)
        XCTAssertNil(outfit.wornAt)

        XCTAssertEqual(result.feedback.feedbackType, .saved)
        XCTAssertEqual(result.feedback.itemIds, items.map(\.id))
        XCTAssertEqual(result.feedback.outfitId, outfit.id)

        let fetchedOutfits = try context.fetch(FetchDescriptor<Outfit>())
        let fetchedFeedback = try context.fetch(FetchDescriptor<OutfitFeedback>())
        XCTAssertEqual(fetchedOutfits.count, 1)
        XCTAssertEqual(fetchedFeedback.count, 1)
        XCTAssertEqual(fetchedFeedback.first?.outfitId, fetchedOutfits.first?.id)
    }

    func testDuplicateWoreSameCandidateScenarioAndDayDoesNotDoubleIncrement() throws {
        let context = try makeInMemoryModelContext()
        let items = [
            clothingItem(id: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!, type: .top),
            clothingItem(id: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!, type: .bottom),
            clothingItem(id: UUID(uuidString: "30000000-0000-0000-0000-000000000003")!, type: .shoes)
        ]
        items.forEach(context.insert)
        try context.save()
        let candidate = OutfitCandidate(id: "dailyOffice:wore-duplicate", items: items, score: 72, explanationSeed: "seed")
        let firstTap = Date(timeIntervalSince1970: 3_600)
        let secondTap = Date(timeIntervalSince1970: 7_200)

        let firstResult = try TodayFeedbackRecorder().record(
            .wore,
            candidate: candidate,
            scenario: .dailyOffice,
            season: .spring,
            explanation: "A practical office option.",
            in: context,
            now: firstTap
        )
        let secondResult = try TodayFeedbackRecorder().record(
            .wore,
            candidate: candidate,
            scenario: .dailyOffice,
            season: .spring,
            explanation: "A practical office option.",
            in: context,
            now: secondTap
        )

        XCTAssertEqual(firstResult.outcome, .recorded)
        XCTAssertEqual(secondResult.outcome, .alreadyRecorded)
        XCTAssertEqual(secondResult.feedback.id, firstResult.feedback.id)
        XCTAssertEqual(secondResult.outfit?.id, firstResult.outfit?.id)
        XCTAssertEqual(items.map(\.wearCount), [1, 1, 1])
        XCTAssertEqual(items.map(\.lastWornAt), [firstTap, firstTap, firstTap])

        let fetchedOutfits = try context.fetch(FetchDescriptor<Outfit>())
        let fetchedFeedback = try context.fetch(FetchDescriptor<OutfitFeedback>())
        XCTAssertEqual(fetchedOutfits.count, 1)
        XCTAssertEqual(fetchedFeedback.count, 1)
        XCTAssertEqual(fetchedOutfits.first?.wornAt, firstTap)
        XCTAssertEqual(fetchedFeedback.first?.outfitId, fetchedOutfits.first?.id)
    }

    func testDuplicateSaveSameCandidateScenarioAndDayDoesNotCreateMultipleRecords() throws {
        let context = try makeInMemoryModelContext()
        let items = [
            clothingItem(id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!, type: .top),
            clothingItem(id: UUID(uuidString: "40000000-0000-0000-0000-000000000002")!, type: .bottom),
            clothingItem(id: UUID(uuidString: "40000000-0000-0000-0000-000000000003")!, type: .shoes)
        ]
        items.forEach(context.insert)
        try context.save()
        let candidate = OutfitCandidate(id: "dailyOffice:save-duplicate", items: items, score: 80, explanationSeed: "seed")
        let firstTap = Date(timeIntervalSince1970: 3_600)
        let secondTap = Date(timeIntervalSince1970: 7_200)

        let firstResult = try TodayFeedbackRecorder().record(
            .saved,
            candidate: candidate,
            scenario: .dailyOffice,
            season: .spring,
            explanation: "A polished office mix.",
            in: context,
            now: firstTap
        )
        let secondResult = try TodayFeedbackRecorder().record(
            .saved,
            candidate: candidate,
            scenario: .dailyOffice,
            season: .spring,
            explanation: "A polished office mix.",
            in: context,
            now: secondTap
        )

        XCTAssertEqual(firstResult.outcome, .recorded)
        XCTAssertEqual(secondResult.outcome, .alreadyRecorded)
        XCTAssertEqual(secondResult.feedback.id, firstResult.feedback.id)
        XCTAssertEqual(secondResult.outfit?.id, firstResult.outfit?.id)

        let fetchedOutfits = try context.fetch(FetchDescriptor<Outfit>())
        let fetchedFeedback = try context.fetch(FetchDescriptor<OutfitFeedback>())
        XCTAssertEqual(fetchedOutfits.count, 1)
        XCTAssertEqual(fetchedFeedback.count, 1)
        XCTAssertEqual(fetchedOutfits.first?.savedAt, firstTap)
        XCTAssertEqual(fetchedFeedback.first?.createdAt, firstTap)
    }

    func testUndoWoreFeedbackRollsBackWearCountsAndLastWornAt() throws {
        let context = try makeInMemoryModelContext()
        let recorder = TodayFeedbackRecorder()
        let items = [
            clothingItem(id: UUID(uuidString: "50000000-0000-0000-0000-000000000001")!, type: .top),
            clothingItem(id: UUID(uuidString: "50000000-0000-0000-0000-000000000002")!, type: .bottom),
            clothingItem(id: UUID(uuidString: "50000000-0000-0000-0000-000000000003")!, type: .shoes),
            clothingItem(id: UUID(uuidString: "50000000-0000-0000-0000-000000000004")!, type: .blazer)
        ]
        items.forEach(context.insert)
        try context.save()

        let firstTimestamp = Date(timeIntervalSince1970: 1_000)
        let secondTimestamp = Date(timeIntervalSince1970: 2_000)

        let firstResult = try recorder.record(
            .wore,
            candidate: OutfitCandidate(id: "dailyOffice:wore-undo", items: Array(items[0...1]), score: 74, explanationSeed: "seed"),
            scenario: .dailyOffice,
            season: .spring,
            explanation: "First record",
            in: context,
            now: firstTimestamp
        )
        let secondResult = try recorder.record(
            .wore,
            candidate: OutfitCandidate(id: "dailyOffice:wore-undo-2", items: [items[0], items[2]], score: 68, explanationSeed: "seed"),
            scenario: .dailyOffice,
            season: .spring,
            explanation: "Second record",
            in: context,
            now: secondTimestamp
        )

        try recorder.undoFeedback(
            feedbackID: firstResult.feedback.id,
            outfitID: firstResult.outfit?.id,
            in: context
        )

        let fetchedItems = try context.fetch(FetchDescriptor<ClothingItem>())
            .reduce(into: [UUID: ClothingItem]()) { $0[$1.id] = $1 }
        XCTAssertEqual(fetchedItems[items[0].id]?.wearCount, 1)
        XCTAssertEqual(fetchedItems[items[0].id]?.lastWornAt, secondTimestamp)
        XCTAssertEqual(fetchedItems[items[1].id]?.wearCount, 0)
        XCTAssertNil(fetchedItems[items[1].id]?.lastWornAt)
        XCTAssertEqual(fetchedItems[items[2].id]?.wearCount, 1)
        XCTAssertEqual(fetchedItems[items[2].id]?.lastWornAt, secondTimestamp)
        XCTAssertEqual(fetchedItems[items[3].id]?.wearCount, 0)
        XCTAssertNil(fetchedItems[items[3].id]?.lastWornAt)

        let outfits = try context.fetch(FetchDescriptor<Outfit>())
        let feedbacks = try context.fetch(FetchDescriptor<OutfitFeedback>())
        XCTAssertEqual(feedbacks.count, 1)
        XCTAssertEqual(outfits.count, 1)
        XCTAssertEqual(feedbacks.first?.id, secondResult.feedback.id)
        XCTAssertEqual(outfits.first?.id, secondResult.outfit?.id)
    }

    func testUndoNonWoreFeedbackDoesNotModifyWearStatistics() throws {
        let context = try makeInMemoryModelContext()
        let recorder = TodayFeedbackRecorder()
        let targetDate = Date(timeIntervalSince1970: 3_000)
        let savedDate = Date(timeIntervalSince1970: 4_000)

        let item = clothingItem(id: UUID(uuidString: "60000000-0000-0000-0000-000000000001")!, type: .top)
        item.wearCount = 3
        item.lastWornAt = targetDate
        context.insert(item)
        try context.save()

        let result = try recorder.record(
            .saved,
            candidate: OutfitCandidate(id: "dailyOffice:saved-undo", items: [item], score: 77, explanationSeed: "seed"),
            scenario: .dailyOffice,
            season: .summer,
            explanation: "Saved outfit",
            in: context,
            now: savedDate
        )

        try recorder.undoFeedback(
            feedbackID: result.feedback.id,
            outfitID: result.outfit?.id,
            in: context
        )

        let fetchedItems = try context.fetch(FetchDescriptor<ClothingItem>())
        XCTAssertEqual(fetchedItems.map(\.wearCount), [3])
        XCTAssertEqual(fetchedItems.first?.lastWornAt, targetDate)
        XCTAssertTrue(try context.fetch(FetchDescriptor<OutfitFeedback>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Outfit>()).isEmpty)
    }

    func testWoreActionGeneratesUndoActionWhenRecorded() throws {
        let context = try makeInMemoryModelContext()
        let recorder = TodayFeedbackRecorder()
        let item = clothingItem(id: UUID(uuidString: "70000000-0000-0000-0000-000000000001")!, type: .top)
        context.insert(item)
        try context.save()

        let result = try recorder.record(
            .wore,
            candidate: OutfitCandidate(id: "dailyOffice:wore-undo-action", items: [item], score: 70, explanationSeed: "seed"),
            scenario: .dailyOffice,
            season: .winter,
            explanation: "Record for undo action",
            in: context,
            now: Date(timeIntervalSince1970: 5_000)
        )

        let undoAction = TodayFeedbackAction.wore.undoAction(for: result)
        XCTAssertNotNil(undoAction)
        XCTAssertEqual(undoAction?.feedbackID, result.feedback.id)
        XCTAssertEqual(undoAction?.outfitID, result.outfit?.id)
    }

    private func makeInMemoryModelContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self,
            configurations: configuration
        )

        return ModelContext(container)
    }

    private func clothingItem(id: UUID, type: ClothingType) -> ClothingItem {
        ClothingItem(
            id: id,
            photoLocalPath: "wardrobe/\(id.uuidString).jpg",
            type: type,
            color: "navy",
            seasons: [.spring],
            formalityLevel: 4,
            storageLocation: "closet"
        )
    }
}
