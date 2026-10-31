import XCTest

final class NotebookPrototypeUITests: XCTestCase {
    private let fixtureOrder = ["slab", "corner", "traverse", "crack", "ridge"]
    private let pitchNames = ["slab": "Opening slab", "corner": "Quiet corner", "traverse": "High traverse",
                              "crack": "Upper crack", "ridge": "Summit ridge"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func application(failSave: Bool = false, accessibility: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // One namespace per test, retained unchanged through every process relaunch.
        app.launchEnvironment["NOTEBOOK_TEST_STORE"] = UUID().uuidString
        if failSave { app.launchEnvironment["NOTEBOOK_FAIL_SAVE"] = "1" }
        if accessibility {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        return app
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        _ = element.waitForExistence(timeout: 1)
        if reachable(element, in: app) { return }
        // Only the foreground Form/List should scroll, never the status bar or covered route.
        let towardTop = !element.exists
            || (element.frame != .zero && element.frame.midY < app.frame.midY)
        for down in [towardTop, !towardTop] {
            for _ in 0..<20 {
                let list = (app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex).last {
                    $0.isHittable || $0.cells.allElementsBoundByIndex.contains { $0.isHittable }
                }
                guard let list else { break }
                let bounds = list.frame.intersection(viewport(app)).insetBy(dx: 12, dy: 12)
                guard bounds.height > 40 else { break }
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: bounds.maxX - 4, dy: bounds.minY + bounds.height * (down ? 0.25 : 0.75)))
                let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: bounds.maxX - 4, dy: bounds.minY + bounds.height * (down ? 0.75 : 0.25)))
                start.press(forDuration: 0.05, thenDragTo: end)
                if reachable(element, in: app) { return }
            }
        }
        XCTFail("Control is not reachable: \(element)", file: file, line: line)
    }

    private func reachable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        element.exists && element.isHittable && (element.frame.intersection(visibleBounds(element, in: app)).height >= min(30, element.frame.height)
            || app.navigationBars.allElementsBoundByIndex.contains { $0.isHittable && $0.frame.contains(element.frame) })
    }

    private func visibleBounds(_ element: XCUIElement, in app: XCUIApplication) -> CGRect {
        var bounds = viewport(app)
        let match = NSPredicate(format: "identifier == %@ AND label == %@", element.identifier, element.label)
        for container in app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex {
            if container.isHittable && container.descendants(matching: element.elementType).matching(match).firstMatch.exists {
                bounds = bounds.intersection(container.frame)
            }
        }
        return bounds
    }

    private func viewport(_ app: XCUIApplication) -> CGRect {
        let top = app.navigationBars.allElementsBoundByIndex.filter { $0.isHittable }
            .map { $0.frame.maxY }.max() ?? (app.frame.minY + 90)
        return CGRect(x: app.frame.minX, y: top, width: app.frame.width,
                      height: max(0, app.frame.maxY - 34 - top))
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        let bounds = visibleBounds(element, in: app)
        let visible = element.frame.intersection(bounds)
        if bounds.contains(element.frame)
            || app.navigationBars.allElementsBoundByIndex.contains(where: { $0.isHittable && $0.frame.contains(element.frame) }) {
            element.tap()
        } else {
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: visible.midY)).tap()
        }
    }

    private func goBack(_ app: XCUIApplication) {
        let back = app.buttons["BackButton"]
        if back.exists { back.tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }

    private func routeLink(_ app: XCUIApplication, name: String = "Paper Skyline") -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
    }

    private func routeNotes(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Route notes")).firstMatch
    }

    private func openRoute(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["area-granite"].waitForExistence(timeout: 10))
        tap(app.buttons["area-granite"], in: app)
        tap(routeLink(app), in: app)
        XCTAssertTrue(app.staticTexts["prototypeNotice"].exists)
    }

    private func relaunchRoute(_ app: XCUIApplication) {
        app.terminate()
        app.launch()
        openRoute(app)
        assertAcknowledgment(app, "Loaded from this device")
    }

    private func assertAcknowledgment(_ app: XCUIApplication, _ text: String) {
        if app.buttons["Jump to Pitches"].isHittable { app.buttons["Jump to Pitches"].tap() }
        let acknowledgment = app.staticTexts["saveAcknowledgment"]
        reveal(acknowledgment, in: app)
        XCTAssertEqual(acknowledgment.label, text)
    }

    private func assertEditorClosed(_ app: XCUIApplication) {
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                               object: app.staticTexts["editorSaveState"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    }

    private func assertState(_ app: XCUIApplication, _ text: String) {
        let state = app.staticTexts["editorSaveState"]
        reveal(state, in: app)
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", text), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
    }

    @discardableResult
    private func draftNotes(_ app: XCUIApplication, append text: String) -> String {
        XCTAssertFalse(app.textViews["noteEditor"].exists, "Browsing must remain read-only")
        app.buttons["Edit Notes"].tap()
        let editor = app.textViews["noteEditor"]
        reveal(editor, in: app)
        XCTAssertTrue(editor.exists)
        editor.tap()
        editor.typeText(text)
        let value = editor.value as? String ?? ""
        XCTAssertTrue(value.contains(text))
        app.buttons["Dismiss keyboard"].tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                  object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        assertState(app, "Unsaved changes")
        return value
    }

    private func saveNotes(_ app: XCUIApplication, append text: String) -> String {
        let value = draftNotes(app, append: text)
        tap(app.buttons["Finish Editing"], in: app)
        assertEditorClosed(app)
        XCTAssertEqual(app.staticTexts["noteText"].label, value)
        return value
    }

    private func assertOrder(_ app: XCUIApplication, _ order: [String]) {
        XCTAssertEqual(order.count, 5)
        app.buttons["Jump to Pitches"].tap()
        var verified = Set<String>()
        for _ in 0..<12 {
            for (index, id) in order.enumerated() {
                let pitch = app.buttons["pitch-\(id)"]
                if pitch.exists {
                    XCTAssertTrue(pitch.label.contains("\(index + 1). \(pitchNames[id]!)"), pitch.label)
                    verified.insert(id)
                }
            }
            if verified.count == order.count { return }
            app.collectionViews.firstMatch.swipeUp()
        }
        XCTAssertEqual(verified, Set(order), "Every numbered stable-ID row must be observed")
    }

    func testRouteAndDistinctPitchNotesAndWholeOrderSurviveRepeatedProcessLaunches() {
        let app = application()
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let routeText = saveNotes(app, append: "\nSynthetic route saved exactly.\nSecond line.")
        goBack(app)
        assertAcknowledgment(app, "Saved on this device")
        tap(app.buttons["pitch-slab"], in: app)
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        let slabText = saveNotes(app, append: "\nSLAB-only saved note")
        app.buttons["Next Pitch"].tap()
        XCTAssertTrue(app.navigationBars["Quiet corner"].exists)
        let cornerText = saveNotes(app, append: "\nCORNER-only saved note")
        XCTAssertFalse(cornerText.contains("SLAB-only"))
        app.buttons["Previous Pitch"].tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, slabText)
        XCTAssertFalse(slabText.contains("CORNER-only"))
        goBack(app)
        tap(app.buttons["Edit Pitch Order"], in: app)
        tap(app.buttons["move-up-corner"], in: app)
        tap(app.buttons["move-up-ridge"], in: app)
        tap(app.buttons["Done"], in: app)
        assertEditorClosed(app)
        let savedOrder = ["corner", "slab", "traverse", "ridge", "crack"]
        assertOrder(app, savedOrder)

        for _ in 0..<2 {
            relaunchRoute(app)
            assertOrder(app, savedOrder)
            tap(routeNotes(app), in: app)
            XCTAssertEqual(app.staticTexts["noteText"].label, routeText)
            goBack(app)
            tap(app.buttons["pitch-corner"], in: app)
            XCTAssertEqual(app.staticTexts["noteText"].label, cornerText)
            XCTAssertTrue(app.staticTexts["Pitch 1 of 5 · 5.8"].exists)
            XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
            app.buttons["Next Pitch"].tap()
            XCTAssertTrue(app.navigationBars["Opening slab"].exists)
            XCTAssertEqual(app.staticTexts["noteText"].label, slabText)
            goBack(app)
            // Visible aggregate counts plus every numbered stable ID avoid offscreen query counts.
            goBack(app)
            reveal(routeLink(app), in: app)
            XCTAssertTrue(routeLink(app).label.contains("5 pitches entered"))
            reveal(routeLink(app, name: "Unwritten Line"), in: app)
            XCTAssertTrue(routeLink(app, name: "Unwritten Line").label.contains("0 pitches entered"))
            goBack(app)
            XCTAssertTrue(app.buttons["area-granite"].label.contains("2 routes"))
            XCTAssertTrue(app.buttons["area-meadow"].label.contains("0 routes"))
        }
    }

    func testCancelDiscardAndTerminateUnsavedNotesAndOrderRetainAcknowledgedVersion() {
        let app = application()
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let savedText = saveNotes(app, append: "\nPrior acknowledged route")
        let discarded = draftNotes(app, append: "UNSAVED discard")
        tap(app.buttons["Cancel"], in: app)
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 3))
        app.buttons["Keep Editing"].tap()
        reveal(app.textViews["noteEditor"], in: app)
        XCTAssertEqual(app.textViews["noteEditor"].value as? String, discarded)
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Discard Changes"].tap()
        assertEditorClosed(app)
        XCTAssertEqual(app.staticTexts["noteText"].label, savedText)
        draftNotes(app, append: "UNSAVED termination")
        relaunchRoute(app)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, savedText)
        goBack(app)
        tap(app.buttons["Edit Pitch Order"], in: app)
        tap(app.buttons["move-down-slab"], in: app)
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Discard Changes"].tap()
        assertEditorClosed(app)
        assertOrder(app, fixtureOrder)
        tap(app.buttons["Edit Pitch Order"], in: app)
        tap(app.buttons["move-down-slab"], in: app)
        relaunchRoute(app)
        assertOrder(app, fixtureOrder)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, savedText)
    }

    func testNoteFailureRetainsExactBufferAndRetryAcknowledgesOnlySuccess() {
        let app = application(failSave: true)
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let text = draftNotes(app, append: "\nRetained failed route text")
        tap(app.buttons["Finish Editing"], in: app)
        assertSaveFailure(app)
        reveal(app.textViews["noteEditor"], in: app)
        XCTAssertEqual(app.textViews["noteEditor"].value as? String, text)
        tap(app.buttons["Retry"], in: app)
        assertEditorClosed(app)
        XCTAssertEqual(app.staticTexts["noteText"].label, text)
        goBack(app)
        assertAcknowledgment(app, "Saved on this device")
        app.launchEnvironment.removeValue(forKey: "NOTEBOOK_FAIL_SAVE")
        relaunchRoute(app)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, text)
    }

    private func assertSaveFailure(_ app: XCUIApplication) {
        assertState(app, "Not saved - retry")
        let detail = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@",
            "Synthetic save failure. Your changes remain in this editor.")).firstMatch
        reveal(detail, in: app)
        XCTAssertTrue(detail.exists)
        capture(app, name: "Exact save failure row")
        reveal(app.buttons["Retry"], in: app)
        XCTAssertTrue(app.buttons["Retry"].isHittable)
        reveal(app.buttons["Reload Saved Version"], in: app)
        XCTAssertTrue(app.buttons["Reload Saved Version"].isHittable)
        XCTAssertFalse(app.staticTexts["saveAcknowledgment"].isHittable)
        XCTAssertFalse(app.staticTexts["Saved on this device"].isHittable)
    }

    func testOrderFailureRetainsWholeOrderAndRetryPersistsIt() {
        let app = application(failSave: true)
        app.launch()
        openRoute(app)
        tap(app.buttons["Edit Pitch Order"], in: app)
        XCTAssertFalse(app.buttons["move-up-slab"].isEnabled)
        tap(app.buttons["move-down-slab"], in: app)
        tap(app.buttons["Done"], in: app)
        assertSaveFailure(app)
        for (index, id) in ["corner", "slab", "traverse", "crack", "ridge"].enumerated() {
            let move = app.buttons["move-\(index == 0 ? "down" : "up")-\(id)"]
            reveal(move, in: app)
            let row = app.cells.containing(.button, identifier: "move-up-\(id)").firstMatch
            let title = "\(index + 1). \(pitchNames[id]!)"
            XCTAssertTrue(row.label.contains(title) || row.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch.exists,
                "Retained order row must contain \(title): \(row.debugDescription)")
        }
        tap(app.buttons["Retry"], in: app)
        assertEditorClosed(app)
        let order = ["corner", "slab", "traverse", "crack", "ridge"]
        assertOrder(app, order)
        assertAcknowledgment(app, "Saved on this device")
        app.launchEnvironment.removeValue(forKey: "NOTEBOOK_FAIL_SAVE")
        relaunchRoute(app)
        assertOrder(app, order)
    }

    func testReloadSavedVersionRequiresConfirmationAndDiscardsFailedBuffer() {
        let app = application()
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let savedText = saveNotes(app, append: "\nSaved before failed edit")
        app.launchEnvironment["NOTEBOOK_FAIL_SAVE"] = "1"
        relaunchRoute(app)
        tap(routeNotes(app), in: app)
        draftNotes(app, append: "DO NOT KEEP failed buffer")
        tap(app.buttons["Finish Editing"], in: app)
        assertSaveFailure(app)
        tap(app.buttons["Reload Saved Version"], in: app)
        let confirm = app.buttons["Reload and Discard Changes"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        confirm.tap()
        assertState(app, "No unsaved changes")
        reveal(app.textViews["noteEditor"], in: app)
        XCTAssertEqual(app.textViews["noteEditor"].value as? String, savedText)
        tap(app.buttons["Finish Editing"], in: app)
        assertEditorClosed(app)
        XCTAssertEqual(app.staticTexts["noteText"].label, savedText)
        goBack(app)
        assertAcknowledgment(app, "Loaded from this device")
    }

    func testLoadFailureNeverFallsBackToEmptyFixturesAndRetryLoadsSavedData() {
        let app = application()
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let savedText = saveNotes(app, append: "\nRetained across failed load")
        app.terminate()
        app.launchEnvironment["NOTEBOOK_FAIL_LOAD"] = "1"
        app.launch()
        XCTAssertTrue(app.staticTexts["Notebook unavailable"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Synthetic load failure. Retained data has not been reset."].exists)
        XCTAssertFalse(app.buttons["area-granite"].exists)
        XCTAssertFalse(app.buttons["area-meadow"].exists)
        XCTAssertFalse(app.staticTexts["No routes entered"].exists)
        XCTAssertFalse(app.staticTexts["saveAcknowledgment"].exists)
        app.buttons["Retry Loading"].tap()
        openRoute(app)
        assertAcknowledgment(app, "Loaded from this device")
        assertOrder(app, fixtureOrder)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, savedText)
    }

    func testUnchangedFinishAndCancelDoNotInventSaveOrConsumeFailure() {
        let app = application(failSave: true)
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let original = app.staticTexts["noteText"].label
        app.buttons["Edit Notes"].tap()
        assertState(app, "No unsaved changes")
        tap(app.buttons["Finish Editing"], in: app)
        assertEditorClosed(app)
        XCTAssertEqual(app.staticTexts["noteText"].label, original)
        app.buttons["Edit Notes"].tap()
        tap(app.buttons["Cancel"], in: app)
        assertEditorClosed(app)
        XCTAssertFalse(app.buttons["Discard Changes"].exists)
        goBack(app)
        assertAcknowledgment(app, "Loaded from this device")
        tap(app.buttons["Edit Pitch Order"], in: app)
        assertState(app, "No unsaved changes")
        tap(app.buttons["Done"], in: app)
        assertEditorClosed(app)
        assertAcknowledgment(app, "Loaded from this device")
        tap(routeNotes(app), in: app)
        draftNotes(app, append: "First actual mutation must still fail")
        tap(app.buttons["Finish Editing"], in: app)
        assertSaveFailure(app)
    }

    func testEmptyAreasNoPitchesAndFifthPitchScrolling() {
        let app = application()
        app.launch()
        XCTAssertTrue(app.buttons["area-meadow"].waitForExistence(timeout: 10))
        app.buttons["area-meadow"].tap()
        XCTAssertTrue(app.staticTexts["No routes entered"].exists)
        XCTAssertTrue(app.staticTexts["prototypeNotice"].exists)
        goBack(app)
        app.buttons["area-granite"].tap()
        tap(routeLink(app, name: "Unwritten Line"), in: app)
        XCTAssertFalse(app.buttons["Edit Pitch Order"].exists)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, "No notes entered")
        app.buttons["Edit Notes"].tap()
        reveal(app.textViews["noteEditor"], in: app)
        XCTAssertEqual(app.textViews["noteEditor"].value as? String, "")
        tap(app.buttons["Finish Editing"], in: app)
        assertEditorClosed(app)
        goBack(app)
        goBack(app)
        tap(routeLink(app), in: app)
        tap(app.buttons["pitch-ridge"], in: app)
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        XCTAssertTrue(app.staticTexts["Pitch 5 of 5 · 5.5"].exists)
        XCTAssertFalse(app.buttons["Move Down"].exists)
        XCTAssertFalse(app.textViews["noteEditor"].exists)
    }

    func testAccessibilitySizeNavigationEditorErrorAndOrderLayout() {
        let app = application(failSave: true, accessibility: true)
        app.launch()
        openRoute(app)
        capture(app, name: "Read-only route at accessibility XXXL")
        XCTAssertTrue(app.staticTexts["prototypeNotice"].isHittable)
        XCTAssertFalse(app.buttons["Move Up"].exists)
        tap(app.buttons["pitch-ridge"], in: app)
        capture(app, name: "Pitch navigation at accessibility XXXL")
        reveal(app.buttons["Previous Pitch"], in: app)
        XCTAssertTrue(app.buttons["Previous Pitch"].isEnabled)
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        let text = draftNotes(app, append: "\nXXXL retained note")
        reveal(app.textViews["noteEditor"], in: app)
        capture(app, name: "Note editor at accessibility XXXL")
        tap(app.buttons["Finish Editing"], in: app)
        assertSaveFailure(app)
        capture(app, name: "Save error and retry at accessibility XXXL")
        tap(app.buttons["Retry"], in: app)
        assertEditorClosed(app)
        reveal(app.staticTexts["noteText"], in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, text)
        goBack(app)
        tap(app.buttons["Edit Pitch Order"], in: app)
        XCTAssertTrue(app.staticTexts["Edit Pitch Order"].exists)
        tap(app.buttons["move-down-slab"], in: app)
        capture(app, name: "Explicit order editor at accessibility XXXL")
        tap(app.buttons["Done"], in: app)
        assertEditorClosed(app)
        assertOrder(app, ["corner", "slab", "traverse", "crack", "ridge"])
    }

    func testLongNotesReadingQuickJumpAndPinnedPitchNavigation() {
        checkLongNotesReading(accessibility: false)
    }

    func testLongNotesReadingAndPinnedNavigationAtLargestText() {
        checkLongNotesReading(accessibility: true)
    }

    private func checkLongNotesReading(accessibility: Bool) {
        let app = application(accessibility: accessibility)
        app.launch()
        openRoute(app)
        tap(routeNotes(app), in: app)
        let longText = (1...12).map { "\nSynthetic reading line \($0): retain notes with their owner." }.joined()
        let routeText = saveNotes(app, append: longText)
        goBack(app)
        XCTAssertEqual(app.staticTexts["routeNoteText"].label, routeText)
        XCTAssertTrue(app.buttons["Jump to Pitches"].isHittable)
        app.buttons["Jump to Pitches"].tap()
        XCTAssertTrue(app.buttons["pitch-slab"].isHittable)
        tap(app.buttons["pitch-slab"], in: app)
        let pitchText = saveNotes(app, append: longText)
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(app.buttons["Next Pitch"].isHittable)
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        let note = app.staticTexts["noteText"]
        for _ in 0..<12 {
            if note.frame.maxY <= app.frame.maxY - 34 { break }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertLessThanOrEqual(note.frame.maxY, app.frame.maxY - 34, "Final note lines must remain reachable below pinned controls")
        capture(app, name: "Long pitch notes with pinned navigation")
        app.buttons["Next Pitch"].tap()
        XCTAssertTrue(app.navigationBars["Quiet corner"].exists)
        XCTAssertTrue(app.buttons["Previous Pitch"].isHittable)
        XCTAssertTrue(app.buttons["Next Pitch"].isHittable)
        app.buttons["Previous Pitch"].tap()
        XCTAssertEqual(app.staticTexts["noteText"].label, pitchText)
        app.buttons["Edit Notes"].tap()
        XCTAssertEqual(app.staticTexts["editorContext"].label, "Paper Skyline / Pitch notes")
        tap(app.buttons["Cancel"], in: app)
        assertEditorClosed(app)
        relaunchRoute(app)
        goBack(app)
        tap(routeLink(app), in: app)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, routeText)
        goBack(app)
        app.buttons["Jump to Pitches"].tap()
        assertOrder(app, fixtureOrder)
        tap(app.buttons["pitch-slab"], in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, pitchText)
        goBack(app)
        assertAcknowledgment(app, "Loaded from this device")
    }

    private func openArea(_ app: XCUIApplication, alias: String = "meadow") {
        let area = app.buttons["area-\(alias)"]
        XCTAssertTrue(area.waitForExistence(timeout: 10))
        tap(area, in: app)
    }

    private func nameField(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "routeNameEditor").firstMatch
    }

    private func beginRoute(_ app: XCUIApplication, name: String) {
        tap(app.buttons["Add Route"], in: app)
        let field = nameField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        capture(app, name: "Add Route initial form")
        tap(field, in: app)
        field.typeText(name)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        let dismissKeyboard = app.buttons["Dismiss keyboard"]
        reveal(dismissKeyboard, in: app)
        XCTAssertTrue(dismissKeyboard.isHittable)
        // Simulator may expose an off-screen keyboard; this tests focus dismissal, not rendered keys.
        let keyboardCapture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        keyboardCapture.name = "Add Route focused field and dismissal control"
        keyboardCapture.lifetime = .keepAlways
        add(keyboardCapture)
        dismissKeyboard.tap()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                  object: app.keyboards.firstMatch)
        XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
        XCTAssertEqual(field.value as? String, name)
    }

    private func assertCreationClosed(_ app: XCUIApplication) {
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                               object: app.staticTexts["creationSaveState"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    }

    private func addedRouteIDs(_ app: XCUIApplication, name: String) -> [String] {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label BEGINSWITH %@", "route-", name))
            .allElementsBoundByIndex.map(\.identifier).sorted()
    }

    func testAddDuplicateRoutesGeneralNotesAndStableIDsSurviveProcessRelaunch() {
        let app = application()
        app.launch()
        // Preserve preexisting acknowledged fixture notes/order through creation.
        openRoute(app)
        tap(routeNotes(app), in: app)
        let fixtureNotes = saveNotes(app, append: "\nFixture retained through creation")
        goBack(app)
        tap(app.buttons["Edit Pitch Order"], in: app)
        tap(app.buttons["move-down-slab"], in: app)
        tap(app.buttons["Done"], in: app)
        assertEditorClosed(app)
        goBack(app)
        goBack(app)
        openArea(app)
        let name = "Synthetic Twin"
        var ids: [String] = []
        var notes: [String: String] = [:]
        for number in 1...2 {
            beginRoute(app, name: name)
            tap(app.buttons["Add"], in: app)
            assertCreationClosed(app)
            let current = addedRouteIDs(app, name: name)
            XCTAssertEqual(current.count, number)
            let id = current.first { !ids.contains($0) }!
            XCTAssertNotNil(UUID(uuidString: String(id.dropFirst("route-".count))))
            ids = current
            tap(app.buttons[id], in: app)
            XCTAssertTrue(app.staticTexts["0 pitches entered"].exists)
            XCTAssertFalse(app.buttons["Edit Pitch Order"].exists)
            assertAcknowledgment(app, "Saved on this device")
            tap(routeNotes(app), in: app)
            XCTAssertEqual(app.staticTexts["noteText"].label, "No notes entered")
            notes[id] = saveNotes(app, append: "Twin \(number)\nDistinct General notes")
            goBack(app)
            goBack(app)
        }
        for _ in 0..<2 {
            app.terminate()
            app.launch()
            XCTAssertTrue(app.buttons["area-meadow"].waitForExistence(timeout: 10))
            XCTAssertTrue(app.buttons["area-meadow"].label.contains("2 routes"))
            openArea(app)
            XCTAssertEqual(addedRouteIDs(app, name: name), ids)
            for id in ids {
                tap(app.buttons[id], in: app)
                assertAcknowledgment(app, "Loaded from this device")
                tap(routeNotes(app), in: app)
                XCTAssertEqual(app.staticTexts["noteText"].label, notes[id])
                goBack(app)
                goBack(app)
            }
        }
        goBack(app)
        openRoute(app)
        assertOrder(app, ["corner", "slab", "traverse", "crack", "ridge"])
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, fixtureNotes)
    }

    func testCreationValidationCancelAndUnsavedTerminationDoNotCreateRoutes() {
        let app = application()
        app.launch()
        openArea(app)
        tap(app.buttons["Add Route"], in: app)
        tap(app.buttons["Add"], in: app)
        XCTAssertEqual(app.staticTexts["creationSaveState"].label, "Not saved - retry")
        tap(app.buttons["Cancel"], in: app)
        assertCreationClosed(app)
        XCTAssertFalse(app.buttons["Discard Changes"].exists)
        beginRoute(app, name: "   ")
        tap(app.buttons["Add"], in: app)
        XCTAssertEqual(app.staticTexts["creationSaveState"].label, "Not saved - retry")
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Keep Editing"].tap()
        XCTAssertEqual(nameField(app).value as? String, "   ")
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Discard Changes"].tap()
        assertCreationClosed(app)
        beginRoute(app, name: String(repeating: "x", count: 501))
        tap(app.buttons["Add"], in: app)
        XCTAssertEqual(app.staticTexts["creationSaveState"].label, "Not saved - retry")
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Discard Changes"].tap()
        assertCreationClosed(app)
        beginRoute(app, name: "Never added")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["area-meadow"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["area-meadow"].label.contains("0 routes"))
        openArea(app)
        XCTAssertTrue(app.staticTexts["No routes entered"].exists)
        XCTAssertTrue(addedRouteIDs(app, name: "Never added").isEmpty)
    }

    func testCreationFailureRetryAndUnsavedGeneralTerminationRetainOneRoute() {
        checkCreationFailure(accessibility: false)
    }

    func testCreationAtLargestTextRetainsDraftAndAccessibleRecovery() {
        checkCreationFailure(accessibility: true)
    }

    func testCreationInDarkAppearanceRetainsDraftAndRecovery() {
        checkCreationFailure(accessibility: false, dark: true)
    }

    private func checkCreationFailure(accessibility: Bool, dark: Bool = false) {
        let app = application(failSave: true, accessibility: accessibility)
        if dark { app.launchEnvironment["NOTEBOOK_TEST_DARK"] = "1" }
        app.launch()
        openArea(app, alias: "granite")
        let name = "Synthetic route with a longer name for wrapping"
        beginRoute(app, name: name)
        capture(app, name: "Add Route draft")
        tap(app.buttons["Add"], in: app)
        let state = app.staticTexts["creationSaveState"]
        reveal(state, in: app)
        XCTAssertEqual(state.label, "Not saved - retry")
        reveal(nameField(app), in: app)
        XCTAssertEqual(nameField(app).value as? String, name)
        capture(app, name: "Add Route retained failure")
        XCTAssertFalse(app.staticTexts["Saved on this device"].isHittable)
        tap(app.buttons["Retry"], in: app)
        assertCreationClosed(app)
        let ids = addedRouteIDs(app, name: name)
        XCTAssertEqual(ids.count, 1)
        tap(app.buttons[ids[0]], in: app)
        tap(routeNotes(app), in: app)
        let saved = saveNotes(app, append: "Acknowledged new route notes")
        draftNotes(app, append: "UNSAVED do not retain")
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NOTEBOOK_FAIL_SAVE")
        app.launch()
        XCTAssertTrue(app.buttons["area-granite"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["area-granite"].label.contains("3 routes"))
        openArea(app, alias: "granite")
        XCTAssertEqual(addedRouteIDs(app, name: name), ids)
        tap(app.buttons[ids[0]], in: app)
        assertAcknowledgment(app, "Loaded from this device")
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, saved)
        // Existing-field failure recovery also works on arbitrary (nonfixture) IDs.
        app.terminate()
        app.launchEnvironment["NOTEBOOK_FAIL_SAVE"] = "1"
        app.launch()
        openArea(app, alias: "granite")
        tap(app.buttons[ids[0]], in: app)
        tap(routeNotes(app), in: app)
        let retryText = draftNotes(app, append: "\nRetry new route notes")
        tap(app.buttons["Finish Editing"], in: app)
        assertSaveFailure(app)
        tap(app.buttons["Retry"], in: app)
        assertEditorClosed(app)
        XCTAssertEqual(app.staticTexts["noteText"].label, retryText)
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NOTEBOOK_FAIL_SAVE")
        app.launch()
        openArea(app, alias: "granite")
        XCTAssertEqual(addedRouteIDs(app, name: name), ids)
        tap(app.buttons[ids[0]], in: app)
        tap(routeNotes(app), in: app)
        XCTAssertEqual(app.staticTexts["noteText"].label, retryText)
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
