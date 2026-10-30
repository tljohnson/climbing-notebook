import XCTest

final class FoundationLaunchTests: XCTestCase {
    func testLaunchShowsHonestSyntheticNotebookState() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTEBOOK_TEST_STORE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.navigationBars["Climbing Notebook"].waitForExistence(timeout: 10))
        let notice = app.staticTexts["prototypeNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertEqual(notice.label, "Synthetic notebook - explicit saves stay on this device. Not for personal data; backup/restore unavailable.")
        XCTAssertTrue(app.buttons["area-granite"].label.contains("Example Granite"))
        XCTAssertTrue(app.buttons["area-meadow"].label.contains("Example Meadow"))
        XCTAssertTrue(app.staticTexts["Built at Novacoast."].exists)
        XCTAssertFalse(app.staticTexts["Saved on this device"].exists)
        XCTAssertFalse(app.staticTexts["Prototype - changes reset on relaunch"].exists)
    }
}
