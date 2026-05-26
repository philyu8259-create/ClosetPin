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

        XCTAssertNil(result.outfit)
        XCTAssertEqual(result.feedback.feedbackType, .wore)
        XCTAssertEqual(result.feedback.scenario, .dailyOffice)
        XCTAssertEqual(result.feedback.itemIds, items.map(\.id))
        XCTAssertNil(result.feedback.outfitId)
        XCTAssertEqual(items.map(\.wearCount), [1, 1, 1])
        XCTAssertEqual(items.map(\.lastWornAt), [wornAt, wornAt, wornAt])

        let fetchedFeedback = try context.fetch(FetchDescriptor<OutfitFeedback>())
        XCTAssertEqual(fetchedFeedback.count, 1)
        XCTAssertEqual(fetchedFeedback.first?.feedbackType, .wore)
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

        let outfit = try XCTUnwrap(result.outfit)
        XCTAssertEqual(outfit.itemIds, items.map(\.id))
        XCTAssertEqual(outfit.scenario, .dailyOffice)
        XCTAssertEqual(outfit.weatherNote, "Spring")
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
