import XCTest

final class TextNotebookUITests: XCTestCase {
    private struct Pitch {
        let id: String
        var name: String
        var notes: String = ""
    }

    private struct Route {
        let id: String
        var name: String
        var notes: String = ""
        var pitches: [Pitch] = []
    }

    private struct Area {
        let id: String
        var name: String
        var routes: [Route] = []
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        if let testRun, testRun.failureCount > 0 {
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "Rendered screen at UI test failure"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    private func application(accessibility: Bool = false, dark: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        // Allocate once per test; every terminate/launch below reuses this exact namespace.
        app.launchEnvironment["NOTEBOOK_TEST_STORE"] = UUID().uuidString
        app.launchEnvironment["NOTEBOOK_TEXT_TEST"] = "1"
        if dark { app.launchEnvironment["NOTEBOOK_TEST_DARK"] = "1" }
        if accessibility {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func viewport(_ app: XCUIApplication) -> CGRect {
        let top = app.navigationBars.allElementsBoundByIndex.filter { $0.isHittable }
            .map { $0.frame.maxY }.max() ?? (app.frame.minY + 90)
        return CGRect(x: app.frame.minX, y: top, width: app.frame.width,
                      height: max(0, app.frame.maxY - 34 - top))
    }

    private func reachable(_ element: XCUIElement, in app: XCUIApplication) -> Bool {
        element.exists && element.isHittable && (element.frame.intersection(visibleBounds(element, in: app)).height >= min(30, element.frame.height)
            || (element.label == "Close Examples" && app.frame.contains(element.frame))
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

    private func foregroundList(_ app: XCUIApplication) -> XCUIElement? {
        let editor = app.collectionViews["textEditorForm"]
        if editor.exists { return editor }
        let examples = app.collectionViews["textExamplesLibrary"]
        if examples.exists { return examples }
        return app.collectionViews.allElementsBoundByIndex.last
            ?? app.scrollViews.allElementsBoundByIndex.last { $0.isHittable }
    }

    private func library(_ app: XCUIApplication) -> XCUIElement {
        let examples = app.collectionViews["textExamplesLibrary"]
        return examples.exists ? examples : app.collectionViews["textLibrary"]
    }

    private func addButton(_ app: XCUIApplication, kind: String) -> XCUIElement {
        kind == "area" ? library(app).buttons["Add Area"] : app.buttons["Add \(kind.capitalized)"]
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) {
        if !element.exists { _ = element.waitForExistence(timeout: 1) }
        if reachable(element, in: app) { return }
        // Validation rows can virtualize a field below the visible Form.
        let towardTop = element.exists && element.frame != .zero && element.frame.midY < app.frame.midY
        for down in [towardTop, !towardTop] {
            var previousRows: [String] = []
            for _ in 0..<6 {
                let list = foregroundList(app)
                guard let list else { break }
                let rows = list.cells.allElementsBoundByIndex.map { "\($0.label):\($0.frame)" }
                if !rows.isEmpty && rows == previousRows { break }
                previousRows = rows
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
        capture(app, "Unreachable target \(element)")
        XCTFail("Control is not reachable: \(element)", file: file, line: line)
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        reveal(element, in: app)
        let closesExamples = element.label == "Close Examples"
        let bounds = visibleBounds(element, in: app)
        if bounds.contains(element.frame) || element.label == "Close Examples"
            || app.navigationBars.allElementsBoundByIndex.contains(where: { $0.isHittable && $0.frame.contains(element.frame) }) {
            element.tap()
        } else {
            let visible = element.frame.intersection(bounds)
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: visible.midX, dy: visible.midY)).tap()
        }
        if closesExamples {
            let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                                   object: app.buttons["Close Examples"])
            XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
        }
    }

    private func back(_ app: XCUIApplication) {
        let button = app.buttons["BackButton"]
        if button.exists { button.tap() }
        else { app.navigationBars.buttons.element(boundBy: 0).tap() }
    }

    private func assertLibrary(_ app: XCUIApplication) {
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 10))
        let source = library(app).descendants(matching: .any).matching(identifier: "sourceLabel").firstMatch
        reveal(source, in: app)
        XCTAssertEqual(source.label, "Notebook")
    }

    private func relaunch(_ app: XCUIApplication, failSave: Bool = false, failLoad: Bool = false) {
        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NOTEBOOK_FAIL_SAVE")
        app.launchEnvironment.removeValue(forKey: "NOTEBOOK_FAIL_LOAD")
        if failSave { app.launchEnvironment["NOTEBOOK_FAIL_SAVE"] = "1" }
        if failLoad { app.launchEnvironment["NOTEBOOK_FAIL_LOAD"] = "1" }
        app.launch()
        if !failLoad { assertLibrary(app) }
    }

    private func assertClosed(_ app: XCUIApplication) {
        let closed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"),
                                               object: app.staticTexts["textEditorSaveState"])
        XCTAssertEqual(XCTWaiter.wait(for: [closed], timeout: 5), .completed)
    }

    private func assertState(_ app: XCUIApplication, _ text: String) {
        let state = app.staticTexts["textEditorSaveState"]
        reveal(state, in: app)
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", text), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
    }

    private func fill(_ field: XCUIElement, with text: String, in app: XCUIApplication) {
        tap(field, in: app)
        let value = field.value as? String ?? ""
        let previous = value == field.placeholderValue ? "" : value
        if !previous.isEmpty {
            // A tap may place the caret at the start, so backward deletes cannot clear the old value.
            field.press(forDuration: 1)
            let menuItem = app.menuItems["Select All"]
            let selectAll = menuItem.exists ? menuItem : app.buttons["Select All"]
            XCTAssertTrue(selectAll.waitForExistence(timeout: 3))
            selectAll.tap()
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        if !text.isEmpty { field.typeText(text) }
        let actual = field.value as? String ?? ""
        XCTAssertEqual(actual == field.placeholderValue ? "" : actual, text)
        tap(app.buttons["Dismiss keyboard"], in: app)
    }

    private func beginName(_ app: XCUIApplication, action: String, name: String) {
        tap(action == "Add Area" ? library(app).buttons[action] : app.buttons[action], in: app)
        XCTAssertTrue(nameField(app).waitForExistence(timeout: 3))
        fill(nameField(app), with: name, in: app)
    }

    private func nameField(_ app: XCUIApplication) -> XCUIElement {
        // v2 captured index zero before the modal existed, permanently querying the covered root.
        XCTAssertTrue(app.collectionViews["textEditorForm"].waitForExistence(timeout: 5))
        let field = app.collectionViews["textEditorForm"]
            .descendants(matching: .any).matching(identifier: "textNameEditor").firstMatch
        reveal(field, in: app)
        return field
    }

    private func rowIDs(_ app: XCUIApplication, kind: String) -> [String] {
        (kind == "area" ? library(app).buttons : app.buttons).matching(NSPredicate(format: "identifier BEGINSWITH %@", "text-\(kind)-"))
            .allElementsBoundByIndex.map(\.identifier)
    }

    @discardableResult
    private func create(_ app: XCUIApplication, kind: String, name: String) -> String {
        reveal(addButton(app, kind: kind), in: app)
        let previous = Set(rowIDs(app, kind: kind))
        beginName(app, action: "Add \(kind.capitalized)", name: name)
        tap(app.buttons["Add"], in: app)
        assertClosed(app)
        reveal(addButton(app, kind: kind), in: app)
        let matches = (kind == "area" ? library(app).buttons : app.buttons).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
            "text-\(kind)-", name.isEmpty ? "Pitch" : name)).allElementsBoundByIndex
        let candidate = matches.first { !previous.contains($0.identifier) }
        if let candidate { reveal(candidate, in: app) }
        let added = matches.map(\.identifier).filter { !previous.contains($0) }
        XCTAssertEqual(added.count, 1)
        let id = added.first ?? "missing-\(kind)"
        XCTAssertNotNil(UUID(uuidString: String(id.dropFirst("text-\(kind)-".count))))
        return id
    }

