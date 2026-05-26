import XCTest
@testable import ClosetPin

final class ClosetPinTests: XCTestCase {
    func testScaffoldSeedPasses() {
        XCTAssertTrue(true)
    }

    func testClothingItemStoresRawValuesAndExposesTypedAccessors() {
        let item = ClothingItem(
            photoLocalPath: "wardrobe/shirt.jpg",
            type: .blazer,
            color: "navy",
            seasons: [.spring, .autumn],
            styleTags: ["tailored"],
            formalityLevel: 4,
            warmthLevel: 3,
            storageLocation: "hall closet",
            status: .needsRepair,
            brand: "Acme",
            size: "M",
            material: "wool",
            notes: "Replace button"
        )

        XCTAssertEqual(item.typeRawValue, ClothingType.blazer.rawValue)
        XCTAssertEqual(item.type, .blazer)
        XCTAssertEqual(item.seasonRawValues, [SeasonTag.spring.rawValue, SeasonTag.autumn.rawValue])
        XCTAssertEqual(item.seasons, [.spring, .autumn])
        XCTAssertEqual(item.statusRawValue, ClothingStatus.needsRepair.rawValue)
        XCTAssertEqual(item.status, .needsRepair)
        XCTAssertEqual(item.wearCount, 0)
        XCTAssertNil(item.lastWornAt)
    }

    func testModelTypedAccessorsFallBackForUnknownRawValues() {
        let item = ClothingItem(
            photoLocalPath: "wardrobe/unknown.jpg",
            type: .top,
            color: "white",
            seasons: [.summer],
            formalityLevel: 2,
            storageLocation: "drawer"
        )
        item.typeRawValue = "unexpected"
        item.statusRawValue = "unexpected"
        item.seasonRawValues = ["summer", "unexpected"]

        let outfit = Outfit(
            itemIds: [item.id],
            scenario: .importantMeeting,
            dateContext: Date(timeIntervalSince1970: 0),
            weatherNote: "mild",
            score: 88,
            explanation: "balanced"
        )
        outfit.scenarioRawValue = "unexpected"

        let feedback = OutfitFeedback(
            outfitId: outfit.id,
            feedbackType: .liked,
            itemIds: outfit.itemIds,
            scenario: .importantMeeting
        )
        feedback.feedbackTypeRawValue = "unexpected"
        feedback.scenarioRawValue = "unexpected"

        let preference = UserPreference(defaultScenario: .importantMeeting)
        preference.defaultScenarioRawValue = "unexpected"

        XCTAssertEqual(item.type, .top)
        XCTAssertEqual(item.status, .available)
        XCTAssertEqual(item.seasons, [.summer])
        XCTAssertEqual(outfit.scenario, .dailyOffice)
        XCTAssertEqual(feedback.feedbackType, .skipped)
        XCTAssertEqual(feedback.scenario, .dailyOffice)
        XCTAssertEqual(preference.defaultScenario, .dailyOffice)
    }

    func testUserPreferenceDefaultsAreLocalOfficeFriendly() {
        let preference = UserPreference()

        XCTAssertEqual(preference.defaultScenario, .dailyOffice)
        XCTAssertEqual(preference.preferredFormality, 3)
        XCTAssertEqual(preference.preferredColors, [])
        XCTAssertEqual(preference.avoidedColors, [])
        XCTAssertEqual(preference.preferredStyles, [])
        XCTAssertEqual(preference.avoidedStyles, [])
        XCTAssertEqual(preference.workplaceDressCode, "")
    }
}
