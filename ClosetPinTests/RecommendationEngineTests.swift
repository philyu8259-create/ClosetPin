import XCTest
@testable import ClosetPin

final class RecommendationEngineTests: XCTestCase {
    func testExcludesUnavailableItems() {
        let items = [
            clothingItem(type: .top, status: .needsWash),
            clothingItem(type: .bottom),
            clothingItem(type: .shoes)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testImportantMeetingRequiresHigherFormality() {
        let items = [
            clothingItem(type: .top, formalityLevel: 2),
            clothingItem(type: .bottom, formalityLevel: 4),
            clothingItem(type: .shoes, formalityLevel: 4),
            clothingItem(type: .blazer, formalityLevel: 4)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .importantMeeting, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testDailyOfficeReturnsCompleteOutfit() {
        let items = [
            clothingItem(type: .top, color: "white", formalityLevel: 2),
            clothingItem(type: .bottom, color: "navy", formalityLevel: 3),
            clothingItem(type: .shoes, color: "black", formalityLevel: 2)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.items.count, 3)
        XCTAssertGreaterThan(candidates.first?.score ?? 0, 0)
    }

    func testInvalidRawStatusOrTypeShouldNotBecomeRecommendable() {
        let invalidTop = clothingItem(type: .top)
        invalidTop.typeRawValue = "unexpected"

        let invalidStatusTop = clothingItem(type: .top)
        invalidStatusTop.statusRawValue = "unexpected"

        let validSupportItems = [
            clothingItem(type: .bottom),
            clothingItem(type: .shoes)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 5),
            items: [invalidTop, invalidStatusTop] + validSupportItems,
            feedback: []
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testImportantMeetingIncludesBlazerWhenAvailableAndRequired() {
        let blazer = clothingItem(type: .blazer, color: "charcoal", formalityLevel: 5)
        let items = [
            clothingItem(type: .top, color: "white", formalityLevel: 4),
            clothingItem(type: .bottom, color: "navy", formalityLevel: 4),
            clothingItem(type: .shoes, color: "black", formalityLevel: 4),
            blazer
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .importantMeeting, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertTrue(candidates[0].items.contains { $0.id == blazer.id })
        XCTAssertEqual(candidates[0].items.count, 4)
    }
}

private extension RecommendationEngineTests {
    func clothingItem(
        type: ClothingType,
        color: String = "navy",
        seasons: [SeasonTag] = [.spring],
        formalityLevel: Int = 3,
        status: ClothingStatus = .available
    ) -> ClothingItem {
        ClothingItem(
            photoLocalPath: "wardrobe/\(type.rawValue)-\(UUID().uuidString).jpg",
            type: type,
            color: color,
            seasons: seasons,
            formalityLevel: formalityLevel,
            storageLocation: "closet",
            status: status
        )
    }
}
