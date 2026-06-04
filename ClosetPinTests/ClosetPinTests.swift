import XCTest
import SwiftData
import UIKit
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

    func testClothingItemDisplayTextUsesLocalizedKnownValues() {
        let item = ClothingItem(
            photoLocalPath: "wardrobe/shoes.jpg",
            type: .shoes,
            color: "Black",
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Sample work capsule"
        )

        XCTAssertEqual(item.displayColor, localizedColor("Black"))
        XCTAssertEqual(item.displayStorageLocation, L10n.text("seed.work_capsule.storage_location"))
        XCTAssertEqual(item.displayTitle, "\(localizedColor("Black")) \(ClothingType.shoes.displayName)")

        let draft = AddEditItemDraft(item: item)
        XCTAssertEqual(draft.color, item.displayColor)
        XCTAssertEqual(draft.storageLocation, item.displayStorageLocation)
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
        XCTAssertTrue(preference.cloudPhotoRecognitionEnabled)
        XCTAssertFalse(preference.tomorrowWeatherEnabled)
        XCTAssertEqual(preference.tomorrowWeatherLocationName, "")
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

    func testUserPreferenceAppliesSettingsWithoutLanguagePreference() {
        let preference = UserPreference()
        let updateDate = Date(timeIntervalSince1970: 300)

        preference.applySettings(
            defaultScenario: .importantMeeting,
            preferredFormality: 7,
            workplaceDressCode: "Business casual, client-facing",
            cloudPhotoRecognitionEnabled: true,
            tomorrowWeatherEnabled: true,
            tomorrowWeatherLocationName: "  Shanghai  ",
            updatedAt: updateDate
        )

        XCTAssertEqual(preference.defaultScenario, .importantMeeting)
        XCTAssertEqual(preference.preferredFormality, 5)
        XCTAssertEqual(preference.workplaceDressCode, "Business casual, client-facing")
        XCTAssertTrue(preference.cloudPhotoRecognitionEnabled)
        XCTAssertTrue(preference.tomorrowWeatherEnabled)
        XCTAssertEqual(preference.tomorrowWeatherLocationName, "Shanghai")
        XCTAssertEqual(preference.updatedAt, updateDate)
    }

    func testTomorrowWeatherSettingsRequireEnabledAndLocation() {
        let disabled = UserPreference(tomorrowWeatherEnabled: false, tomorrowWeatherLocationName: "Shanghai")
        let missingLocation = UserPreference(tomorrowWeatherEnabled: true, tomorrowWeatherLocationName: "   ")
        let ready = UserPreference(tomorrowWeatherEnabled: true, tomorrowWeatherLocationName: "Shanghai")

        XCTAssertFalse(disabled.canRequestTomorrowWeather)
        XCTAssertFalse(missingLocation.canRequestTomorrowWeather)
        XCTAssertTrue(ready.canRequestTomorrowWeather)
    }

    func testStatusMetadataIncludesIconAndReadableLabel() {
        for status in ClothingStatus.allCases {
            XCTAssertFalse(status.displayName.isEmpty)
            XCTAssertFalse(status.systemImage.isEmpty)
        }
    }

    func testLooksHistoryEntriesIncludeSavedOutfitAndWornFeedbackInReverseChronologicalOrder() {
        let top = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/top.jpg",
            type: .top,
            color: "White",
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Rack"
        )
        let shoes = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/shoes.jpg",
            type: .shoes,
            color: "Black",
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Shoe shelf"
        )
        let savedDate = Date(timeIntervalSince1970: 100)
        let wornDate = Date(timeIntervalSince1970: 200)
        let outfit = Outfit(
            itemIds: [top.id, shoes.id],
            scenario: .importantMeeting,
            dateContext: savedDate,
            weatherNote: "Spring",
            score: 92,
            explanation: "Polished for a client meeting.",
            savedAt: savedDate
        )
        let feedback = OutfitFeedback(
            feedbackType: .wore,
            itemIds: [top.id],
            scenario: .dailyOffice
        )
        feedback.createdAt = wornDate

        let entries = LooksHistoryEntry.makeEntries(
            outfits: [outfit],
            feedback: [feedback],
            items: [top, shoes]
        )

        XCTAssertEqual(entries.map(\.kind), [.worn, .saved])
        XCTAssertEqual(entries.first?.scenario, .dailyOffice)
        XCTAssertEqual(entries.first?.itemCount, 1)
        XCTAssertEqual(entries.first?.itemSummary, "\(localizedColor("White")) \(ClothingType.top.displayName)")
        XCTAssertEqual(entries.first?.visualItems.map(\.id), [top.id])
        XCTAssertEqual(entries.first?.visualItems.first?.type, .top)
        XCTAssertEqual(entries.last?.scenario, .importantMeeting)
        XCTAssertEqual(entries.last?.itemCount, 2)
        XCTAssertEqual(entries.last?.visualItems.map(\.id), [top.id, shoes.id])
        XCTAssertEqual(
            entries.last?.explanation,
            TodayRecommendationExplanation.text(
                for: [
                    TodayOutfitItemSnapshot(type: .top, color: "White"),
                    TodayOutfitItemSnapshot(type: .shoes, color: "Black")
                ],
                scenario: .importantMeeting
            )
        )
    }

    func testLooksHistoryEntriesKeepDeterministicItemSelectionWithDuplicateItemIDs() {
        let itemID = UUID()
        let earlierDuplicate = ClothingItem(
            id: itemID,
            photoLocalPath: "/tmp/duplicate-top.jpg",
            type: .top,
            color: "White",
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Rack"
        )
        let laterDuplicate = ClothingItem(
            id: itemID,
            photoLocalPath: "/tmp/duplicate-shoes.jpg",
            type: .shoes,
            color: "Black",
            seasons: [.summer],
            formalityLevel: 4,
            storageLocation: "Shoe rack"
        )
        let outfit = Outfit(
            itemIds: [itemID],
            scenario: .importantMeeting,
            dateContext: Date(timeIntervalSince1970: 100),
            weatherNote: "Evening",
            score: 80,
            explanation: "Classic meeting option.",
            savedAt: Date(timeIntervalSince1970: 100)
        )

        let entries = LooksHistoryEntry.makeEntries(
            outfits: [outfit],
            feedback: [],
            items: [earlierDuplicate, laterDuplicate]
        )

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.itemSummary, "\(localizedColor("Black")) \(ClothingType.shoes.displayName)")
        XCTAssertEqual(entries.first?.visualItems.map(\.photoLocalPath), ["/tmp/duplicate-shoes.jpg"])
        XCTAssertEqual(
            entries.first?.explanation,
            TodayRecommendationExplanation.text(
                for: [TodayOutfitItemSnapshot(type: .shoes, color: "Black")],
                scenario: .importantMeeting
            )
        )
    }

    func testOutfitVisualItemsPreserveOutfitOrderAndPhotoMetadata() {
        let top = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/top.jpg",
            type: .top,
            color: "White",
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Rack"
        )
        let shoes = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/shoes.jpg",
            type: .shoes,
            color: "Black",
            seasons: [.spring],
            formalityLevel: 3,
            storageLocation: "Shoe shelf"
        )

        let visualItems = OutfitVisualItem.makeItems(from: [shoes, top])

        XCTAssertEqual(visualItems.map(\.id), [shoes.id, top.id])
        XCTAssertEqual(visualItems.map(\.photoLocalPath), ["/tmp/shoes.jpg", "/tmp/top.jpg"])
        XCTAssertEqual(visualItems.map(\.displayName), [
            "\(localizedColor("Black")) \(ClothingType.shoes.displayName)",
            "\(localizedColor("White")) \(ClothingType.top.displayName)"
        ])
    }

    private func localizedColor(_ color: String) -> String {
        ColorResolver.localizedDisplayColor(from: color) ?? color
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

    func testWorkCapsuleSeederFirstInsertAddsExpectedCount() throws {
        let context = try makeInMemoryModelContext()

        let insertedCount = try WorkCapsuleSeeder.insertSampleCapsule(in: context)
        let fetchedItems = try context.fetch(FetchDescriptor<ClothingItem>())

        XCTAssertEqual(insertedCount, SeedData.workCapsuleItems().count)
        XCTAssertEqual(fetchedItems.count, SeedData.workCapsuleItems().count)
    }

    func testWorkCapsuleSeederSecondInsertAddsNoDuplicates() throws {
        let context = try makeInMemoryModelContext()

        let firstInsertedCount = try WorkCapsuleSeeder.insertSampleCapsule(in: context)
        let secondInsertedCount = try WorkCapsuleSeeder.insertSampleCapsule(in: context)
        let fetchedItems = try context.fetch(FetchDescriptor<ClothingItem>())
        let uniqueIDs = Set(fetchedItems.map(\.id))

        XCTAssertEqual(firstInsertedCount, SeedData.workCapsuleItems().count)
        XCTAssertEqual(secondInsertedCount, 0)
        XCTAssertEqual(fetchedItems.count, SeedData.workCapsuleItems().count)
        XCTAssertEqual(uniqueIDs.count, fetchedItems.count)
    }

    func testWorkCapsuleSeedDataProducesOfficeAndMeetingRecommendations() {
        let items = SeedData.workCapsuleItems()
        let engine = RecommendationEngine()

        let dailyOfficeCandidates = engine.recommend(
            input: RecommendationInput(scenario: .dailyOffice, season: .spring, maximumResults: 1),
            items: items,
            feedback: []
        )
        let importantMeetingCandidates = engine.recommend(
            input: RecommendationInput(scenario: .importantMeeting, season: .spring, maximumResults: 1),
            items: items,
            feedback: []
        )

        XCTAssertEqual(dailyOfficeCandidates.first?.items.count, 3)
        XCTAssertEqual(importantMeetingCandidates.first?.items.count, 4)
        XCTAssertTrue(importantMeetingCandidates.first?.items.contains { $0.type == .blazer } ?? false)
    }

    func testSeasonResolverUsesCalendarMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertEqual(SeasonResolver.currentSeason(date: date(month: 1, calendar: calendar), calendar: calendar), .winter)
        XCTAssertEqual(SeasonResolver.currentSeason(date: date(month: 4, calendar: calendar), calendar: calendar), .spring)
        XCTAssertEqual(SeasonResolver.currentSeason(date: date(month: 7, calendar: calendar), calendar: calendar), .summer)
        XCTAssertEqual(SeasonResolver.currentSeason(date: date(month: 10, calendar: calendar), calendar: calendar), .autumn)
    }

    func testGeneratedMVPAssetsAreBundled() {
        let onboardingURL = Bundle.main.url(forResource: "work-capsule-onboarding", withExtension: "png")
        let emptyClosetURL = Bundle.main.url(forResource: "empty-closet", withExtension: "png")

        XCTAssertNotNil(onboardingURL.flatMap { UIImage(contentsOfFile: $0.path) })
        XCTAssertNotNil(emptyClosetURL.flatMap { UIImage(contentsOfFile: $0.path) })
    }

    func testEditorialSeedCapsuleAssetsAreBundled() {
        let assetNames = [
            "editorial-white-shirt",
            "editorial-light-blue-blouse",
            "editorial-charcoal-knit",
            "editorial-navy-bottom",
            "editorial-black-bottom",
            "editorial-charcoal-blazer",
            "editorial-black-shoes",
            "editorial-brown-loafers",
            "editorial-work-bag"
        ]

        for name in assetNames {
            let url = Bundle.main.url(forResource: name, withExtension: "png")
            XCTAssertNotNil(url.flatMap { UIImage(contentsOfFile: $0.path) }, "Expected bundled image named \(name)")
        }
    }

    func testSampleCapsuleUsesEditorialGeneratedPhotoPaths() {
        let expectedPaths = [
            "generated/editorial-white-shirt.png",
            "generated/editorial-light-blue-blouse.png",
            "generated/editorial-charcoal-knit.png",
            "generated/editorial-navy-bottom.png",
            "generated/editorial-black-bottom.png",
            "generated/editorial-charcoal-blazer.png",
            "generated/editorial-black-shoes.png",
            "generated/editorial-brown-loafers.png",
            "generated/editorial-work-bag.png"
        ]

        XCTAssertEqual(SeedData.workCapsuleItems().map(\.photoLocalPath), expectedPaths)
    }

    func testEditorialDesignTokensPreferSoftImageLedSurfaces() {
        XCTAssertGreaterThan(DesignSystem.Radius.editorialHero, DesignSystem.Radius.lg)
        XCTAssertGreaterThan(DesignSystem.Spacing.editorial, DesignSystem.Spacing.xl)
        XCTAssertEqual(DesignSystem.editorialOverlayOpacity, 0.54, accuracy: 0.001)
    }

    func testAddEditItemDraftRequiresOnlyColorPhotoAndSeasonBeforeSaving() {
        var draft = AddEditItemDraft()

        XCTAssertFalse(draft.canSave)
        XCTAssertFalse(draft.selectedSeasons.isEmpty)

        draft.color = "Ivory"
        XCTAssertFalse(draft.canSave)

        draft.photoLocalPath = "/tmp/photo.jpg"

        XCTAssertTrue(draft.canSave)
    }

    func testAddEditItemDraftCanStartWithSuggestedMissingType() {
        let defaultDraft = AddEditItemDraft()
        let suggestedDraft = AddEditItemDraft(initialType: .bottom)

        XCTAssertEqual(defaultDraft.type, .top)
        XCTAssertEqual(suggestedDraft.type, .bottom)
        XCTAssertFalse(suggestedDraft.selectedSeasons.isEmpty)
    }

    func testAddEditItemDraftCanSelectCurrentSeasonFromSystemDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let mayDate = date(month: 5, calendar: calendar)
        var draft = AddEditItemDraft()

        draft.selectCurrentSeason(date: mayDate, calendar: calendar)

        XCTAssertEqual(draft.selectedSeasons, [.spring])
    }

    func testAddEditItemDraftCanMarkItemAsYearRound() {
        var draft = AddEditItemDraft()

        draft.selectYearRound()

        XCTAssertEqual(draft.selectedSeasons, Set(SeasonTag.allCases))
    }

    func testAddEditItemDraftAllowsStagedJPEGPhotoBeforeFinalPathExists() {
        var draft = AddEditItemDraft()
        draft.color = "Ivory"
        draft.pendingPhotoJPEGData = Data([0xFF, 0xD8, 0xFF, 0xD9])

        XCTAssertTrue(draft.canSave)
        XCTAssertTrue(draft.photoLocalPath.isEmpty)
    }

    func testAddEditItemDraftRejectsWhitespaceOnlyRequiredText() {
        var draft = AddEditItemDraft()
        draft.photoLocalPath = "/tmp/photo.jpg"
        draft.color = "   "
        draft.storageLocation = "\n\t"

        XCTAssertFalse(draft.canSave)
        XCTAssertTrue(draft.validationMessages.contains(L10n.text("closet.validation.color_required")))
        XCTAssertFalse(draft.validationMessages.contains(L10n.text("closet.validation.storage_required")))
    }

    func testAddEditItemDraftUsesStableItemIDForCreatedItem() {
        var draft = AddEditItemDraft()
        draft.photoLocalPath = "/tmp/photo.jpg"
        draft.color = "Ivory"
        draft.selectedSeasons = [.spring]
        draft.storageLocation = "Main wardrobe"

        let item = draft.makeItem()

        XCTAssertEqual(item.id, draft.itemID)
        XCTAssertEqual(item.photoLocalPath, "/tmp/photo.jpg")
    }

    func testPhotoPersistenceNormalizesUIImageToJPEGData() throws {
        let image = makeTestImage()

        let data = try XCTUnwrap(ClosetItemPhotoPersistence.jpegData(from: image))

        XCTAssertEqual(data.prefix(2), Data([0xFF, 0xD8]))
        XCTAssertNotNil(UIImage(data: data))
    }

    func testPhotoPersistenceNormalizesLibraryDataToJPEGData() throws {
        let pngData = try XCTUnwrap(makeTestImage().pngData())

        let data = try XCTUnwrap(ClosetItemPhotoPersistence.normalizedJPEGData(from: pngData))

        XCTAssertEqual(data.prefix(2), Data([0xFF, 0xD8]))
        XCTAssertNotNil(UIImage(data: data))
    }

    func testPhotoPersistenceAutoCropsClothingSubjectBeforeSavingDisplayJPEG() throws {
        let sourceImage = makeImageWithCenteredSubject()
        let sourceData = try XCTUnwrap(sourceImage.pngData())

        let result = try XCTUnwrap(ClosetItemPhotoPersistence.processedPhotoData(from: sourceData))
        let displayImage = try XCTUnwrap(UIImage(data: result.displayJPEGData))
        let originalImage = try XCTUnwrap(UIImage(data: result.originalJPEGData))

        XCTAssertLessThan(displayImage.size.width, originalImage.size.width)
        XCTAssertLessThan(displayImage.size.height, originalImage.size.height)
        XCTAssertEqual(originalImage.cgImage?.width, sourceImage.cgImage?.width)
        XCTAssertEqual(originalImage.cgImage?.height, sourceImage.cgImage?.height)
    }

    func testPhotoPersistenceCropsCenteredGarmentWithoutEdgeClutter() throws {
        let sourceImage = makeImageWithCenteredSubjectAndEdgeClutter()
        let sourceData = try XCTUnwrap(sourceImage.pngData())

        let result = try XCTUnwrap(ClosetItemPhotoPersistence.processedPhotoData(from: sourceData))
        let displayImage = try XCTUnwrap(UIImage(data: result.displayJPEGData))

        XCTAssertLessThan(displayImage.size.width, 78)
        XCTAssertLessThan(displayImage.size.height, 82)
    }

    func testPhotoPersistenceRejectsNonImageLibraryData() {
        let data = ClosetItemPhotoPersistence.processedPhotoData(from: Data("not an image".utf8))

        XCTAssertNil(data)
    }

    func testPhotoPersistenceStagesDisplayAndOriginalJPEGFiles() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClosetPinTests-\(UUID().uuidString)", isDirectory: true)
        let imageStore = ImageStore(baseDirectory: directory)
        let itemID = UUID()
        let photoData = ProcessedClosetPhotoData(
            displayJPEGData: Data("display image".utf8),
            originalJPEGData: Data("original image".utf8)
        )

        let stagedWrite = try ClosetItemPhotoPersistence.stagePhotoData(
            photoData,
            id: itemID,
            imageStore: imageStore
        )

        try stagedWrite.commit()

        XCTAssertEqual(try Data(contentsOf: stagedWrite.display.finalURL), photoData.displayJPEGData)
        XCTAssertEqual(try Data(contentsOf: stagedWrite.original.finalURL), photoData.originalJPEGData)
        XCTAssertTrue(stagedWrite.display.finalURL.lastPathComponent.hasSuffix(".jpg"))
        XCTAssertTrue(stagedWrite.original.finalURL.path.contains("/Originals/"))

        try? FileManager.default.removeItem(at: directory)
    }

    func testStagedPhotoWriteDoesNotReplaceExistingImageUntilCommit() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClosetPinTests-\(UUID().uuidString)", isDirectory: true)
        let imageStore = ImageStore(baseDirectory: directory)
        let itemID = UUID()
        let existingData = Data("old image".utf8)
        let replacementData = Data("new image".utf8)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let finalURL = directory.appendingPathComponent("\(itemID.uuidString).jpg")
        try existingData.write(to: finalURL)

        let stagedWrite = try ClosetItemPhotoPersistence.stageJPEGData(
            replacementData,
            id: itemID,
            imageStore: imageStore
        )

        XCTAssertEqual(try Data(contentsOf: finalURL), existingData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: stagedWrite.stagingURL.path))

        try stagedWrite.commit()

        XCTAssertEqual(try Data(contentsOf: finalURL), replacementData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stagedWrite.stagingURL.path))

        try? FileManager.default.removeItem(at: directory)
    }

    func testAddEditItemDraftPreservesExistingPhotoPathWhenEditing() {
        let existing = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/original.jpg",
            originalPhotoLocalPath: "/tmp/source.jpg",
            type: .top,
            color: "Blue",
            seasons: [.spring],
            formalityLevel: 3,
            warmthLevel: 2,
            storageLocation: "Rack"
        )

        var draft = AddEditItemDraft(item: existing)
        draft.color = "Ivory"
        draft.storageLocation = "Main wardrobe"
        draft.apply(to: existing)

        XCTAssertEqual(existing.id, draft.itemID)
        XCTAssertEqual(existing.photoLocalPath, "/tmp/original.jpg")
        XCTAssertEqual(existing.originalPhotoLocalPath, "/tmp/source.jpg")
        XCTAssertEqual(existing.color, "Ivory")
        XCTAssertEqual(existing.storageLocation, "Main wardrobe")
    }

    func testAddEditItemDraftUpdatesPhotoPathWhenEditing() {
        let existing = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/original.jpg",
            originalPhotoLocalPath: "/tmp/source.jpg",
            type: .top,
            color: "Blue",
            seasons: [.spring],
            formalityLevel: 3,
            warmthLevel: 2,
            storageLocation: "Rack"
        )

        var draft = AddEditItemDraft(item: existing)
        draft.photoLocalPath = "/tmp/replacement.jpg"
        draft.originalPhotoLocalPath = "/tmp/replacement-source.jpg"
        draft.apply(to: existing)

        XCTAssertEqual(existing.photoLocalPath, "/tmp/replacement.jpg")
        XCTAssertEqual(existing.originalPhotoLocalPath, "/tmp/replacement-source.jpg")
    }

    func testAddEditItemDraftApplyUpdatesFieldsAndUpdatedAt() {
        let existing = ClothingItem(
            id: UUID(),
            photoLocalPath: "/tmp/original.jpg",
            type: .top,
            color: "Blue",
            seasons: [.spring],
            formalityLevel: 3,
            warmthLevel: 2,
            storageLocation: "Rack",
            status: .available,
            notes: "Old"
        )
        let originalUpdatedAt = existing.updatedAt

        var draft = AddEditItemDraft(item: existing)
        draft.type = .blazer
        draft.color = "Charcoal"
        draft.selectedSeasons = [.autumn, .winter]
        draft.formalityLevel = 5
        draft.warmthLevel = 4
        draft.storageLocation = "Main wardrobe"
        draft.status = .needsRepair
        draft.notes = "Replace button"
        draft.apply(to: existing)

        XCTAssertEqual(existing.type, .blazer)
        XCTAssertEqual(existing.color, "Charcoal")
        XCTAssertEqual(existing.seasons, [.autumn, .winter])
        XCTAssertEqual(existing.formalityLevel, 5)
        XCTAssertEqual(existing.warmthLevel, 4)
        XCTAssertEqual(existing.storageLocation, "Main wardrobe")
        XCTAssertEqual(existing.status, .needsRepair)
        XCTAssertEqual(existing.notes, "Replace button")
        XCTAssertGreaterThanOrEqual(existing.updatedAt, originalUpdatedAt)
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

    private func makeTestImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        }
    }

    private func makeImageWithCenteredSubject() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 35, y: 30, width: 30, height: 40))
        }
    }

    private func makeImageWithCenteredSubjectAndEdgeClutter() -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120), format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
            UIColor.systemGreen.setFill()
            context.fill(CGRect(x: 40, y: 28, width: 42, height: 62))
            UIColor.black.setFill()
            context.fill(CGRect(x: 4, y: 75, width: 12, height: 36))
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 104, y: 8, width: 10, height: 28))
        }
    }

    private func date(month: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: 15))!
    }
}
