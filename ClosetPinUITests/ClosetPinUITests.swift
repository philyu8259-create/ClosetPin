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

    func testCompletedOnboardingWithEmptyClosetShowsActionableTabs() {
        let app = makeApp()
        app.launchEnvironment["CLOSETPIN_DEBUG_HAS_COMPLETED_ONBOARDING"] = "1"
        app.launch()

        XCTAssertFalse(app.staticTexts["10-Minute Starter Closet"].exists)
        XCTAssertTrue(app.staticTexts["Outfit ingredients needed"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()
        XCTAssertTrue(app.staticTexts["Build Your Closet"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.staticTexts["Why this works"].exists)
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
        XCTAssertTrue(app.staticTexts["Tomorrow prep: Soft Power Office"].exists)
        XCTAssertTrue(app.staticTexts["ClosetPin checks your occasion, auto season, and tomorrow forecast before suggesting what to prep."].exists)
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

        XCTAssertTrue(app.staticTexts["今天就穿"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["保存"].exists)
        XCTAssertTrue(app.staticTexts["微调这条建议"].exists)
        XCTAssertTrue(app.staticTexts["这套包含"].exists)
        XCTAssertTrue(app.staticTexts["场合"].exists)
        XCTAssertTrue(app.staticTexts["搭配依据"].exists)
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

    func testClosetSearchFiltersVisualGrid() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))

        app.buttons["appTab_closet"].tap()
        let searchField = app.textFields["closetSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 3))
        searchField.tap()
        searchField.typeText("Charcoal")

        let charcoalTop = app.buttons["closetItemCard_33333333-3333-3333-3333-333333333333"]
        let charcoalBlazer = app.buttons["closetItemCard_66666666-6666-6666-6666-666666666666"]
        let nonMatchingBlueTop = app.buttons["closetItemCard_22222222-2222-2222-2222-222222222222"]

        XCTAssertTrue(charcoalTop.waitForExistence(timeout: 3))
        XCTAssertTrue(charcoalBlazer.waitForExistence(timeout: 3))
        XCTAssertFalse(nonMatchingBlueTop.exists)
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
        XCTAssertTrue(app.staticTexts["photoAiHelpText"].exists)
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
        XCTAssertTrue(app.staticTexts["Photo preview"].waitForExistence(timeout: 3))
        app.swipeUp()

        XCTAssertTrue(app.staticTexts["Auto season"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["closetSeasonChangeButton"].exists)
        XCTAssertFalse(app.buttons["seasonShortcut_current"].exists)
        XCTAssertFalse(app.buttons["formalityIncreaseButton"].exists)
        XCTAssertFalse(app.buttons["formalityLevel_3"].exists)

        app.buttons["photoSuggestionEditManualButton"].tap()
        app.swipeUp()
        XCTAssertTrue(app.buttons["formalityLevel_3"].exists)
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

        let viewClosetButton = app.buttons["postSaveViewClosetButton"]
        XCTAssertTrue(viewClosetButton.waitForExistence(timeout: 3))
        viewClosetButton.tap()

        XCTAssertTrue(app.staticTexts["Ivory"].waitForExistence(timeout: 3))
    }

    func testAddItemAiSuggestionNeedsConfirmationBeforeApplying() {
        let app = makeApp()
        openAddItemFromSampleCloset(app)
        app.buttons["useTestPhotoButton"].tap()

        XCTAssertTrue(app.staticTexts["photoSuggestionReviewTitle"].waitForExistence(timeout: 3))
        let saveItemButton = app.buttons["saveItemButton"]
        XCTAssertTrue(saveItemButton.waitForExistence(timeout: 8))

        tapWhenReady(app.buttons["photoSuggestionDebugApplyButton"], in: app, timeout: 8, maxScrolls: 6)

        XCTAssertTrue(app.staticTexts["photoSuggestionReviewTitle"].waitForNonExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["photoAutoAppliedTag"].waitForExistence(timeout: 8))
        XCTAssertTrue(saveItemButton.waitForExistence(timeout: 3))
    }

    func testAddItemAiSuggestionCanBeReviewedManually() {
        let app = makeApp()
        openAddItemFromSampleCloset(app)
        app.buttons["useTestPhotoButton"].tap()

        XCTAssertTrue(app.staticTexts["photoSuggestionReviewTitle"].waitForExistence(timeout: 3))

        let manualReviewButton = app.buttons["photoSuggestionDebugManualButton"]
        XCTAssertTrue(manualReviewButton.waitForExistence(timeout: 8))
        tapWhenReady(manualReviewButton, in: app, timeout: 8, maxScrolls: 6)
        app.swipeUp()

        XCTAssertTrue(app.staticTexts["photoSuggestionReviewTitle"].waitForNonExistence(timeout: 8))
        let optionalDetailsDisclosure = app.buttons["optionalDetailsDisclosure"]
        let itemStorageField = app.textFields["itemStorageField"]
        var manualSectionAvailable = optionalDetailsDisclosure.waitForExistence(timeout: 3) || itemStorageField.waitForExistence(timeout: 3)
        if !manualSectionAvailable {
            for _ in 0..<4 {
                app.swipeUp()
                manualSectionAvailable = optionalDetailsDisclosure.waitForExistence(timeout: 2) || itemStorageField.waitForExistence(timeout: 2)
                if manualSectionAvailable { break }
            }
        }
        XCTAssertTrue(manualSectionAvailable)
    }

    func testAddItemAiSuggestionCanApplyOnlyColor() {
        let app = makeApp()
        openAddItemFromSampleCloset(app)
        app.buttons["useTestPhotoButton"].tap()

        XCTAssertTrue(app.staticTexts["photoSuggestionReviewTitle"].waitForExistence(timeout: 3))
        let useColorButton = app.buttons["photoSuggestionUseColorButton"]

        tapWhenReady(useColorButton, in: app, timeout: 8, maxScrolls: 12)

        XCTAssertTrue(app.staticTexts["photoSuggestionReviewTitle"].waitForNonExistence(timeout: 8))
        let colorField = app.textFields["itemColorField"]
        XCTAssertTrue(colorField.waitForExistence(timeout: 3))
        XCTAssertEqual(colorField.value as? String, "Ivory")
        let appliedTag = app.staticTexts["photoAutoAppliedTag"]
        XCTAssertTrue(appliedTag.waitForExistence(timeout: 8))
        XCTAssertTrue(appliedTag.label.contains("Color"))
        XCTAssertFalse(appliedTag.label.contains("Seasons"))

        app.swipeUp()
        let systemSeasonSummary = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS %@", "from system date"))
            .firstMatch
        XCTAssertTrue(systemSeasonSummary.waitForExistence(timeout: 3))
        XCTAssertTrue(systemSeasonSummary.label.contains("from system date"))
        XCTAssertFalse(systemSeasonSummary.label.contains("suggested from photo"))
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
        if app.buttons["postSaveViewClosetButton"].waitForExistence(timeout: 1) {
            app.buttons["postSaveViewClosetButton"].tap()
            app.buttons["appTab_today"].tap()
        }

        XCTAssertTrue(app.staticTexts["Add one bottom to generate office outfits."].waitForExistence(timeout: 3))

        let addMissingButton = app.buttons["todayMissingAddItemButton"]
        XCTAssertTrue(addMissingButton.waitForExistence(timeout: 3))
        XCTAssertTrue(addMissingButton.isHittable)
        addMissingButton.tap()

        XCTAssertTrue(app.buttons["saveItemButton"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Bottom"].waitForExistence(timeout: 3))
    }

    func testTodayRecommendationCanRecordWoreFeedback() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        let woreButton = app.buttons["todayFeedback_wore_0"]
        XCTAssertTrue(woreButton.waitForExistence(timeout: 3))
        woreButton.tap()

        XCTAssertTrue(app.staticTexts["Marked as worn today. You can find it in Looks."].waitForExistence(timeout: 3))
    }

    func testTodayRecommendationCanRecordPreferenceFeedback() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["Need a change?"].waitForExistence(timeout: 3))

        let moreButton = app.buttons["todayFeedbackMore_0"]
        XCTAssertTrue(moreButton.waitForExistence(timeout: 3))
        moreButton.tap()

        let avoidStyleButton = app.buttons["Avoid this style"]
        XCTAssertTrue(avoidStyleButton.waitForExistence(timeout: 3))
        avoidStyleButton.tap()

        XCTAssertTrue(app.staticTexts["Got it. We will show fewer looks like this."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["todayFeedbackUndoButton"].exists)
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

        XCTAssertTrue(app.staticTexts["Great. This look is marked for today."].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Great. This look is marked for today."].waitForNonExistence(timeout: 4))
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
        app.launchEnvironment["CLOSETPIN_DEBUG_PRESEED_SAMPLE_CAPSULE"] = "1"
        app.launchEnvironment["CLOSETPIN_DEBUG_TOMORROW_WEATHER_ENABLED"] = "1"
        app.launchEnvironment["CLOSETPIN_DEBUG_TOMORROW_WEATHER_LOCATION"] = "Shanghai"
        app.launch()

        app.buttons["appTab_settings"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow Weather"].waitForExistence(timeout: 3))

        let locationField = app.textFields["tomorrowWeatherLocationField"]
        if !locationField.exists {
            app.swipeUp()
        }
        XCTAssertTrue(locationField.waitForExistence(timeout: 5))

        XCTAssertTrue(app.staticTexts["Type one city. No location permission needed."].exists)
        XCTAssertTrue(app.staticTexts["Using city: Shanghai"].waitForExistence(timeout: 5))
    }

    func testTodayWeatherMissingCityCanOpenSettingsDirectly() {
        let app = makeApp()
        app.launchEnvironment["CLOSETPIN_DEBUG_PRESEED_SAMPLE_CAPSULE"] = "1"
        app.launchEnvironment["CLOSETPIN_DEBUG_TOMORROW_WEATHER_ENABLED"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["Tomorrow weather"].waitForExistence(timeout: 3))
        app.swipeUp()
        let addCityButton = app.buttons["tomorrowWeatherOpenSettingsButton"]
        XCTAssertTrue(addCityButton.waitForExistence(timeout: 5))
        addCityButton.tap()

        XCTAssertTrue(app.staticTexts["Tomorrow Weather"].waitForExistence(timeout: 3))
        app.swipeUp()
        XCTAssertTrue(app.textFields["tomorrowWeatherLocationField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Needs city"].waitForExistence(timeout: 3))
    }

    func testSettingsExplainsAiRoleWithoutExtraSetup() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        app.buttons["appTab_settings"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["AI & Privacy"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["AI only steps in where it saves you time, and you stay in control."].exists)
        XCTAssertTrue(app.staticTexts["Photo tags"].exists)
        XCTAssertTrue(app.staticTexts["Local first"].exists)
        XCTAssertTrue(app.staticTexts["Outfit explanations"].exists)
        XCTAssertTrue(app.staticTexts["Available on Today"].exists)
        XCTAssertTrue(app.staticTexts["Weather help"].exists)
        XCTAssertTrue(app.staticTexts["Optional"].exists)
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

        tapWhenReady(app.buttons["postSaveGenerateTodayButton"], in: app)
        XCTAssertTrue(app.buttons["todayFeedback_wore_0"].waitForExistence(timeout: 5))
    }

    func testClosetItemCanEditStatusAndFormality() {
        let app = makeApp()
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))

        app.buttons["appTab_closet"].tap()

        let visibleItemCard = app.buttons["closetItemCard_77777777-7777-7777-7777-777777777777"]
        XCTAssertTrue(visibleItemCard.waitForExistence(timeout: 5))
        visibleItemCard.tap()

        XCTAssertTrue(app.buttons["editItemButton"].waitForExistence(timeout: 5))
        app.buttons["editItemButton"].tap()
        app.swipeUp()
        app.swipeUp()

        let optionalDetails = app.buttons["optionalDetailsDisclosure"]
        XCTAssertTrue(optionalDetails.waitForExistence(timeout: 5))
        optionalDetails.tap()

        let needsWashOption = app.buttons["statusOption_needsWash"]
        XCTAssertTrue(needsWashOption.waitForExistence(timeout: 5))
        needsWashOption.tap()
        app.swipeUp()

        let polishedFormality = app.buttons["formalityLevel_5"]
        XCTAssertTrue(polishedFormality.waitForExistence(timeout: 5))
        polishedFormality.tap()

        app.buttons["saveItemButton"].tap()

        XCTAssertTrue(app.staticTexts["Needs Wash"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Polished"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["formalityIncreaseButton"].exists)
    }

    func testClosetNeedsWashFilterShowsOnlyNeedsWashItems() {
        let app = makeApp()
        app.launchEnvironment["CLOSETPIN_UI_TEST_SAMPLE_NEEDS_WASH"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))

        app.buttons["appTab_closet"].tap()
        let needsWashCard = app.buttons["closetItemCard_77777777-7777-7777-7777-777777777777"]
        let unrelatedCard = app.buttons["closetItemCard_55555555-5555-5555-5555-555555555555"]
        XCTAssertTrue(needsWashCard.waitForExistence(timeout: 5))
        XCTAssertTrue(unrelatedCard.exists)

        let needsWashChip = app.buttons["closetFilter_needsWash"]
        XCTAssertTrue(needsWashChip.waitForExistence(timeout: 5))
        XCTAssertTrue(needsWashChip.isHittable)
        needsWashChip.tap()

        XCTAssertTrue(needsWashCard.waitForExistence(timeout: 5))
        XCTAssertFalse(unrelatedCard.exists)
    }

    private func makeApp(
        language: String = "en",
        locale: String = "en_US"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launchEnvironment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] = "1"
        app.launchEnvironment["CLOSETPIN_DISABLE_CLOUD_AI"] = "1"
        return app
    }

    private func openAddItemFromSampleCloset(_ app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.staticTexts["10-Minute Starter Closet"].waitForExistence(timeout: 10))
        app.buttons["useSampleCapsuleButton"].tap()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 10))
        app.buttons["appTab_closet"].tap()
        XCTAssertTrue(app.buttons["addItemButton"].waitForExistence(timeout: 10))
        app.buttons["addItemButton"].tap()
        XCTAssertTrue(app.buttons["saveItemButton"].waitForExistence(timeout: 10))
    }

    private func tapWhenReady(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 8,
        maxScrolls: Int = 4
    ) {
        let start = Date()
        func nextHittableMatch() -> XCUIElement? {
            let matches = app.buttons.matching(identifier: element.identifier)
            for idx in 0..<matches.count {
                let candidate = matches.element(boundBy: idx)
                if candidate.isHittable {
                    return candidate
                }
            }
            return nil
        }

        let existenceExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true"),
            object: element
        )
        XCTAssertEqual(XCTWaiter().wait(for: [existenceExpectation], timeout: 3), .completed)

        for attempt in 0..<maxScrolls {
            if let tappable = nextHittableMatch() {
                tappable.tap()
                return
            }
            if Date().timeIntervalSince(start) > timeout {
                break
            }
            if attempt % 2 == 0 {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
        }

        if let tappable = nextHittableMatch() {
            tappable.tap()
            return
        }

        XCTFail("Failed to tap \(element.identifier): not hittable after scrolling")
    }

}
