import XCTest

final class ClosetPinUITests: XCTestCase {
    func testLaunchSmoke() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(
            app.staticTexts["10-Minute Work Capsule"].waitForExistence(timeout: 3)
                || app.staticTexts["Today"].waitForExistence(timeout: 3)
        )
    }
}
