import XCTest

final class FoundationLaunchTests: XCTestCase {
    func testLaunchShowsHonestPrototypeState() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Climbing Notebook"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Prototype - changes reset on relaunch"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Built at Novacoast."].exists)
        XCTAssertFalse(app.staticTexts["Saved on this device"].exists)
    }
}
