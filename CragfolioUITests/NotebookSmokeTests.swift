import XCTest

final class NotebookSmokeTests: XCTestCase {
    func testFoundationLaunchesAndPersistsSyntheticSample() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Cragfolio Foundation"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Synthetic persistence sample: Synthetic Persistence Sample"].waitForExistence(timeout: 5))
    }

    func testWebKitHarnessCapturesSyntheticTextAndSelectedImage() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-url-copy-harness"]
        app.launch()

        XCTAssertTrue(app.staticTexts["URL Copy Feasibility Harness"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Harness-only page text."].waitForExistence(timeout: 10))
        let copyButton = app.buttons["Copy Selected Image"]
        XCTAssertTrue(copyButton.isEnabled)
        copyButton.tap()
        XCTAssertTrue(app.staticTexts["Image selected"].waitForExistence(timeout: 5))
    }
}