    private func actions(_ app: XCUIApplication, kind: String, action: String) {
        tap(app.buttons["\(kind) Actions"], in: app)
        tap(app.buttons["\(action) \(kind)"], in: app)
    }

    private func rename(_ app: XCUIApplication, kind: String, name: String) {
        actions(app, kind: kind, action: "Rename")
        fill(nameField(app), with: name, in: app)
        tap(app.buttons["Save"], in: app)
        assertClosed(app)
    }

    private func editNotes(_ app: XCUIApplication, action: String, text: String, save: Bool = true) {
        tap(app.buttons[action], in: app)
        XCTAssertTrue(app.textViews["textNoteEditor"].waitForExistence(timeout: 3))
        fill(app.textViews["textNoteEditor"], with: text, in: app)
        assertState(app, "Unsaved changes")
        if save {
            tap(app.buttons["Finish Editing"], in: app)
            assertClosed(app)
        }
    }

    private func discard(_ app: XCUIApplication) {
        tap(app.buttons["Cancel"], in: app)
        XCTAssertTrue(app.buttons["Discard Changes"].waitForExistence(timeout: 3))
        app.buttons["Discard Changes"].tap()
        assertClosed(app)
    }

    private func recordID(_ rowID: String) -> String {
        String(rowID.split(separator: "-").dropFirst(2).joined(separator: "-"))
    }

    private func move(_ app: XCUIApplication, id: String, direction: String) {
        tap(app.collectionViews["textEditorForm"].buttons["move-\(direction)-\(recordID(id))"], in: app)
    }

    private func order(_ app: XCUIApplication, kind: String, ids: [String], names: [String]) {
        XCTAssertEqual(ids.count, names.count)
        beginOrder(app, kind: kind)
        for (index, id) in ids.enumerated() {
            let form = app.collectionViews["textEditorForm"]
            let anyRow = form.descendants(matching: .any).matching(identifier: "order-\(recordID(id))").firstMatch
            reveal(anyRow, in: app)
            XCTAssertTrue(anyRow.exists)
            let title = "\(index + 1). \(names[index])"
            XCTAssertEqual(anyRow.label, title)
            XCTAssertEqual(Array(anyRow.label.utf8), Array(title.utf8))
            XCTAssertEqual(anyRow.value as? String, "Position \(index + 1) of \(ids.count)")
            let up = form.buttons["move-up-\(recordID(id))"]
            let down = form.buttons["move-down-\(recordID(id))"]
            XCTAssertTrue(up.exists)
            XCTAssertTrue(down.exists)
            XCTAssertEqual(up.isEnabled, index != 0)
            XCTAssertEqual(down.isEnabled, index != ids.count - 1)
        }
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
    }

    private func beginOrder(_ app: XCUIApplication, kind: String) {
        if kind != "Area" { tap(app.buttons[kind == "Route" ? "Area Actions" : "Route Actions"], in: app) }
        tap(app.buttons["Edit \(kind) Order"], in: app)
    }

