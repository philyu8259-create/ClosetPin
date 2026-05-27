import XCTest

@MainActor
final class ClosetPinUITests: XCTestCase {
    func testLaunchSmoke() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
    }

    func testUseSampleCapsuleRoutesToToday() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    func testStartAddingFromOnboardingOpensAddItemFlow() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["startAddingClothesButton"].tap()

        XCTAssertTrue(app.buttons["saveItemButton"].waitForExistence(timeout: 3))
    }

    func testTodayRecommendationCanRecordWoreFeedback() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let woreButton = app.buttons["todayFeedback_wore_0"]
        XCTAssertTrue(woreButton.waitForExistence(timeout: 3))
        woreButton.tap()

        XCTAssertTrue(app.staticTexts["Recorded as worn."].waitForExistence(timeout: 3))
    }

    func testTodayRecommendationCanRecordPreferenceFeedback() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["Tune future recommendations"].waitForExistence(timeout: 3))

        let goodFitButton = app.buttons["todayFeedback_liked_0"]
        XCTAssertTrue(goodFitButton.waitForExistence(timeout: 3))
        goodFitButton.tap()

        XCTAssertTrue(app.staticTexts["Preference saved."].waitForExistence(timeout: 3))
    }

    func testSavedOutfitCanOpenLooksFromConfirmation() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let saveButton = app.buttons["todayFeedback_saved_0"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        let viewLooksButton = app.buttons["todayFeedbackViewLooksButton"]
        XCTAssertTrue(viewLooksButton.waitForExistence(timeout: 3))
        viewLooksButton.tap()

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))
    }

    func testEmptyLooksCanReturnToToday() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_looks"].tap()

        let openTodayButton = app.buttons["looksEmptyOpenTodayButton"]
        XCTAssertTrue(openTodayButton.waitForExistence(timeout: 3))
        openTodayButton.tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    func testSettingsPreferenceAppliesToTodayRecommendation() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Soft Power Office"].waitForExistence(timeout: 3))

        app.buttons["appTab_settings"].tap()
        XCTAssertTrue(app.staticTexts["Workday brief"].waitForExistence(timeout: 3))

        let meetingOption = app.buttons["defaultScenarioOption_importantMeeting"]
        XCTAssertTrue(meetingOption.waitForExistence(timeout: 3))
        meetingOption.tap()

        XCTAssertTrue(app.staticTexts["Applied to Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_today"].tap()
        XCTAssertTrue(app.staticTexts["Executive Polish"].waitForExistence(timeout: 3))
    }

    func testAddClosetItemSmokeFlow() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()
        app.buttons["addItemButton"].tap()

        // System PhotosPicker library selection is not reliable in UI automation, so this
        // debug-only control persists a local test image through the same ImageStore path.
        app.buttons["useTestPhotoButton"].tap()
        app.swipeUp()
        app.swipeUp()

        let colorField = app.textFields["itemColorField"]
        XCTAssertTrue(colorField.waitForExistence(timeout: 3))
        colorField.tap()
        colorField.typeText("Ivory")

        let storageField = app.textFields["itemStorageField"]
        storageField.tap()
        storageField.typeText("Main wardrobe")

        app.buttons["seasonToggle_spring"].tap()

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Ivory"].waitForExistence(timeout: 3))
        let storageLabel = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Main wardrobe")).firstMatch
        XCTAssertTrue(storageLabel.exists)
    }

    func testClosetItemCanEditStatusAndFormality() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()

        let whiteShirtCard = app.buttons["closetItemCard_11111111-1111-1111-1111-111111111111"]
        XCTAssertTrue(whiteShirtCard.waitForExistence(timeout: 3))
        whiteShirtCard.tap()

        XCTAssertTrue(app.buttons["editItemButton"].waitForExistence(timeout: 3))
        app.buttons["editItemButton"].tap()
        app.swipeUp()
        app.swipeUp()

        let needsWashOption = app.buttons["statusOption_needsWash"]
        XCTAssertTrue(needsWashOption.waitForExistence(timeout: 3))
        needsWashOption.tap()

        let formalityIncreaseButton = app.buttons["formalityIncreaseButton"]
        XCTAssertTrue(formalityIncreaseButton.waitForExistence(timeout: 3))
        formalityIncreaseButton.tap()

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Needs Wash"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["5"].waitForExistence(timeout: 3))
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] = "1"
        return app
    }
}
