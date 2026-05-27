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
        XCTAssertTrue(app.staticTexts["Main wardrobe"].exists)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launchEnvironment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] = "1"
        return app
    }
}
