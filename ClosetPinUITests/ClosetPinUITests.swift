import XCTest

final class ClosetPinUITests: XCTestCase {
    func testLaunchSmoke() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