    private func assertFailure(_ app: XCUIApplication) {
        assertState(app, "Not saved - retry")
        let message = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Synthetic save failure")).firstMatch
        reveal(message, in: app)
        XCTAssertTrue(message.exists)
        XCTAssertTrue(app.buttons["Retry"].isEnabled)
        XCTAssertFalse(app.staticTexts["Saved on this device"].isHittable)
        capture(app, "Retained synthetic save failure")
    }

    private func verify(_ app: XCUIApplication, areas: [Area], loaded: Bool = true) {
        assertLibrary(app)
        XCTAssertEqual(Set(rowIDs(app, kind: "area")), Set(areas.map(\.id)))
        order(app, kind: "Area", ids: areas.map(\.id), names: areas.map(\.name))
        for area in areas {
            let areaRow = app.buttons[area.id]
            reveal(areaRow, in: app)
            XCTAssertTrue(areaRow.label.contains(area.name))
            XCTAssertTrue(areaRow.label.contains("\(area.routes.count) routes"))
            tap(areaRow, in: app)
            XCTAssertEqual(Set(rowIDs(app, kind: "route")), Set(area.routes.map(\.id)))
            if !area.routes.isEmpty {
                order(app, kind: "Route", ids: area.routes.map(\.id), names: area.routes.map(\.name))
            }
            for route in area.routes {
                let routeRow = app.buttons[route.id]
                reveal(routeRow, in: app)
                XCTAssertTrue(routeRow.label.contains(route.name))
                XCTAssertTrue(routeRow.label.contains("\(route.pitches.count) pitches entered"))
                tap(routeRow, in: app)
                if loaded {
                    reveal(app.staticTexts["textSaveStatus"], in: app)
                    XCTAssertEqual(app.staticTexts["textSaveStatus"].label, "Loaded from this device")
                }
                let general = app.staticTexts["textGeneralNotes"]
                reveal(general, in: app)
                XCTAssertEqual(general.label, route.notes.isEmpty ? "No General notes entered" : route.notes)
                XCTAssertEqual(Array(general.label.utf8), Array((route.notes.isEmpty ? "No General notes entered" : route.notes).utf8))
                XCTAssertFalse(app.textViews["textNoteEditor"].exists)
                if !route.pitches.isEmpty {
                    tap(app.buttons["Jump to Pitches"], in: app)
                    order(app, kind: "Pitch", ids: route.pitches.map(\.id), names: route.pitches.map(\.name))
                }
                XCTAssertEqual(Set(rowIDs(app, kind: "pitch")), Set(route.pitches.map(\.id)))
                for (index, pitch) in route.pitches.enumerated() {
                    let row = app.buttons[pitch.id]
                    reveal(row, in: app)
                    XCTAssertTrue(row.label.contains("\(index + 1). \(pitch.name)"), row.label)
                    tap(row, in: app)
                    XCTAssertEqual(app.staticTexts["textPitchNotes"].label,
                                   pitch.notes.isEmpty ? "No notes entered" : pitch.notes)
                    XCTAssertEqual(Array(app.staticTexts["textPitchNotes"].label.utf8),
                                   Array((pitch.notes.isEmpty ? "No notes entered" : pitch.notes).utf8))
                    XCTAssertEqual(app.buttons["Previous Pitch"].isEnabled, index != 0)
                    XCTAssertEqual(app.buttons["Next Pitch"].isEnabled, index != route.pitches.count - 1)
                    back(app)
                }
                back(app)
            }
            back(app)
        }
    }

    func testEmptyNotebookFivePitchesDuplicateRoutesNotesAndPitchOrderSurviveProcessRelaunch() {
        let app = application()
        app.launch()
        assertLibrary(app)
        XCTAssertTrue(app.staticTexts["No areas entered"].exists)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Example Granite")).firstMatch.exists)
        var first = Area(id: create(app, kind: "area", name: "North Cafe\u{301}"), name: "North Cafe\u{301}")
        let second = Area(id: create(app, kind: "area", name: "South"), name: "South")
        tap(app.buttons[first.id], in: app)
        var route = Route(id: create(app, kind: "route", name: "Twin"), name: "Twin")
        var twin = Route(id: create(app, kind: "route", name: "Twin"), name: "Twin")
        XCTAssertNotEqual(route.id, twin.id)
        tap(app.buttons[route.id], in: app)
        route.notes = "General exact text\nCafe\u{301}, \u{96ea}, and trailing spaces  "
        editNotes(app, action: "Edit General Notes", text: route.notes)
        for number in 1...5 {
            var pitch = Pitch(id: create(app, kind: "pitch", name: "Pitch name \(number)"), name: "Pitch name \(number)")
            tap(app.buttons[pitch.id], in: app)
            pitch.notes = "Distinct pitch \(number)\nExact synthetic notes \(number)."
            editNotes(app, action: "Edit Notes", text: pitch.notes)
            route.pitches.append(pitch)
            back(app)
        }
        beginOrder(app, kind: "Pitch")
        move(app, id: route.pitches[4].id, direction: "up")
        move(app, id: route.pitches[1].id, direction: "up")
        tap(app.buttons["Done"], in: app)
        assertClosed(app)
        route.pitches.swapAt(3, 4)
        route.pitches.swapAt(0, 1)
        back(app)
        tap(app.buttons[twin.id], in: app)
        twin.notes = "Other duplicate route owns only these General notes."
        editNotes(app, action: "Edit General Notes", text: twin.notes)
        back(app)
        first.routes = [route, twin]
        back(app)
        // All-kind rename/order durability has its own shorter workflows below.
        relaunch(app)
        verify(app, areas: [first, second])
    }

