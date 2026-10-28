import XCTest

final class FoundationLaunchTests: XCTestCase {
    func testLaunchShowsHonestFoundationState() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Climbing Notebook"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Foundation build"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Built at Novacoast."].exists)
    }
}
