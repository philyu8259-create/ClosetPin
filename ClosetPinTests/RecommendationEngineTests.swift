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

    func testMaximumResultsIsRespected() {
        let items = [
            clothingItem(type: .top, color: "white", formalityLevel: 4),
            clothingItem(type: .top, color: "blue", formalityLevel: 3),
            clothingItem(type: .bottom, color: "navy", formalityLevel: 4),
            clothingItem(type: .bottom, color: "black", formalityLevel: 3),
            clothingItem(type: .shoes, color: "black", formalityLevel: 4),
            clothingItem(type: .shoes, color: "brown", formalityLevel: 3)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 2),
            items: items,
            feedback: []
        )

        XCTAssertEqual(candidates.count, 2)
    }

    func testPreferredFormalityChangesDailyOfficeRanking() throws {
        let relaxedTop = clothingItem(type: .top, color: "soft blue", formalityLevel: 2)
        let relaxedBottom = clothingItem(type: .bottom, color: "khaki", formalityLevel: 2)
        let relaxedShoes = clothingItem(type: .shoes, color: "brown", formalityLevel: 2)
        let polishedTop = clothingItem(type: .top, color: "white", formalityLevel: 5)
        let polishedBottom = clothingItem(type: .bottom, color: "navy", formalityLevel: 5)
        let polishedShoes = clothingItem(type: .shoes, color: "black", formalityLevel: 5)
        let items = [
            relaxedTop,
            relaxedBottom,
            relaxedShoes,
            polishedTop,
            polishedBottom,
            polishedShoes
        ]

        let relaxedCandidate = try XCTUnwrap(RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .dailyOffice,
                season: .spring,
                maximumResults: 1,
                preferredFormality: 2
            ),
            items: items,
            feedback: []
        ).first)
        let polishedCandidate = try XCTUnwrap(RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .dailyOffice,
                season: .spring,
                maximumResults: 1,
                preferredFormality: 5
            ),
            items: items,
            feedback: []
        ).first)

        XCTAssertTrue(relaxedCandidate.items.allSatisfy { $0.formalityLevel == 2 })
        XCTAssertTrue(polishedCandidate.items.allSatisfy { $0.formalityLevel == 5 })
    }

    func testDeterministicOrderingAndIdentifiersAreStableAcrossRepeatedCalls() {
        let items = [
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, type: .top, color: "white", formalityLevel: 4),
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, type: .top, color: "blue", formalityLevel: 4),
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!, type: .bottom, color: "navy", formalityLevel: 4),
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!, type: .shoes, color: "black", formalityLevel: 4)
        ]
        let input = RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 5)

        let firstRun = RecommendationEngine().recommend(input: input, items: items, feedback: [])
        let secondRun = RecommendationEngine().recommend(input: input, items: items, feedback: [])

        XCTAssertEqual(firstRun.map(\.id), secondRun.map(\.id))
        XCTAssertEqual(firstRun.map(\.explanationSeed), secondRun.map(\.explanationSeed))
    }

    func testWrongSeasonItemsAreExcluded() {
        let wrongSeasonTop = clothingItem(type: .top, color: "white", seasons: [.winter], formalityLevel: 5)
        let springTop = clothingItem(type: .top, color: "blue", seasons: [.spring], formalityLevel: 2)
        let items = [
            wrongSeasonTop,
            springTop,
            clothingItem(type: .bottom, seasons: [.spring]),
            clothingItem(type: .shoes, seasons: [.spring])
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertFalse(candidates[0].items.contains { $0.id == wrongSeasonTop.id })
        XCTAssertTrue(candidates[0].items.contains { $0.id == springTop.id })
    }

    func testUnsupportedKnownTypesDoNotSatisfyRequiredCategories() {
        let items = [
            clothingItem(type: .bag, formalityLevel: 5),
            clothingItem(type: .accessory, formalityLevel: 5),
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
}

private extension RecommendationEngineTests {
    func clothingItem(
        id: UUID = UUID(),
        type: ClothingType,
        color: String = "navy",
        seasons: [SeasonTag] = [.spring],
        formalityLevel: Int = 3,
        status: ClothingStatus = .available
    ) -> ClothingItem {
        ClothingItem(
            id: id,
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