    func testInvalidNamesKeepEditingDiscardAndTerminatedDraftsNeverCreateRecords() {
        let app = application()
        app.launch()
        assertLibrary(app)
        tap(app.buttons["Add Area"], in: app)
        tap(app.buttons["Add"], in: app)
        assertState(app, "Not saved - retry")
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
        XCTAssertFalse(app.buttons["Discard Changes"].exists)
        for name in ["   ", String(repeating: "x", count: 501)] {
            beginName(app, action: "Add Area", name: name)
            tap(app.buttons["Add"], in: app)
            assertState(app, "Not saved - retry")
            XCTAssertEqual(nameField(app).value as? String, name)
            tap(app.buttons["Cancel"], in: app)
            app.buttons["Keep Editing"].tap()
            XCTAssertEqual(nameField(app).value as? String, name)
            discard(app)
        }
        beginName(app, action: "Add Area", name: "Unsaved area")
        relaunch(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
        let area = create(app, kind: "area", name: "Saved area")
        tap(app.buttons[area], in: app)
        beginName(app, action: "Add Route", name: "Unsaved route")
        relaunch(app)
        tap(app.buttons[area], in: app)
        XCTAssertTrue(rowIDs(app, kind: "route").isEmpty)
        let route = create(app, kind: "route", name: "Saved route")
        tap(app.buttons[route], in: app)
        let pitch = create(app, kind: "pitch", name: "")
        XCTAssertTrue(app.buttons[pitch].label.contains("1. Pitch 1"))
        beginName(app, action: "Add Pitch", name: "Unsaved pitch")
        relaunch(app)
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        XCTAssertEqual(rowIDs(app, kind: "pitch"), [pitch])
        order(app, kind: "Pitch", ids: [pitch], names: ["Pitch 1"])
    }

    func testSingleAreaCreationAndProcessRelaunchSmoke() {
        let app = application()
        app.launch()
        assertLibrary(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
        let id = create(app, kind: "area", name: "Synthetic smoke area")
        XCTAssertEqual(rowIDs(app, kind: "area"), [id])
        capture(app, "Acknowledged single-area creation")
        relaunch(app)
        XCTAssertEqual(rowIDs(app, kind: "area"), [id])
        XCTAssertTrue(app.buttons[id].label.contains("Synthetic smoke area"))
        XCTAssertTrue(app.buttons[id].label.contains("0 routes"))
        capture(app, "Single-area process readback")
    }

    func testCanceledAndTerminatedNotesRenameAndAllOrderDraftsRetainAcknowledgedGraph() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let areaID = create(app, kind: "area", name: "Retained area")
        let empty = Area(id: create(app, kind: "area", name: "Empty area"), name: "Empty area")
        tap(app.buttons[areaID], in: app)
        var route = Route(id: create(app, kind: "route", name: "Retained route"), name: "Retained route")
        let other = Route(id: create(app, kind: "route", name: "Other route"), name: "Other route")
        tap(app.buttons[route.id], in: app)
        route.notes = "Prior acknowledged General\nDo not replace."
        editNotes(app, action: "Edit General Notes", text: route.notes)
        let first = Pitch(id: create(app, kind: "pitch", name: "First"), name: "First")
        let last = Pitch(id: create(app, kind: "pitch", name: "Last"), name: "Last")
        route.pitches = [first, last]
        editNotes(app, action: "Edit General Notes", text: "Discard this note", save: false)
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Keep Editing"].tap()
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, "Discard this note")
        discard(app)
        editNotes(app, action: "Edit General Notes", text: "Terminated note", save: false)
        relaunch(app)
        tap(app.buttons[areaID], in: app)
        tap(app.buttons[route.id], in: app)
        XCTAssertEqual(app.staticTexts["textGeneralNotes"].label, route.notes)
        beginOrder(app, kind: "Pitch")
        move(app, id: first.id, direction: "down")
        discard(app)
        beginOrder(app, kind: "Pitch")
        move(app, id: first.id, direction: "down")
        relaunch(app)
        tap(app.buttons[areaID], in: app)
        beginOrder(app, kind: "Route")
        move(app, id: route.id, direction: "down")
        discard(app)
        beginOrder(app, kind: "Route")
        move(app, id: route.id, direction: "down")
        relaunch(app)
        tap(app.buttons[areaID], in: app)
        actions(app, kind: "Area", action: "Rename")
        fill(nameField(app), with: "Unsaved rename", in: app)
        discard(app)
        back(app)
        beginOrder(app, kind: "Area")
        move(app, id: areaID, direction: "down")
        discard(app)
        beginOrder(app, kind: "Area")
        move(app, id: areaID, direction: "down")
        relaunch(app)
        verify(app, areas: [Area(id: areaID, name: "Retained area", routes: [route, other]), empty])
    }

