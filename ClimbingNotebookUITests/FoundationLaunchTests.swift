import XCTest

final class FoundationLaunchTests: XCTestCase {
    func testDirectEmptyToFivePitchNotebookPreservesFullNotesAcrossProcessRelaunch() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTEBOOK_TEST_STORE"] = UUID().uuidString
        app.launchEnvironment["NOTEBOOK_TEXT_TEST"] = "1"
        app.launch()

        func addRecord(_ kind: String, _ name: String) -> String {
            let add = app.buttons["Add \(kind)"].firstMatch
            XCTAssertTrue(add.waitForExistence(timeout: 10))
            add.tap()
            let field = app.descendants(matching: .any)["textNameEditor"].firstMatch
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { field.tap() }
            field.typeText(name)
            XCTAssertEqual(field.value as? String, name)
            app.buttons["Dismiss keyboard"].tap()
            app.buttons["Add"].tap()
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                   object: app.collectionViews["textEditorForm"])
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
            if kind == "Pitch" {
                let jump = app.buttons["Jump to Pitches"]
                XCTAssertTrue(jump.waitForExistence(timeout: 5))
                jump.tap()
            }
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                "text-\(kind.lowercased())-", name)).firstMatch
            for _ in 0..<8 where !row.exists || !row.isHittable { app.collectionViews.firstMatch.swipeUp() }
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            return row.identifier
        }

        let areaID = addRecord("Area", "Direct area")
        app.buttons[areaID].tap()
        let routeID = addRecord("Route", "Direct route")
        app.buttons[routeID].tap()
        var pitchIDs: [String] = []
        for index in 1...5 {
            let addPitch = app.buttons["Add Pitch"]
            if !addPitch.isHittable { app.swipeUp() }
            pitchIDs.append(addRecord("Pitch", "Direct pitch \(index)"))
        }
        for _ in 0..<8 where !app.buttons["Edit General Notes"].isHittable { app.swipeDown() }
        XCTAssertTrue(app.buttons["Edit General Notes"].isHittable)
        app.buttons["Edit General Notes"].tap()
        let general = app.textViews["textNoteEditor"]
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        general.tap()
        general.typeText("Full route notes\nSecond line retained.")
        app.buttons["Finish Editing"].tap()
        app.buttons["Jump to Pitches"].tap()
        app.buttons[pitchIDs[0]].tap()
        app.buttons["Edit Notes"].tap()
        let pitchNotes = app.textViews["textNoteEditor"]
        XCTAssertTrue(pitchNotes.waitForExistence(timeout: 5))
        pitchNotes.tap()
        pitchNotes.typeText("Distinct pitch notes\nComplete body retained.")
        app.buttons["Finish Editing"].tap()
        XCTAssertTrue(app.staticTexts["textPitchNotes"].label.contains("Complete body retained."))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[areaID].waitForExistence(timeout: 10))
        app.buttons[areaID].tap()
        app.buttons[routeID].tap()
        XCTAssertTrue(app.staticTexts["textGeneralNotes"].label.contains("Second line retained."))
        app.buttons["Jump to Pitches"].tap()
        for identity in pitchIDs {
            for _ in 0..<8 where !app.buttons[identity].exists { app.collectionViews.firstMatch.swipeUp() }
            XCTAssertTrue(app.buttons[identity].exists)
        }
        app.buttons["Jump to Pitches"].tap()
        app.buttons[pitchIDs[0]].tap()
        XCTAssertTrue(app.staticTexts["textPitchNotes"].label.contains("Complete body retained."))
        XCTAssertTrue(app.staticTexts["Pitch 1 of 5"].exists)
    }

    func testEmptyTextNotebookCreatesAreaAndReopensAcknowledgedName() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTEBOOK_TEST_STORE"] = UUID().uuidString
        app.launchEnvironment["NOTEBOOK_TEXT_TEST"] = "1"
        app.launch()
        let addArea = app.buttons["Add Area"].firstMatch
        XCTAssertTrue(addArea.waitForExistence(timeout: 10))
        addArea.tap()
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Initial native area editor"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let name = app.descendants(matching: .any)["textNameEditor"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertTrue(name.isHittable)
        name.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            name.tap()
        }
        name.typeText("Synthetic durability area")
        app.buttons["Add"].tap()
        let area = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "text-area-")).firstMatch
        XCTAssertTrue(area.waitForExistence(timeout: 5))
        let identity = area.identifier
        XCTAssertTrue(area.label.contains("Synthetic durability area"))
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons[identity].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons[identity].label.contains("Synthetic durability area"))
    }

    func testRetainedPrototypeReadsWithoutMutationActions() {
        let app = XCUIApplication()
        app.launchEnvironment["NOTEBOOK_TEST_STORE"] = UUID().uuidString
        app.launchEnvironment["NOTEBOOK_RETAINED_READ_ONLY"] = "1"
        app.launch()
        let notice = app.staticTexts["prototypeNotice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 10))
        XCTAssertTrue(notice.label.contains("importance is unknown"))
        app.buttons["area-granite"].tap()
        XCTAssertFalse(app.buttons["Add Route"].exists)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Paper Skyline")).firstMatch.tap()
        XCTAssertFalse(app.buttons["Edit Pitch Order"].exists)
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Route notes")).firstMatch.tap()
        XCTAssertFalse(app.buttons["Edit Notes"].exists)
        XCTAssertTrue(app.staticTexts["noteText"].exists)
    }

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
        XCTAssertTrue(app.staticTexts["Built by Leif Digital."].exists)
        XCTAssertFalse(app.staticTexts["Saved on this device"].exists)
        XCTAssertFalse(app.staticTexts["Prototype - changes reset on relaunch"].exists)
    }
}
