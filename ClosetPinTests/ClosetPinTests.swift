import XCTest
import SwiftData
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
        XCTAssertEqual(item.resolvedType, .blazer)
        XCTAssertEqual(item.seasonRawValues, [SeasonTag.spring.rawValue, SeasonTag.autumn.rawValue])
        XCTAssertEqual(item.seasons, [.spring, .autumn])
        XCTAssertEqual(item.statusRawValue, ClothingStatus.needsRepair.rawValue)
        XCTAssertEqual(item.status, .needsRepair)
        XCTAssertEqual(item.resolvedStatus, .needsRepair)
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

        XCTAssertEqual(item.type, .accessory)
        XCTAssertNil(item.resolvedType)
        XCTAssertEqual(item.status, .inactive)
        XCTAssertNil(item.resolvedStatus)
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
        XCTAssertLessThanOrEqual(abs(preference.createdAt.timeIntervalSinceNow), 1)
        XCTAssertLessThanOrEqual(abs(preference.updatedAt.timeIntervalSinceNow), 1)
    }

    func testUserPreferenceCanUseExplicitTimestamps() {
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)

        let preference = UserPreference(createdAt: createdAt, updatedAt: updatedAt)

        XCTAssertEqual(preference.createdAt, createdAt)
        XCTAssertEqual(preference.updatedAt, updatedAt)
    }

    func testWorkCapsuleSeedDataProvidesOfficeRecommendationBasics() {
        let items = SeedData.workCapsuleItems()
        let itemTypes = Set(items.map(\.type))

        XCTAssertTrue(itemTypes.isSuperset(of: [.top, .bottom, .shoes]))
        XCTAssertTrue(itemTypes.contains(.blazer))
        XCTAssertTrue(itemTypes.contains(.bag))
        XCTAssertGreaterThanOrEqual(items.count, 5)
        XCTAssertTrue(items.allSatisfy { $0.status == .available })
        XCTAssertTrue(items.allSatisfy { $0.formalityLevel >= 3 })
    }

    func testSwiftDataInMemoryPersistenceStoresCollectionFields() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ClothingItem.self,
            Outfit.self,
            OutfitFeedback.self,
            UserPreference.self,
            configurations: configuration
        )
        let context = ModelContext(container)
        let itemId = UUID()
        let outfitId = UUID()

        let item = ClothingItem(
            id: itemId,
            photoLocalPath: "wardrobe/coat.jpg",
            type: .outerwear,
            color: "charcoal",
            seasons: [.autumn, .winter],
            styleTags: ["structured", "warm"],
            formalityLevel: 4,
            warmthLevel: 5,
            storageLocation: "coat closet"
        )
        let outfit = Outfit(
            id: outfitId,
            itemIds: [itemId],
            scenario: .dailyOffice,
            dateContext: Date(timeIntervalSince1970: 0),
            weatherNote: "cold",
            score: 91,
            explanation: "warm and polished"
        )
        let feedback = OutfitFeedback(
            outfitId: outfitId,
            feedbackType: .wore,
            itemIds: [itemId],
            scenario: .dailyOffice
        )
        let preference = UserPreference(
            preferredColors: ["charcoal"],
            avoidedColors: ["neon"],
            preferredStyles: ["structured"],
            avoidedStyles: ["distressed"]
        )

        context.insert(item)
        context.insert(outfit)
        context.insert(feedback)
        context.insert(preference)
        try context.save()

        let fetchedItems = try context.fetch(FetchDescriptor<ClothingItem>())
        let fetchedOutfits = try context.fetch(FetchDescriptor<Outfit>())
        let fetchedFeedback = try context.fetch(FetchDescriptor<OutfitFeedback>())
        let fetchedPreferences = try context.fetch(FetchDescriptor<UserPreference>())

        XCTAssertEqual(fetchedItems.first?.seasonRawValues, [SeasonTag.autumn.rawValue, SeasonTag.winter.rawValue])
        XCTAssertEqual(fetchedItems.first?.styleTags, ["structured", "warm"])
        XCTAssertEqual(fetchedOutfits.first?.itemIds, [itemId])
        XCTAssertEqual(fetchedFeedback.first?.itemIds, [itemId])
        XCTAssertEqual(fetchedPreferences.first?.preferredColors, ["charcoal"])
        XCTAssertEqual(fetchedPreferences.first?.avoidedStyles, ["distressed"])
    }
}
