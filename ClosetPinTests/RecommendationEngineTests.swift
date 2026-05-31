import XCTest
@testable import ClosetPin

final class RecommendationEngineTests: XCTestCase {
    func testTomorrowWeatherPreviewParsesRainyCommutePreset() throws {
        let context = try XCTUnwrap(TomorrowWeatherPreview.context(from: "rainy_commute"))

        XCTAssertEqual(context.condition, .rain)
        XCTAssertEqual(context.minTemperatureCelsius, 11)
        XCTAssertEqual(context.maxTemperatureCelsius, 18)
        XCTAssertEqual(context.precipitationProbability, 70)
        XCTAssertTrue(context.isRainLikely)
    }

    func testTomorrowWeatherPreviewParsesJSONPayload() throws {
        let payload = """
        {"condition":"light_rain","minTemperatureCelsius":9,"maxTemperatureCelsius":14,"precipitationProbability":55,"windSpeedKph":31}
        """

        let context = try XCTUnwrap(TomorrowWeatherPreview.context(from: payload))

        XCTAssertEqual(context.condition, .lightRain)
        XCTAssertEqual(context.minTemperatureCelsius, 9)
        XCTAssertEqual(context.maxTemperatureCelsius, 14)
        XCTAssertTrue(context.isRainLikely)
        XCTAssertTrue(context.isWindy)
    }

    func testTomorrowWeatherConditionMapperHandlesWeatherKitStyleValues() {
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "heavyRain"), .rain)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "drizzle"), .lightRain)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "partlyCloudy"), .partlyCloudy)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "isolatedThunderstorms"), .thunderstorms)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "wintryMix"), .snow)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "breezy"), .wind)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "mostlyClear"), .clear)
        XCTAssertEqual(TomorrowWeatherConditionMapper.condition(from: "unexpected"), .unknown)
    }

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

    func testWeekendCasualAllowsRelaxedItems() {
        let items = [
            clothingItem(type: .top, color: "cream", formalityLevel: 1),
            clothingItem(type: .bottom, color: "denim", formalityLevel: 1),
            clothingItem(type: .shoes, color: "white", formalityLevel: 1)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .weekendCasual, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.items.count, 3)
    }

    func testBanquetPrefersPolishedLooksWithoutRequiringBlazer() {
        let items = [
            clothingItem(type: .top, color: "silk black", formalityLevel: 4),
            clothingItem(type: .bottom, color: "black", formalityLevel: 4),
            clothingItem(type: .shoes, color: "black", formalityLevel: 4)
        ]

        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(scenario: .banquet, season: .spring, maximumResults: 5),
            items: items,
            feedback: []
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates.first?.items.count, 3)
    }

    func testColdTomorrowPrioritizesWarmerLayeringForDailyOffice() throws {
        let warmTop = clothingItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            type: .top,
            color: "navy",
            seasons: [.winter],
            formalityLevel: 4,
            warmthLevel: 5
        )
        let coolTop = clothingItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            type: .top,
            color: "grey",
            seasons: [.winter],
            formalityLevel: 4,
            warmthLevel: 1
        )
        let itemSet = [
            warmTop,
            coolTop,
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!, type: .bottom, color: "black", seasons: [.winter], formalityLevel: 4, warmthLevel: 4),
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!, type: .shoes, color: "brown", seasons: [.winter], formalityLevel: 4, warmthLevel: 1),
            clothingItem(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!,
                type: .outerwear,
                color: "olive",
                seasons: [.winter],
                formalityLevel: 4,
                warmthLevel: 5
            )
        ]

        let tomorrow = TomorrowRecommendationInput(
            weatherContext: TomorrowWeatherContext(
                condition: .snow,
                minTemperatureCelsius: 1,
                maxTemperatureCelsius: 8,
                precipitationProbability: 65,
                windSpeedKph: 8
            )
        )
        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .dailyOffice,
                season: .winter,
                tomorrow: tomorrow,
                maximumResults: 1
            ),
            items: itemSet,
            feedback: []
        )

        let candidate = try XCTUnwrap(candidates.first)
        let candidateTop = candidate.items.first { $0.resolvedType == .top }
        let hasOuterwear = candidate.items.contains { $0.resolvedType == .outerwear }
        XCTAssertTrue(hasOuterwear)
        XCTAssertEqual(candidateTop?.warmthLevel, 5)
    }

    func testRainTomorrowPrefersRainSafeShoes() throws {
        let safeShoes = clothingItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000201")!,
            type: .shoes,
            color: "black",
            seasons: [.autumn],
            styleTags: ["waterproof"],
            formalityLevel: 4,
            warmthLevel: 1
        )
        let unsafeShoes = clothingItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000202")!,
            type: .shoes,
            color: "white",
            seasons: [.autumn],
            styleTags: ["canvas"],
            formalityLevel: 4,
            warmthLevel: 1
        )
        let items = [
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000203")!, type: .top, color: "white", seasons: [.autumn], formalityLevel: 4),
            clothingItem(id: UUID(uuidString: "00000000-0000-0000-0000-000000000204")!, type: .bottom, color: "black", seasons: [.autumn], formalityLevel: 4),
            unsafeShoes,
            safeShoes
        ]
        let tomorrow = TomorrowRecommendationInput(
            weatherContext: TomorrowWeatherContext(
                condition: .rain,
                minTemperatureCelsius: 10,
                maxTemperatureCelsius: 13,
                precipitationProbability: 90,
                windSpeedKph: 12
            )
        )
        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .dailyOffice,
                season: .autumn,
                tomorrow: tomorrow,
                maximumResults: 1
            ),
            items: items,
            feedback: []
        )

        let candidate: OutfitCandidate = try XCTUnwrap(candidates.first)
        let shoe: ClothingItem = try XCTUnwrap(candidate.items.first { $0.resolvedType == .shoes })
        XCTAssertEqual(shoe.id, safeShoes.id)
    }

    func testHotTomorrowDoesNotForceBlazerInImportantMeeting() {
        let candidates = RecommendationEngine().recommend(
            input: RecommendationInput(
                scenario: .importantMeeting,
                season: .summer,
                tomorrow: TomorrowRecommendationInput(
                    weatherContext: TomorrowWeatherContext(
                        condition: .clear,
                        minTemperatureCelsius: 28,
                        maxTemperatureCelsius: 34,
                        precipitationProbability: 5,
                        windSpeedKph: 6
                    )
                ),
                maximumResults: 2
            ),
            items: [
                clothingItem(type: .top, color: "white", seasons: [.summer], formalityLevel: 4, warmthLevel: 1),
                clothingItem(type: .bottom, color: "navy", seasons: [.summer], formalityLevel: 4, warmthLevel: 2),
                clothingItem(type: .shoes, color: "black", seasons: [.summer], formalityLevel: 4, warmthLevel: 1),
                clothingItem(type: .blazer, color: "charcoal", seasons: [.summer], formalityLevel: 4, warmthLevel: 3)
            ],
            feedback: []
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].items.count, 3)
        XCTAssertFalse(candidates[0].items.contains { $0.resolvedType == .blazer })
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
        styleTags: [String] = [],
        formalityLevel: Int = 3,
        warmthLevel: Int = 2,
        status: ClothingStatus = .available
    ) -> ClothingItem {
        ClothingItem(
            id: id,
            photoLocalPath: "wardrobe/\(type.rawValue)-\(UUID().uuidString).jpg",
            type: type,
            color: color,
            seasons: seasons,
            styleTags: styleTags,
            formalityLevel: formalityLevel,
            warmthLevel: warmthLevel,
            storageLocation: "closet",
            status: status
        )
    }
}
