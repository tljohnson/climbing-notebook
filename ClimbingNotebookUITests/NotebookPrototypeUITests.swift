import XCTest

final class NotebookPrototypeUITests: XCTestCase {
    private func goBack(_ app: XCUIApplication) {
        let back = app.buttons["BackButton"]
        if back.exists { back.tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }

    private func openRoute(_ app: XCUIApplication) {
        app.launch()
        app.buttons["area-granite"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Paper Skyline")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["prototypeNotice"].exists)
    }

    private func editNotes(_ app: XCUIApplication, append text: String) {
        XCTAssertEqual(app.textViews.count, 0, "Browsing must not expose an editable field")
        app.buttons["Edit Notes"].tap()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(text)
        XCTAssertTrue((editor.value as? String)?.contains(text) == true)
        app.buttons["Dismiss keyboard"].tap()
        XCTAssertEqual(app.keyboards.count, 0)
        app.buttons["Finish Editing"].tap()
        XCTAssertEqual(app.textViews.count, 0)
    }

    func testNavigationEditingReorderAndRelaunchReset() {
        let app = XCUIApplication()
        openRoute(app)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Route notes")).firstMatch.tap()
        editNotes(app, append: "Synthetic edit")
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("Synthetic edit"))
        goBack(app)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic edit")).firstMatch.exists)
        app.buttons["pitch-slab"].tap()
        editNotes(app, append: "Pitch edit")
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("Pitch edit"))
        goBack(app)
        app.buttons["Edit Pitch Order"].tap()
        XCTAssertFalse(app.buttons["move-up-slab"].isEnabled)
        app.buttons["move-down-slab"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["pitch-slab"].label.contains("2. Opening slab"))
        app.buttons["pitch-slab"].tap()
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("Pitch edit"))
        app.terminate()
        openRoute(app)
        XCTAssertTrue(app.buttons["pitch-slab"].label.contains("1. Opening slab"))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Route notes")).firstMatch.tap()
        XCTAssertFalse(app.staticTexts["noteText"].label.contains("Synthetic edit"))
    }

    func testEmptyAreasNoPitchesAndFifthPitchScrolling() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["area-meadow"].tap()
        XCTAssertTrue(app.staticTexts["No routes entered"].exists)
        XCTAssertTrue(app.staticTexts["prototypeNotice"].exists)
        goBack(app)
        app.buttons["area-granite"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Unwritten Line")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "0 pitches entered")).firstMatch.exists)
        XCTAssertFalse(app.buttons["Edit Pitch Order"].exists)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Route notes")).firstMatch.tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, "No notes entered")
        app.buttons["Edit Notes"].tap()
        XCTAssertEqual(app.textViews["noteEditor"].value as? String, "")
        app.buttons["Finish Editing"].tap()
        goBack(app)
        goBack(app)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Paper Skyline")).firstMatch.tap()
        app.swipeUp()
        app.buttons["pitch-ridge"].tap()
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        XCTAssertTrue(app.staticTexts["Pitch 5 of 5 · 5.5"].exists)
    }

    func testDistinctPitchNotesFollowNamesAcrossMovesAndNavigation() {
        let app = XCUIApplication()
        openRoute(app)
        app.buttons["pitch-slab"].tap()
        let slabNotes = app.staticTexts["noteText"].label
        XCTAssertTrue(slabNotes.contains("rounded slab"))
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        XCTAssertFalse(app.buttons["Move Down"].exists)
        app.buttons["Next Pitch"].tap()
        XCTAssertTrue(app.staticTexts["Pitch 2 of 5 · 5.8"].exists)
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("fictional corner"))
        editNotes(app, append: "Corner-only edit")
        let cornerNotes = app.staticTexts["noteText"].label
        app.buttons["Previous Pitch"].tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, slabNotes)
        app.buttons["Next Pitch"].tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, cornerNotes)
        goBack(app)
        app.buttons["Edit Pitch Order"].tap()
        app.buttons["move-up-corner"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["pitch-corner"].label.contains("1. Quiet corner"))
        app.buttons["pitch-corner"].tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, cornerNotes)
        app.buttons["Next Pitch"].tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, slabNotes)
        goBack(app)
        app.buttons["Edit Pitch Order"].tap()
        for _ in 0..<4 { app.buttons["move-down-corner"].tap() }
        XCTAssertFalse(app.buttons["move-down-corner"].isEnabled)
        app.buttons["Done"].tap()
        app.swipeUp()
        app.buttons["pitch-corner"].tap()
        XCTAssertTrue(app.staticTexts["Pitch 5 of 5 · 5.8"].exists)
        XCTAssertEqual(app.staticTexts["noteText"].label, cornerNotes)
    }

    func testReorderModeIsExplicitAndSeparateFromNoteEditing() {
        let app = XCUIApplication()
        openRoute(app)
        XCTAssertFalse(app.buttons["Edit"].exists)
        XCTAssertFalse(app.buttons["Move Up"].exists)
        app.buttons["Edit Pitch Order"].tap()
        XCTAssertTrue(app.navigationBars["Edit Pitch Order"].exists)
        XCTAssertTrue(app.staticTexts["Prototype - changes reset on relaunch"].exists)
        XCTAssertFalse(app.buttons["pitch-slab"].isHittable)
        app.buttons["Done"].tap()
        app.buttons["pitch-slab"].tap()
        XCTAssertTrue(app.buttons["Next Pitch"].exists)
        XCTAssertFalse(app.buttons["Move Down"].exists)
        editNotes(app, append: "Explicit edit")
        XCTAssertTrue(app.staticTexts["noteText"].label.contains("Explicit edit"))
    }

    func testAccessibilitySizeNavigationAndLayout() {
        let app = XCUIApplication()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        openRoute(app)
        capture(app, name: "Read-only route at accessibility XXXL")
        XCTAssertTrue(app.staticTexts["prototypeNotice"].isHittable)
        app.buttons["Edit Pitch Order"].tap()
        capture(app, name: "Explicit reorder workflow at accessibility XXXL")
        XCTAssertTrue(app.buttons["move-down-slab"].isHittable)
        app.buttons["move-down-slab"].tap()
        app.buttons["Done"].tap()
        for _ in 0..<8 where !app.buttons["pitch-ridge"].isHittable { app.swipeUp() }
        app.buttons["pitch-ridge"].tap()
        capture(app, name: "Pitch navigation at accessibility XXXL")
        XCTAssertTrue(app.buttons["Previous Pitch"].isHittable)
        XCTAssertTrue(app.staticTexts["prototypeNotice"].isHittable)
        app.buttons["Edit Notes"].tap()
        let editor = app.textViews["noteEditor"]
        XCTAssertTrue(editor.isHittable)
        editor.tap()
        capture(app, name: "Explicit note editing at accessibility XXXL")
        app.buttons["Dismiss keyboard"].tap()
        XCTAssertTrue(app.buttons["Finish Editing"].exists)
        let keyboardDismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 5), .completed)
        app.buttons["Finish Editing"].tap()
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