    func testDeletionConfirmationCancelNonemptyAreaAndDeleteLastItemsPersist() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Delete area")
        let survivor = Area(id: create(app, kind: "area", name: "Surviving area"), name: "Surviving area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Delete route")
        actions(app, kind: "Area", action: "Delete")
        XCTAssertFalse(app.buttons["Delete"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "contains 1 routes")).firstMatch.exists)
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
        tap(app.buttons[route], in: app)
        editNotes(app, action: "Edit General Notes", text: "General owned by deleted route")
        let first = create(app, kind: "pitch", name: "First")
        let last = create(app, kind: "pitch", name: "Last")
        tap(app.buttons[last], in: app)
        editNotes(app, action: "Edit Notes", text: "Retained until last pitch deletion")
        back(app)
        tap(app.buttons[first], in: app)
        actions(app, kind: "Pitch", action: "Delete")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Delete First from Delete route")).firstMatch.exists)
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        actions(app, kind: "Pitch", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        XCTAssertEqual(app.staticTexts["textPitchNotes"].label, "Retained until last pitch deletion")
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        relaunch(app)
        let remaining = Pitch(id: last, name: "Last", notes: "Retained until last pitch deletion")
        verify(app, areas: [Area(id: area, name: "Delete area", routes: [
            Route(id: route, name: "Delete route", notes: "General owned by deleted route", pitches: [remaining])
        ]), survivor])
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        tap(app.buttons[last], in: app)
        actions(app, kind: "Pitch", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        XCTAssertTrue(app.buttons["Edit General Notes"].exists)
        XCTAssertTrue(rowIDs(app, kind: "pitch").isEmpty)
        actions(app, kind: "Route", action: "Delete")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "0 pitches and 1 General note")).firstMatch.exists)
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
        actions(app, kind: "Route", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        XCTAssertTrue(rowIDs(app, kind: "route").isEmpty)
        actions(app, kind: "Area", action: "Delete")
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
        actions(app, kind: "Area", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        for _ in 0..<2 {
            relaunch(app)
            verify(app, areas: [survivor])
        }
        tap(app.buttons[survivor.id], in: app)
        actions(app, kind: "Area", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        relaunch(app)
        XCTAssertTrue(app.staticTexts["No areas entered"].exists)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
    }

    func testCreateFailuresRetainEachDraftAndRetryCreatesExactlyOneOfEachKind() {
        let app = application()
        app.launchEnvironment["NOTEBOOK_FAIL_SAVE"] = "1"
        app.launch()
        assertLibrary(app)
        beginName(app, action: "Add Area", name: "Retry area")
        tap(app.buttons["Add"], in: app)
        assertFailure(app)
        XCTAssertEqual(nameField(app).value as? String, "Retry area")
        tap(app.buttons["Retry"], in: app)
        assertClosed(app)
        let areas = rowIDs(app, kind: "area")
        XCTAssertEqual(areas.count, 1)
        relaunch(app, failSave: true)
        tap(app.buttons[areas[0]], in: app)
        beginName(app, action: "Add Route", name: "Retry route")
        tap(app.buttons["Add"], in: app)
        assertFailure(app)
        XCTAssertEqual(nameField(app).value as? String, "Retry route")
        tap(app.buttons["Retry"], in: app)
        assertClosed(app)
        let routes = rowIDs(app, kind: "route")
        XCTAssertEqual(routes.count, 1)
        relaunch(app, failSave: true)
        tap(app.buttons[areas[0]], in: app)
        tap(app.buttons[routes[0]], in: app)
        beginName(app, action: "Add Pitch", name: "Retry pitch")
        tap(app.buttons["Add"], in: app)
        assertFailure(app)
        XCTAssertEqual(nameField(app).value as? String, "Retry pitch")
        tap(app.buttons["Retry"], in: app)
        assertClosed(app)
        let pitches = rowIDs(app, kind: "pitch")
        XCTAssertEqual(pitches.count, 1)
        relaunch(app)
        verify(app, areas: [Area(id: areas[0], name: "Retry area", routes: [
            Route(id: routes[0], name: "Retry route", pitches: [Pitch(id: pitches[0], name: "Retry pitch")])
        ])])
    }

    func testFailedNotesReloadAndLoadRetryNeverReplaceAcknowledgedHierarchyWithEmptyState() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Failure area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Failure route")
        tap(app.buttons[route], in: app)
        let saved = "Acknowledged exact General\nSecond line."
        editNotes(app, action: "Edit General Notes", text: saved)
        relaunch(app, failSave: true)
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        editNotes(app, action: "Edit General Notes", text: "Failed buffer retained", save: false)
        tap(app.buttons["Finish Editing"], in: app)
        assertFailure(app)
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, "Failed buffer retained")
        tap(app.buttons["Reload Saved Version"], in: app)
        app.buttons["Keep Editing"].tap()
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, "Failed buffer retained")
        tap(app.buttons["Reload Saved Version"], in: app)
        app.buttons["Reload and Discard Changes"].tap()
        assertState(app, "No unsaved changes")
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, saved)
        tap(app.buttons["Finish Editing"], in: app)
        assertClosed(app)
        relaunch(app, failLoad: true)
        XCTAssertTrue(app.staticTexts["Notebook unavailable"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Retained files have not been reset")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["No areas entered"].exists)
        XCTAssertFalse(app.buttons["Add Area"].exists)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
        XCTAssertFalse(app.staticTexts["textSaveStatus"].exists)
        tap(app.buttons["Retry Loading"], in: app)
        let expected = [Area(id: area, name: "Failure area", routes: [Route(id: route, name: "Failure route", notes: saved)])]
        verify(app, areas: expected)
        relaunch(app)
        verify(app, areas: expected)
    }

    func testRenameFailuresRetainExactNamesAndRetryAllEntityKinds() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Original area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Original route")
        tap(app.buttons[route], in: app)
        let pitch = create(app, kind: "pitch", name: "Original pitch")
        for kind in ["Area", "Route", "Pitch"] {
            relaunch(app, failSave: true)
            tap(app.buttons[area], in: app)
            if kind != "Area" { tap(app.buttons[route], in: app) }
            if kind == "Pitch" { tap(app.buttons[pitch], in: app) }
            actions(app, kind: kind, action: "Rename")
            let name = "Renamed \(kind) exactly"
            fill(nameField(app), with: name, in: app)
            tap(app.buttons["Save"], in: app)
            assertFailure(app)
            XCTAssertEqual(nameField(app).value as? String, name)
            tap(app.buttons["Retry"], in: app)
            assertClosed(app)
        }
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "Renamed Area exactly", routes: [
            Route(id: route, name: "Renamed Route exactly", pitches: [Pitch(id: pitch, name: "Renamed Pitch exactly")])
        ])])
    }

    func testOrderFailuresRetainWholeSequencesAndRetryAllSiblingKinds() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Area one")
        let otherArea = Area(id: create(app, kind: "area", name: "Area two"), name: "Area two")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Route one")
        let otherRoute = Route(id: create(app, kind: "route", name: "Route two"), name: "Route two")
        tap(app.buttons[route], in: app)
        let first = Pitch(id: create(app, kind: "pitch", name: "Pitch one"), name: "Pitch one")
        let second = Pitch(id: create(app, kind: "pitch", name: "Pitch two"), name: "Pitch two")
        for (kind, id) in [("Area", area), ("Route", route), ("Pitch", first.id)] {
            relaunch(app, failSave: true)
            if kind != "Area" { tap(app.buttons[area], in: app) }
            if kind == "Pitch" { tap(app.buttons[route], in: app) }
            beginOrder(app, kind: kind)
            move(app, id: id, direction: "down")
            tap(app.buttons["Done"], in: app)
            assertFailure(app)
            let row = app.collectionViews["textEditorForm"].descendants(matching: .any).matching(identifier: "order-\(recordID(id))").firstMatch
            reveal(app.collectionViews["textEditorForm"].buttons["move-up-\(recordID(id))"], in: app)
            XCTAssertTrue(row.exists)
            XCTAssertTrue(row.label.contains("2.") || row.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "2.")).firstMatch.exists)
            tap(app.buttons["Retry"], in: app)
            assertClosed(app)
        }
        relaunch(app)
        verify(app, areas: [otherArea, Area(id: area, name: "Area one", routes: [otherRoute,
            Route(id: route, name: "Route one", pitches: [second, first])
        ])])
    }

    func testPitchNoteAndDeletionFailuresRetainContentUntilSuccessfulRetry() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Fault area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Fault route")
        tap(app.buttons[route], in: app)
        let pitch = create(app, kind: "pitch", name: "Fault pitch")
        relaunch(app, failSave: true)
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        tap(app.buttons[pitch], in: app)
        editNotes(app, action: "Edit Notes", text: "Pitch retry exact\nSecond line.", save: false)
        tap(app.buttons["Finish Editing"], in: app)
        assertFailure(app)
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, "Pitch retry exact\nSecond line.")
        tap(app.buttons["Retry"], in: app)
        assertClosed(app)
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "Fault area", routes: [
            Route(id: route, name: "Fault route", pitches: [Pitch(id: pitch, name: "Fault pitch", notes: "Pitch retry exact\nSecond line.")])
        ])])
        for kind in ["Pitch", "Route", "Area"] {
            relaunch(app, failSave: true)
            tap(app.buttons[area], in: app)
            if kind != "Area" { tap(app.buttons[route], in: app) }
            if kind == "Pitch" { tap(app.buttons[pitch], in: app) }
            actions(app, kind: kind, action: "Delete")
            let context = app.staticTexts["textEditorContext"].label
            tap(app.buttons["Delete"], in: app)
            assertFailure(app)
            XCTAssertEqual(app.staticTexts["textEditorContext"].label, context)
            XCTAssertTrue(app.buttons["Delete"].exists)
            // Cancel after failed staging, then process-reopen to prove the acknowledged item survived.
            tap(app.buttons["Cancel"], in: app)
            assertClosed(app)
            relaunch(app, failSave: true)
            tap(app.buttons[area], in: app)
            if kind != "Area" { tap(app.buttons[route], in: app) }
            if kind == "Pitch" {
                tap(app.buttons[pitch], in: app)
                XCTAssertEqual(app.staticTexts["textPitchNotes"].label, "Pitch retry exact\nSecond line.")
            }
            actions(app, kind: kind, action: "Delete")
            tap(app.buttons["Delete"], in: app)
            assertFailure(app)
            tap(app.buttons["Retry"], in: app)
            assertClosed(app)
        }
        relaunch(app)
        XCTAssertTrue(app.staticTexts["No areas entered"].exists)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
    }

    func testGeneralNoteFailureRetryPersistsExactTextWithoutDuplicateHierarchy() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "General retry area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "General retry route")
        relaunch(app, failSave: true)
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        let text = "General failure retry\nExact retained second line."
        editNotes(app, action: "Edit General Notes", text: text, save: false)
        tap(app.buttons["Finish Editing"], in: app)
        assertFailure(app)
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, text)
        tap(app.buttons["Retry"], in: app)
        assertClosed(app)
        XCTAssertEqual(app.staticTexts["textGeneralNotes"].label, text)
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "General retry area", routes: [
            Route(id: route, name: "General retry route", notes: text)
        ])])
    }

    func testNativeAreaDragOrderRequiresDoneAndSurvivesProcessRelaunch() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let first = Area(id: create(app, kind: "area", name: "Drag first"), name: "Drag first")
        let second = Area(id: create(app, kind: "area", name: "Drag second"), name: "Drag second")
        beginOrder(app, kind: "Area")
        let form = app.collectionViews["textEditorForm"]
        let source = form.descendants(matching: .any).matching(identifier: "order-\(recordID(second.id))").firstMatch
        let destination = form.descendants(matching: .any).matching(identifier: "order-\(recordID(first.id))").firstMatch
        reveal(form.buttons["move-up-\(recordID(second.id))"], in: app)
        reveal(form.buttons["move-down-\(recordID(first.id))"], in: app)
        XCTAssertTrue(source.exists)
        XCTAssertTrue(destination.exists)
        let sourceCell = form.cells.containing(.button, identifier: "move-up-\(recordID(second.id))").firstMatch
        let destinationCell = form.cells.containing(.button, identifier: "move-down-\(recordID(first.id))").firstMatch
        XCTAssertTrue(sourceCell.exists)
        XCTAssertTrue(destinationCell.exists)
        let start = sourceCell.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5))
        let end = destinationCell.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.05))
        start.press(forDuration: 1, thenDragTo: end)
        assertState(app, "Unsaved changes")
        capture(app, "Native area drag before explicit Done")
        tap(app.buttons["Done"], in: app)
        assertClosed(app)
        relaunch(app)
        verify(app, areas: [second, first])
    }

    func testExplicitExamplesStaySeparateAndDoNotSeedTheEmptyNotebook() {
        let app = application()
        app.launch()
        assertLibrary(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
        tap(app.buttons["Open Examples"], in: app)
        XCTAssertTrue(app.buttons["Close Examples"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Example Notebook"].waitForExistence(timeout: 5))
        let exampleSource = library(app).descendants(matching: .any).matching(identifier: "sourceLabel").firstMatch
        reveal(exampleSource, in: app)
        XCTAssertEqual(exampleSource.label, "Example Notebook")
        XCTAssertEqual(rowIDs(app, kind: "area").count, 2)
        let example = create(app, kind: "area", name: "Example-only new area")
        tap(app.buttons["Close Examples"], in: app)
        assertLibrary(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
        let own = create(app, kind: "area", name: "My synthetic area")
        relaunch(app)
        XCTAssertEqual(rowIDs(app, kind: "area"), [own])
        tap(app.buttons["Open Examples"], in: app)
        XCTAssertTrue(app.buttons["Close Examples"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Example Notebook"].waitForExistence(timeout: 5))
        XCTAssertEqual(rowIDs(app, kind: "area").count, 3)
        XCTAssertTrue(app.buttons[example].exists)
        XCTAssertFalse(library(app).buttons[own].exists)
        tap(app.buttons["Close Examples"], in: app)
        XCTAssertEqual(rowIDs(app, kind: "area"), [own])
    }

    func testLargestTextLightReadingAndKeyboardEvidence() {
        checkReadingAndKeyboard(accessibility: true, dark: false)
    }

    func testDarkReadingAndKeyboardEvidence() {
        checkReadingAndKeyboard(accessibility: false, dark: true)
    }

    func testFiveHundredCharacterRouteAndPitchNamesKeepLargestTextEditorsAndNavigationReachable() {
        let app = application(accessibility: true)
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Boundary names")
        tap(app.buttons[area], in: app)
        let routeName = String(repeating: "Route name ", count: 45) + "12345"
        let pitchName = String(repeating: "Pitch name ", count: 45) + "12345"
        XCTAssertEqual(routeName.count, 500)
        XCTAssertEqual(pitchName.count, 500)
        let route = create(app, kind: "route", name: routeName)
        tap(app.buttons[route], in: app)
        let pitch = create(app, kind: "pitch", name: pitchName)
        let next = create(app, kind: "pitch", name: "Adjacent pitch")
        tap(app.buttons[pitch], in: app)
        XCTAssertTrue(app.buttons["Next Pitch"].isHittable)
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        let identity = app.staticTexts["textPitchIdentity"]
        reveal(identity, in: app)
        XCTAssertEqual(identity.label, pitchName)
        reveal(app.staticTexts["textPitchRouteIdentity"], in: app)
        XCTAssertEqual(app.staticTexts["textPitchRouteIdentity"].label, routeName)
        XCTAssertTrue(app.buttons["Next Pitch"].isHittable)
        tap(app.buttons["Edit Notes"], in: app)
        for label in ["Dismiss keyboard", "Finish Editing", "Cancel"] {
            reveal(app.buttons[label], in: app)
            XCTAssertTrue(app.buttons[label].isHittable)
        }
        reveal(app.staticTexts["textEditorContext"], in: app)
        XCTAssertEqual(app.staticTexts["textEditorContext"].label, "\(routeName) / \(pitchName)")
        capture(app, "AXXXL full 500-character route and pitch editor context")
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
        app.buttons["Next Pitch"].tap()
        XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, "Adjacent pitch")
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        app.buttons["Previous Pitch"].tap()
        XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, pitchName)
        back(app)
        XCTAssertTrue(app.buttons[next].exists)
        relaunch(app)
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        tap(app.buttons[pitch], in: app)
        XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, pitchName)
        XCTAssertTrue(app.buttons["Next Pitch"].isHittable)
    }

    func testDeletingMiddleThenLastPitchSelectsNextThenPreviousByIdentity() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Adjacent deletion")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Selection route")
        tap(app.buttons[route], in: app)
        let first = create(app, kind: "pitch", name: "First survivor")
        let middle = create(app, kind: "pitch", name: "Middle deleted")
        let last = create(app, kind: "pitch", name: "Last next")
        tap(app.buttons[last], in: app)
        editNotes(app, action: "Edit Notes", text: "Last UUID notes")
        back(app)
        tap(app.buttons[first], in: app)
        editNotes(app, action: "Edit Notes", text: "First UUID notes")
        app.buttons["Next Pitch"].tap()
        XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, "Middle deleted")
        actions(app, kind: "Pitch", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, "Last next")
        XCTAssertEqual(app.staticTexts["textPitchNotes"].label, "Last UUID notes")
        XCTAssertTrue(app.buttons["Previous Pitch"].isEnabled)
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        actions(app, kind: "Pitch", action: "Delete")
        tap(app.buttons["Delete"], in: app)
        assertClosed(app)
        XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, "First survivor")
        XCTAssertEqual(app.staticTexts["textPitchNotes"].label, "First UUID notes")
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        relaunch(app)
        tap(app.buttons[area], in: app)
        tap(app.buttons[route], in: app)
        XCTAssertEqual(rowIDs(app, kind: "pitch"), [first])
        XCTAssertFalse(app.buttons[middle].exists)
        XCTAssertFalse(app.buttons[last].exists)
        tap(app.buttons[first], in: app)
        XCTAssertEqual(app.staticTexts["textPitchNotes"].label, "First UUID notes")
    }

    func testDefaultAccessibilityAuditOfEmptyLibraryAndAreaCreation() throws {
        let app = application()
        app.launch()
        assertLibrary(app)
        capture(app, "Empty library default accessibility audit")
        if #available(iOS 17.0, *) { try app.performAccessibilityAudit() }
        beginName(app, action: "Add Area", name: "Accessible synthetic area")
        capture(app, "Area creation default accessibility audit")
        if #available(iOS 17.0, *) { try app.performAccessibilityAudit() }
        discard(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
    }

    private func checkReadingAndKeyboard(accessibility: Bool, dark: Bool) {
        let app = application(accessibility: accessibility, dark: dark)
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Synthetic long area name with wrapping and Cafe\u{301}")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Synthetic route with a long readable contextual name")
        tap(app.buttons[route], in: app)
        let first = create(app, kind: "pitch", name: "First long synthetic pitch name")
        let last = create(app, kind: "pitch", name: "Last pitch")
        let text = (1...16).map { "Synthetic line \($0): full exact text stays with its owner." }.joined(separator: "\n") + "\nFINAL VISIBLE LINE"
        editNotes(app, action: "Edit General Notes", text: text)
        let general = app.staticTexts["textGeneralNotes"]
        reveal(general, in: app)
        XCTAssertEqual(general.label, text)
        scrollToBottom(general, in: app)
        capture(app, "Full General bottom text \(dark ? "dark" : "largest light")")
        XCTAssertTrue(app.buttons["Jump to Pitches"].isHittable)
        app.buttons["Jump to Pitches"].tap()
        tap(app.buttons[first], in: app)
        editNotes(app, action: "Edit Notes", text: text)
        scrollToBottom(app.staticTexts["textPitchNotes"], in: app)
        XCTAssertTrue(app.buttons["Previous Pitch"].exists)
        XCTAssertTrue(app.buttons["Next Pitch"].isHittable)
        XCTAssertFalse(app.buttons["Previous Pitch"].isEnabled)
        XCTAssertGreaterThanOrEqual(app.buttons["Next Pitch"].frame.height, 44)
        capture(app, "Full pitch bottom with pinned navigation")
        app.buttons["Next Pitch"].tap()
        XCTAssertFalse(app.buttons["Next Pitch"].isEnabled)
        app.buttons["Previous Pitch"].tap()
        XCTAssertEqual(app.staticTexts["textPitchNotes"].label, text)
        tap(app.buttons["Edit Notes"], in: app)
        let editor = app.textViews["textNoteEditor"]
        tap(editor, in: app)
        editor.typeText("\nKeyboard-focused functional typing")
        XCTAssertTrue((editor.value as? String ?? "").contains("Keyboard-focused functional typing"))
        let renderedKeys = app.keyboards.keys.allElementsBoundByIndex.filter {
            $0.isHittable && !$0.frame.intersection(app.frame).isEmpty && $0.frame.width > 0 && $0.frame.height > 0
        }
        if renderedKeys.isEmpty {
            let limitation = XCTAttachment(string: "No software keyboard keys were rendered/hittable in the app viewport. Functional typing is asserted separately; software-keyboard-visible reachability is unverified. No simulator settings changed.")
            limitation.name = "Software keyboard rendering limitation"
            limitation.lifetime = .keepAlways
            add(limitation)
            capture(app, "Focused editor without rendered software keys")
        } else {
            XCTAssertTrue(app.buttons["Dismiss keyboard"].isHittable)
            capture(app, "Rendered software keyboard and reachable dismissal")
        }
        tap(app.buttons["Dismiss keyboard"], in: app)
        discard(app)
        XCTAssertEqual(app.staticTexts["textPitchNotes"].label, text)
        back(app)
        order(app, kind: "Pitch", ids: [first, last], names: ["First long synthetic pitch name", "Last pitch"])
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "Synthetic long area name with wrapping and Cafe\u{301}", routes: [
            Route(id: route, name: "Synthetic route with a long readable contextual name", notes: text, pitches: [
                Pitch(id: first, name: "First long synthetic pitch name", notes: text), Pitch(id: last, name: "Last pitch")
            ])
        ])])
    }

    private func scrollToBottom(_ note: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(note.waitForExistence(timeout: 3))
        for _ in 0..<24 {
            if note.exists && note.frame.maxY <= app.frame.maxY - 34 { break }
            let container = (app.collectionViews.allElementsBoundByIndex + app.scrollViews.allElementsBoundByIndex).last { $0.isHittable }
            guard let container else { break }
            container.swipeUp()
        }
        XCTAssertLessThanOrEqual(note.frame.maxY, app.frame.maxY - 34, "Final note line must be reachable")
    }
}
