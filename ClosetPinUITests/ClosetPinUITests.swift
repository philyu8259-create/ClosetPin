import XCTest

@MainActor
final class ClosetPinUITests: XCTestCase {
    func testLaunchSmoke() {
        let app = XCUIApplication()
        app.launchEnvironment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] = "1"
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
    }

    func testUseSampleCapsuleRoutesToToday() {
        let app = XCUIApplication()
        app.launchEnvironment["CLOSETPIN_UI_TEST_IN_MEMORY_STORE"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3))
        app.buttons["useSampleCapsuleButton"].tap()

        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 3))
    }
}
