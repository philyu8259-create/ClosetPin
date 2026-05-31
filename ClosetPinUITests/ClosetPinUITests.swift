import XCTest

@MainActor
final class ClosetPinUITests: XCTestCase {
    func testLaunchSmoke() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.otherElements["tomorrowPrepCard"].exists)
    }

    func testUseSampleCapsuleRoutesToToday() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    func testOnboardingFramesClosetBeyondWork() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["One closet, many plans"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Workdays"].exists)
        XCTAssertTrue(app.staticTexts["Meetings"].exists)
        XCTAssertTrue(app.staticTexts["Banquets"].exists)
        XCTAssertTrue(app.staticTexts["Weekends"].exists)
        XCTAssertTrue(app.buttons["Preview Recommendations"].exists)
        XCTAssertTrue(app.buttons["Add My Clothes"].exists)
        XCTAssertTrue(app.buttons["useSampleCapsuleButton"].isHittable)
    }

    func testTodayExplainsSimpleAiDecisionFlow() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["You choose"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AI ranks"].exists)
        XCTAssertTrue(app.staticTexts["You decide"].exists)
    }

    func testTodayPrimaryActionsAreVisibleWithoutExtraScroll() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.buttons["todayFeedback_wore_0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["todayFeedback_wore_0"].isHittable)
        XCTAssertTrue(app.buttons["todayFeedback_saved_0"].isHittable)
    }

    func testTodayKeepsSeasonAutomaticUnlessUserChangesIt() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["Auto season"].waitForExistence(timeout: 3))
        let systemDateNote = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "from system date")).firstMatch
        XCTAssertTrue(systemDateNote.exists)
        if !app.buttons["todaySeasonOverrideButton"].exists {
            app.swipeUp()
        }
        XCTAssertTrue(app.buttons["Change season"].exists)
    }

    func testTomorrowPrepExplainsWeatherAwareDecision() {
        let app = makeApp()
        app.launchEnvironment["CLOSETPIN_DEBUG_PRESEED_SAMPLE_CAPSULE"] = "1"
        app.launchEnvironment["CLOSETPIN_TOMORROW_WEATHER_PREVIEW"] = "rainy_commute"
        app.launch()

        XCTAssertTrue(app.staticTexts["Tomorrow Prep"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AI is checking your occasion, auto season, and tomorrow forecast before ranking this plan."].exists)
    }

    func testTomorrowPrepDoesNotHidePrimaryTodayActions() {
        let app = makeApp()
        app.launchEnvironment["CLOSETPIN_DEBUG_PRESEED_SAMPLE_CAPSULE"] = "1"
        app.launchEnvironment["CLOSETPIN_TOMORROW_WEATHER_PREVIEW"] = "rainy_commute"
        app.launch()

        XCTAssertTrue(app.staticTexts["Tomorrow Prep"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["todayFeedback_wore_0"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["todayFeedback_wore_0"].isHittable)
        XCTAssertTrue(app.buttons["todayFeedback_saved_0"].isHittable)
    }

    func testSimplifiedChineseTabsAndTodayActionsFitPrimaryFlow() {
        let app = makeApp(language: "zh-Hans", locale: "zh_CN")
        app.launch()

        XCTAssertTrue(app.staticTexts["10 分钟入门衣橱"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["先看示例推荐"].exists)
        XCTAssertTrue(app.buttons["添加自己的衣物"].exists)
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["今天穿这套"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["保存到穿搭"].exists)
        XCTAssertTrue(app.staticTexts["调整之后的推荐"].exists)
        XCTAssertTrue(app.staticTexts["这套包含"].exists)
        XCTAssertTrue(app.staticTexts["场合"].exists)
        XCTAssertTrue(app.staticTexts["AI 排序"].exists)
        XCTAssertTrue(app.buttons["宴会"].exists)

        app.buttons["appTab_closet"].tap()
        XCTAssertTrue(app.staticTexts["你的衣橱"].waitForExistence(timeout: 3))

        app.buttons["appTab_looks"].tap()
        XCTAssertTrue(app.staticTexts["从这里开始积累你的穿搭档案"].waitForExistence(timeout: 3))

        app.buttons["appTab_settings"].tap()
        XCTAssertTrue(app.staticTexts["穿搭简报"].waitForExistence(timeout: 3))
    }

    func testClosetExplainsTodayReadinessWithoutDefaultAdvancedFilters() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()

        XCTAssertTrue(app.staticTexts["Ready for Today"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["closetOpenTodayButton"].exists)
        XCTAssertFalse(app.buttons["Any Status"].exists)

        app.buttons["closetOpenTodayButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    func testStartAddingFromOnboardingOpensAddItemFlow() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["startAddingClothesButton"].tap()

        XCTAssertTrue(app.buttons["saveItemButton"].waitForExistence(timeout: 3))
    }

    func testAddItemExplainsPhotoAiHelpBeforeManualDetails() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["startAddingClothesButton"].tap()

        XCTAssertTrue(app.staticTexts["Item Photo"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AI can suggest type and color after the photo; you can still edit everything."].exists)
        XCTAssertTrue(app.staticTexts["To save this piece"].exists)
        XCTAssertTrue(app.staticTexts["Add a photo"].exists)
        XCTAssertTrue(app.staticTexts["Add a color"].exists)
    }

    func testAddItemFlowPrioritizesAutoSeasonOverAdvancedStyling() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()
        app.buttons["addItemButton"].tap()
        app.buttons["useTestPhotoButton"].tap()
        app.swipeUp()

        XCTAssertTrue(app.staticTexts["Auto season"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["closetSeasonChangeButton"].exists)
        XCTAssertFalse(app.buttons["seasonShortcut_current"].exists)
        XCTAssertFalse(app.buttons["formalityIncreaseButton"].exists)
    }

    func testAddItemCanSaveWithPhotoColorAndAutoSeason() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()
        app.buttons["addItemButton"].tap()
        app.buttons["useTestPhotoButton"].tap()
        app.swipeUp()

        let colorField = app.textFields["itemColorField"]
        XCTAssertTrue(colorField.waitForExistence(timeout: 3))
        colorField.tap()
        colorField.typeText("Ivory")

        XCTAssertTrue(app.staticTexts["Ready to save."].waitForExistence(timeout: 3))
        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Ivory"].waitForExistence(timeout: 3))
    }

    func testTodayMissingRecommendationOpensAddItemDirectly() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["startAddingClothesButton"].tap()

        XCTAssertTrue(app.buttons["saveItemButton"].waitForExistence(timeout: 3))
        app.buttons["useTestPhotoButton"].tap()
        app.swipeUp()

        let colorField = app.textFields["itemColorField"]
        XCTAssertTrue(colorField.waitForExistence(timeout: 3))
        colorField.tap()
        colorField.typeText("Ivory")

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Add one bottom to generate office outfits."].exists)

        let addMissingButton = app.buttons["todayMissingAddItemButton"]
        XCTAssertTrue(addMissingButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addMissingButton.isHittable)
        addMissingButton.tap()

        XCTAssertTrue(app.buttons["saveItemButton"].waitForExistence(timeout: 3))
    }

    func testTodayRecommendationCanRecordWoreFeedback() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let woreButton = app.buttons["todayFeedback_wore_0"]
        XCTAssertTrue(woreButton.waitForExistence(timeout: 3))
        woreButton.tap()

        XCTAssertTrue(app.staticTexts["Recorded as worn."].waitForExistence(timeout: 3))
    }

    func testTodayRecommendationCanRecordPreferenceFeedback() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
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

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let saveButton = app.buttons["todayFeedback_saved_0"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        let viewLooksButton = app.buttons["todayFeedbackViewLooksButton"]
        XCTAssertTrue(viewLooksButton.waitForExistence(timeout: 3))
        viewLooksButton.tap()

        XCTAssertTrue(app.staticTexts["Saved"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Saved from Today"].waitForExistence(timeout: 3))

        let addAnotherButton = app.buttons["looksArchiveOpenTodayButton"]
        XCTAssertTrue(addAnotherButton.exists)
        addAnotherButton.tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    func testTodayFeedbackConfirmationDoesNotBlockTabNavigation() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let saveButton = app.buttons["todayFeedback_saved_0"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()

        XCTAssertTrue(app.staticTexts["Saved to Looks."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["appTab_settings"].isHittable)
        app.buttons["appTab_settings"].tap()

        XCTAssertTrue(app.staticTexts["Style brief"].waitForExistence(timeout: 3))
    }

    func testTodayFeedbackConfirmationAutoDismisses() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let woreButton = app.buttons["todayFeedback_wore_0"]
        XCTAssertTrue(woreButton.waitForExistence(timeout: 3))
        woreButton.tap()

        XCTAssertTrue(app.staticTexts["Recorded as worn."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Recorded as worn."].waitForNonExistence(timeout: 4))
    }

    func testEmptyLooksCanReturnToToday() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_looks"].tap()

        let openTodayButton = app.buttons["looksEmptyOpenTodayButton"]
        XCTAssertTrue(openTodayButton.waitForExistence(timeout: 3))
        openTodayButton.tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }

    func testWornOutfitCanOpenLooksWithContext() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let woreButton = app.buttons["todayFeedback_wore_0"]
        XCTAssertTrue(woreButton.waitForExistence(timeout: 3))
        woreButton.tap()

        let viewLooksButton = app.buttons["todayFeedbackViewLooksButton"]
        XCTAssertTrue(viewLooksButton.waitForExistence(timeout: 3))
        viewLooksButton.tap()

        XCTAssertTrue(app.staticTexts["Actually worn"].waitForExistence(timeout: 3))
    }

    func testSettingsPreferenceAppliesToTodayRecommendation() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Soft Power Office"].waitForExistence(timeout: 3))

        app.buttons["appTab_settings"].tap()
        XCTAssertTrue(app.staticTexts["Style brief"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Saved for reference. Default occasion and formality are what shape Today right now."].exists)

        let meetingOption = app.buttons["defaultScenarioOption_importantMeeting"]
        XCTAssertTrue(meetingOption.waitForExistence(timeout: 3))
        meetingOption.tap()

        XCTAssertTrue(app.staticTexts["Applied to Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_today"].tap()
        XCTAssertTrue(app.staticTexts["Executive Polish"].waitForExistence(timeout: 3))
    }

    func testSettingsWeatherSuggestionsHaveSimpleCityFlow() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        app.buttons["appTab_settings"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow Weather"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Where AI steps in"].exists)
        XCTAssertFalse(app.textFields["tomorrowWeatherLocationField"].exists)

        let weatherToggle = app.switches["tomorrowWeatherToggle"]
        XCTAssertTrue(weatherToggle.waitForExistence(timeout: 3))
        weatherToggle.tap()

        let locationField = app.textFields["tomorrowWeatherLocationField"]
        XCTAssertTrue(locationField.waitForExistence(timeout: 3))
        locationField.tap()
        locationField.typeText("Shanghai")

        XCTAssertTrue(app.staticTexts["No GPS required. Today will refresh the forecast from this city when available."].exists)
        XCTAssertTrue(app.staticTexts["Ready for Today: Shanghai"].waitForExistence(timeout: 3))
    }

    func testAddClosetItemSmokeFlow() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()
        app.buttons["addItemButton"].tap()

        // System PhotosPicker library selection is not reliable in UI automation, so this
        // debug-only control persists a local test image through the same ImageStore path.
        app.buttons["useTestPhotoButton"].tap()
        app.swipeUp()

        let colorField = app.textFields["itemColorField"]
        XCTAssertTrue(colorField.waitForExistence(timeout: 3))
        colorField.tap()
        colorField.typeText("Ivory")

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Ivory"].waitForExistence(timeout: 3))
    }

    func testClosetItemCanEditStatusAndFormality() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()

        let visibleItemCard = app.buttons["closetItemCard_77777777-7777-7777-7777-777777777777"]
        XCTAssertTrue(visibleItemCard.waitForExistence(timeout: 3))
        visibleItemCard.tap()

        XCTAssertTrue(app.buttons["editItemButton"].waitForExistence(timeout: 3))
        app.buttons["editItemButton"].tap()
        app.swipeUp()
        app.swipeUp()

        let optionalDetails = app.buttons["optionalDetailsDisclosure"]
        XCTAssertTrue(optionalDetails.waitForExistence(timeout: 3))
        optionalDetails.tap()

        let needsWashOption = app.buttons["statusOption_needsWash"]
        XCTAssertTrue(needsWashOption.waitForExistence(timeout: 3))
        needsWashOption.tap()
        app.swipeUp()

        let formalityIncreaseButton = app.buttons["formalityIncreaseButton"]
        XCTAssertTrue(formalityIncreaseButton.waitForExistence(timeout: 3))
        formalityIncreaseButton.tap()

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Needs Wash"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["5"].waitForExistence(timeout: 3))
    }

    private func makeApp(
        language: String = "en",
        locale: String = "en_US"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launchEnvironment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] = "1"
        return app
    }
}
