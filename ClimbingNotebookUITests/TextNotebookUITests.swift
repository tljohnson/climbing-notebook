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

    private func reachableBounds(_ element: XCUIElement, in app: XCUIApplication) -> CGRect? {
        guard element.exists && element.isHittable else { return nil }
        let frame = element.frame
        let bounds = visibleBounds(element, in: app)
        if frame.intersection(bounds).height >= min(30, frame.height) { return bounds }
        if (element.label == "Close Examples" && app.frame.contains(frame))
            || app.navigationBars.allElementsBoundByIndex.contains(where: { $0.isHittable && $0.frame.contains(frame) }) {
            return frame
        }
        return nil
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

    @discardableResult
    private func reveal(_ element: XCUIElement, in app: XCUIApplication,
                        file: StaticString = #filePath, line: UInt = #line) -> CGRect {
        if !element.exists { _ = element.waitForExistence(timeout: 1) }
        if let bounds = reachableBounds(element, in: app) { return bounds }
        if element.exists, element.identifier.hasPrefix("text-pitch-"), app.buttons["Jump to Pitches"].isHittable {
            app.buttons["Jump to Pitches"].tap()
            if let bounds = reachableBounds(element, in: app) { return bounds }
        }
        // Validation rows can virtualize a field below the visible Form.
        let towardTop = element.exists && element.frame != .zero && element.frame.midY < app.frame.midY
        for down in [towardTop, !towardTop] {
            var previousRows: [String] = []
            for _ in 0..<64 {
                let list = foregroundList(app)
                guard let list else { break }
                let rows = list.cells.allElementsBoundByIndex.map { "\($0.label):\($0.frame)" }
                if !rows.isEmpty && rows == previousRows { break }
                previousRows = rows
                let bounds = list.frame.intersection(viewport(app)).insetBy(dx: 12, dy: 12)
                guard bounds.height > 40 else { break }
                // Stay inside the scrollable content, not on the inset List row's trailing boundary.
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: bounds.midX, dy: bounds.minY + bounds.height * (down ? 0.25 : 0.75)))
                let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(
                    dx: bounds.midX, dy: bounds.minY + bounds.height * (down ? 0.75 : 0.25)))
                start.press(forDuration: 0.05, thenDragTo: end)
                if let bounds = reachableBounds(element, in: app) { return bounds }
            }
        }
        capture(app, "Unreachable target \(element)")
        XCTFail("Control is not reachable: \(element)", file: file, line: line)
        return .null
    }

    private func tap(_ element: XCUIElement, in app: XCUIApplication) {
        let bounds = reveal(element, in: app)
        let closesExamples = element.label == "Close Examples"
        let frame = element.frame
        if bounds.contains(frame) || closesExamples
            || app.navigationBars.allElementsBoundByIndex.contains(where: { $0.isHittable && $0.frame.contains(frame) }) {
            element.tap()
        } else {
            let visible = frame.intersection(bounds)
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
        let field = nameField(app)
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        fill(field, with: name, in: app)
    }

    private func nameField(_ app: XCUIApplication) -> XCUIElement {
        // v2 captured index zero before the modal existed, permanently querying the covered root.
        XCTAssertTrue(app.collectionViews["textEditorForm"].waitForExistence(timeout: 5))
        return app.collectionViews["textEditorForm"]
            .descendants(matching: .any).matching(identifier: "textNameEditor").firstMatch
    }

    private func rowIDs(_ app: XCUIApplication, kind: String) -> [String] {
        (kind == "area" ? library(app).buttons : app.buttons).matching(NSPredicate(format: "identifier BEGINSWITH %@", "text-\(kind)-"))
            .allElementsBoundByIndex.map(\.identifier)
    }

    private func allRowIDs(_ app: XCUIApplication, kind: String,
                           file: StaticString = #filePath, line: UInt = #line) -> Set<String> {
        guard let list = foregroundList(app) else {
            XCTFail("Missing list while collecting all \(kind) IDs", file: file, line: line)
            return []
        }
        var directions = [true, false]
        if kind == "pitch", app.buttons["Jump to Pitches"].exists, app.buttons["Jump to Pitches"].isHittable {
            app.buttons["Jump to Pitches"].tap()
            let first = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND value BEGINSWITH %@",
                "text-pitch-", "Position 1 of ")).firstMatch
            if first.exists, first.isHittable,
               first.frame.intersection(list.frame.intersection(viewport(app))).height >= min(30, first.frame.height) {
                // A visible first pitch establishes the section start without traversing long General prose.
                directions = [false]
            }
        }
        var ids = Set<String>()
        for down in directions {
            var previous: String?
            var completed = false
            for _ in 0..<24 {
                let snapshot: XCUIElementSnapshot
                do {
                    snapshot = try list.snapshot()
                } catch {
                    XCTFail("Cannot snapshot \(kind) list: \(error)", file: file, line: line)
                    return ids
                }
                // One fresh UI snapshot supplies IDs and geometry from the same scroll position.
                var pending = Array(snapshot.children.reversed())
                var descendants: [XCUIElementSnapshot] = []
                while let child = pending.popLast() {
                    descendants.append(child)
                    pending.append(contentsOf: child.children.reversed())
                }
                let currentIDs = descendants.filter { $0.elementType == .button && $0.identifier.hasPrefix("text-\(kind)-") }
                    .map(\.identifier)
                ids.formUnion(currentIDs)
                let rows = currentIDs.joined(separator: "|") + "|"
                    + descendants.filter { $0.elementType == .cell }.map { "\($0.label):\($0.frame)" }.joined(separator: "|")
                let bars = descendants.filter { $0.elementType == .other && $0.label.hasPrefix("Vertical scroll bar") }
                if bars.contains(where: { $0.label == "Vertical scroll bar, 1 page"
                    || ($0.value as? String) == (down ? "0%" : "100%") }) {
                    completed = true
                    break
                }
                if rows == previous {
                    // An unchanged interior scrollbar is a blocked gesture, not an endpoint.
                    completed = bars.isEmpty
                    break
                }
                previous = rows
                if down { list.swipeDown() } else { list.swipeUp() }
            }
            XCTAssertTrue(completed, "Incomplete \(kind) ID traversal toward \(down ? "top" : "bottom") after 24 swipes",
                          file: file, line: line)
        }
        return ids
    }

    @discardableResult
    private func create(_ app: XCUIApplication, kind: String, name: String) -> String {
        let previous = allRowIDs(app, kind: kind)
        beginName(app, action: "Add \(kind.capitalized)", name: name)
        tap(app.buttons["Add"], in: app)
        assertClosed(app)
        if kind == "pitch" { tap(app.buttons["Jump to Pitches"], in: app) }
        reveal(addButton(app, kind: kind), in: app)
        let matches = (kind == "area" ? library(app).buttons : app.buttons).matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@ AND NOT (identifier IN %@)",
            "text-\(kind)-", name.isEmpty ? "Pitch" : name, Array(previous)))
        reveal(matches.firstMatch, in: app)
        let added = matches.allElementsBoundByIndex.map(\.identifier)
        XCTAssertEqual(added.count, 1)
        let id = added.first ?? "missing-\(kind)"
        XCTAssertNotNil(UUID(uuidString: String(id.dropFirst("text-\(kind)-".count))))
        return id
    }

    private func actions(_ app: XCUIApplication, kind: String, action: String) {
        tap(app.buttons["\(kind) Actions"], in: app)
        tapMenuItem(app, title: "\(action) \(kind)")
    }

    private func tapMenuItem(_ app: XCUIApplication, title: String) {
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        XCTAssertTrue(item.isHittable)
        // Called only after opening a native actions menu, never for page or Form content.
        let container = app.collectionViews.allElementsBoundByIndex.last { $0.buttons[title].exists }
        let bounds = (container?.frame ?? app.frame).intersection(app.frame)
        XCTAssertGreaterThanOrEqual(item.frame.intersection(bounds).height, min(30, item.frame.height))
        item.tap()
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
        let form = app.collectionViews["textEditorForm"]
        for (index, id) in ids.enumerated() {
            let anyRow = form.descendants(matching: .any).matching(identifier: "order-\(recordID(id))").firstMatch
            reveal(anyRow, in: app)
            XCTAssertTrue(anyRow.exists)
            let title = "\(index + 1). \(names[index])"
            let label = anyRow.label
            XCTAssertEqual(label, title)
            XCTAssertEqual(Array(label.utf8), Array(title.utf8))
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
        if kind != "Area" {
            tap(app.buttons[kind == "Route" ? "Area Actions" : "Route Actions"], in: app)
            tapMenuItem(app, title: "Edit \(kind) Order")
        } else {
            tap(app.buttons["Edit Area Order"], in: app)
        }
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
        XCTAssertEqual(allRowIDs(app, kind: "area"), Set(areas.map(\.id)))
        order(app, kind: "Area", ids: areas.map(\.id), names: areas.map(\.name))
        for area in areas {
            let areaRow = app.buttons[area.id]
            reveal(areaRow, in: app)
            XCTAssertTrue(areaRow.label.contains(area.name))
            XCTAssertTrue(areaRow.label.contains("\(area.routes.count) routes"))
            tap(areaRow, in: app)
            XCTAssertEqual(allRowIDs(app, kind: "route"), Set(area.routes.map(\.id)))
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
                let generalText = general.label
                XCTAssertEqual(generalText, route.notes.isEmpty ? "No General notes entered" : route.notes)
                XCTAssertEqual(Array(generalText.utf8), Array((route.notes.isEmpty ? "No General notes entered" : route.notes).utf8))
                XCTAssertFalse(app.textViews["textNoteEditor"].exists)
                if !route.pitches.isEmpty {
                    tap(app.buttons["Jump to Pitches"], in: app)
                    order(app, kind: "Pitch", ids: route.pitches.map(\.id), names: route.pitches.map(\.name))
                }
                XCTAssertEqual(allRowIDs(app, kind: "pitch"), Set(route.pitches.map(\.id)))
                if !route.pitches.isEmpty { tap(app.buttons["Jump to Pitches"], in: app) }
                for (index, pitch) in route.pitches.enumerated() {
                    let row = app.buttons[pitch.id]
                    reveal(row, in: app)
                    XCTAssertTrue(row.label.contains("\(index + 1). \(pitch.name)"), row.label)
                    tap(row, in: app)
                    let pitchText = app.staticTexts["textPitchNotes"].label
                    XCTAssertEqual(pitchText,
                                   pitch.notes.isEmpty ? "No notes entered" : pitch.notes)
                    XCTAssertEqual(Array(pitchText.utf8),
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
            let pitch = Pitch(id: create(app, kind: "pitch", name: "Pitch name \(number)"), name: "Pitch name \(number)")
            route.pitches.append(pitch)
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

    func testFiveDistinctPitchNotesSurviveProcessRelaunch() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Pitch notes area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Pitch notes route")
        tap(app.buttons[route], in: app)
        var pitches: [Pitch] = []
        for number in 1...5 {
            pitches.append(Pitch(id: create(app, kind: "pitch", name: "Pitch name \(number)"),
                                 name: "Pitch name \(number)",
                                 notes: "Distinct pitch \(number)\nExact synthetic notes \(number)."))
        }
        tap(app.buttons[pitches[0].id], in: app)
        for (index, pitch) in pitches.enumerated() {
            XCTAssertEqual(app.staticTexts["textPitchIdentity"].label, pitch.name)
            editNotes(app, action: "Edit Notes", text: pitch.notes)
            if index < pitches.count - 1 { tap(app.buttons["Next Pitch"], in: app) }
        }
        back(app)
        beginOrder(app, kind: "Pitch")
        move(app, id: pitches[4].id, direction: "up")
        move(app, id: pitches[1].id, direction: "up")
        tap(app.buttons["Done"], in: app)
        assertClosed(app)
        pitches.swapAt(3, 4)
        pitches.swapAt(0, 1)
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "Pitch notes area", routes: [
            Route(id: route, name: "Pitch notes route", pitches: pitches)
        ])])
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

    func testCanceledAndTerminatedGeneralNotesRetainAcknowledgedGraph() {
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
        let acknowledged = app.staticTexts["textGeneralNotes"].label
        XCTAssertEqual(acknowledged, route.notes)
        XCTAssertEqual(Array(acknowledged.utf8), Array(route.notes.utf8))
        editNotes(app, action: "Edit General Notes", text: "Terminated note", save: false)
        relaunch(app)
        verify(app, areas: [Area(id: areaID, name: "Retained area", routes: [route, other]), empty])
    }

    func testCanceledAndTerminatedPitchNotesRetainAcknowledgedGraph() {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Retained area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Retained route")
        tap(app.buttons[route], in: app)
        let pitch = Pitch(id: create(app, kind: "pitch", name: "Retained pitch"), name: "Retained pitch",
                          notes: "Prior acknowledged pitch\nCafe\u{301}, \u{96ea}, and trailing spaces  ")
        tap(app.buttons[pitch.id], in: app)
        editNotes(app, action: "Edit Notes", text: pitch.notes)
        editNotes(app, action: "Edit Notes", text: "Discard this pitch note", save: false)
        tap(app.buttons["Cancel"], in: app)
        app.buttons["Keep Editing"].tap()
        XCTAssertEqual(app.textViews["textNoteEditor"].value as? String, "Discard this pitch note")
        discard(app)
        XCTAssertEqual(Array(app.staticTexts["textPitchNotes"].label.utf8), Array(pitch.notes.utf8))
        editNotes(app, action: "Edit Notes", text: "Terminated pitch note", save: false)
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "Retained area", routes: [
            Route(id: route, name: "Retained route", pitches: [pitch])
        ])])
    }

    func testCanceledAndTerminatedAreaRenameRetainsAcknowledgedGraph() {
        checkCanceledAndTerminatedRename(kind: "Area")
    }

    func testCanceledAndTerminatedRouteRenameRetainsAcknowledgedGraph() {
        checkCanceledAndTerminatedRename(kind: "Route")
    }

    func testCanceledAndTerminatedPitchRenameRetainsAcknowledgedGraph() {
        checkCanceledAndTerminatedRename(kind: "Pitch")
    }

    private func checkCanceledAndTerminatedRename(kind: String) {
        let app = application()
        app.launch()
        assertLibrary(app)
        let area = create(app, kind: "area", name: "Retained area")
        tap(app.buttons[area], in: app)
        let route = create(app, kind: "route", name: "Retained route")
        tap(app.buttons[route], in: app)
        let pitch = Pitch(id: create(app, kind: "pitch", name: "Retained pitch"), name: "Retained pitch")
        if kind == "Area" { back(app) }
        if kind == "Pitch" { tap(app.buttons[pitch.id], in: app) }
        actions(app, kind: kind, action: "Rename")
        fill(nameField(app), with: "Unsaved rename", in: app)
        discard(app)
        actions(app, kind: kind, action: "Rename")
        XCTAssertEqual(nameField(app).value as? String, "Retained \(kind.lowercased())")
        fill(nameField(app), with: "Terminated rename", in: app)
        assertState(app, "Unsaved changes")
        relaunch(app)
        verify(app, areas: [Area(id: area, name: "Retained area", routes: [
            Route(id: route, name: "Retained route", pitches: [pitch])
        ])])
    }

    func testCanceledAndTerminatedAreaOrderRetainsAcknowledgedGraph() {
        checkCanceledAndTerminatedOrder(kind: "Area")
    }

    func testCanceledAndTerminatedRouteOrderRetainsAcknowledgedGraph() {
        checkCanceledAndTerminatedOrder(kind: "Route")
    }

    func testCanceledAndTerminatedPitchOrderRetainsAcknowledgedGraph() {
        checkCanceledAndTerminatedOrder(kind: "Pitch")
    }

    private func checkCanceledAndTerminatedOrder(kind: String) {
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
        if kind != "Pitch" { back(app) }
        if kind == "Area" { back(app) }
        let id = kind == "Area" ? areaID : (kind == "Route" ? route.id : first.id)
        beginOrder(app, kind: kind)
        move(app, id: id, direction: "down")
        discard(app)
        let ids = kind == "Area" ? [areaID, empty.id] : (kind == "Route" ? [route.id, other.id] : [first.id, last.id])
        let names = kind == "Area" ? ["Retained area", empty.name] : (kind == "Route" ? [route.name, other.name] : [first.name, last.name])
        order(app, kind: kind, ids: ids, names: names)
        beginOrder(app, kind: kind)
        move(app, id: id, direction: "down")
        let form = app.collectionViews["textEditorForm"]
        for (index, originalIndex) in ids.indices.reversed().enumerated() {
            let row = form.descendants(matching: .any).matching(identifier: "order-\(recordID(ids[originalIndex]))").firstMatch
            reveal(row, in: app)
            let expected = "\(index + 1). \(names[originalIndex])"
            let label = row.label
            XCTAssertEqual(label, expected)
            XCTAssertEqual(Array(label.utf8), Array(expected.utf8))
            XCTAssertEqual(row.value as? String, "Position \(index + 1) of \(ids.count)")
        }
        assertState(app, "Unsaved changes")
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
            reveal(app.staticTexts["textEditorContext"], in: app)
            let context = app.staticTexts["textEditorContext"].label
            tap(app.buttons["Delete"], in: app)
            assertFailure(app)
            reveal(app.staticTexts["textEditorContext"], in: app)
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

    func testDefaultAccessibilityAuditOfEmptyLibrary() throws {
        let app = application()
        app.launch()
        assertLibrary(app)
        capture(app, "Empty library default accessibility audit")
        if #available(iOS 17.0, *) { try app.performAccessibilityAudit() }
    }

    func testOrdinaryTouchActionsMenusAtDefaultTextDiagnostic() {
        checkOrdinaryTouchActionsMenus(accessibility: false)
    }

    func testOrdinaryTouchActionsMenusAtLargestTextDiagnostic() {
        checkOrdinaryTouchActionsMenus(accessibility: true)
    }

    func testRouteMenuThresholdAtStandardTextSizesDiagnostic() {
        checkRouteMenuThreshold(categories: ["XS", "S", "M", "L", "XL", "XXL", "XXXL"])
    }

    func testRouteMenuThresholdAtAccessibilityTextSizesDiagnostic() {
        checkRouteMenuThreshold(categories: ["AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"])
    }

    private func checkRouteMenuThreshold(categories: [String]) {
        let app = application()
        app.launchEnvironment["NOTEBOOK_TEST_MENU_SIZE"] = "1"
        let observedCategories = ["XS": "xSmall", "S": "small", "M": "medium", "L": "large", "XL": "xLarge", "XXL": "xxLarge", "XXXL": "xxxLarge",
                                  "AccessibilityM": "accessibility1", "AccessibilityL": "accessibility2", "AccessibilityXL": "accessibility3", "AccessibilityXXL": "accessibility4", "AccessibilityXXXL": "accessibility5"]
        var measurements: [String] = []
        defer {
            let attachment = XCTAttachment(string: measurements.joined(separator: "\n"))
            attachment.name = "Exact text categories and ordinary menu scroll counts"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        for category in categories {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"]
            app.launch()
            assertLibrary(app)
            tap(app.buttons["Open Examples"], in: app)
            tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                 "text-area-", "Example Granite")).firstMatch, in: app)
            tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                 "text-route-", "Paper Skyline")).firstMatch, in: app)
            let button = app.buttons["Route Actions"]
            XCTAssertEqual(button.value as? String, observedCategories[category], "Assert actual route category, not just requested launch argument")
            let frame = button.frame
            XCTAssertFalse(frame.isEmpty)
            XCTAssertTrue(app.navigationBars.allElementsBoundByIndex.contains { $0.frame.contains(frame) })
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
            measurements.append("\(category): toolbar \(frame); " + touchDiagnosticMenuItem(app, title: "Delete Route", category: category))
            XCTAssertTrue(app.collectionViews["textEditorForm"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.navigationBars["Delete Route"].exists)
            capture(app, "\(category) deletion editor reached")
            tap(app.buttons["Cancel"], in: app)
            assertClosed(app)
            app.terminate()
        }
    }

    @discardableResult
    private func touchDiagnosticMenuItem(_ app: XCUIApplication, title: String, category: String) -> String {
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 3))
        // Native menu collections can extend below their clipping ancestors. Require two
        // distinct menu items to exclude moving row wrappers, then intersect all ancestors.
        let companion: String
        switch title {
        case "Rename Area": companion = "Delete Area"
        case "Delete Area", "Edit Route Order": companion = "Rename Area"
        case "Rename Route": companion = "Delete Route"
        case "Delete Route", "Edit Pitch Order": companion = "Rename Route"
        case "Rename Pitch": companion = "Delete Pitch"
        default: companion = "Rename Pitch"
        }
        let containers = app.otherElements.containing(.button, identifier: title).allElementsBoundByIndex
            .filter { !$0.frame.isEmpty && $0.buttons[companion].exists }
        guard !containers.isEmpty else {
            XCTFail("No foreground native menu clipping ancestor for \(title)")
            return "missing menu ancestor"
        }
        func viewport() -> CGRect { containers.reduce(app.frame) { $0.intersection($1.frame) } }
        let initial = item.frame
        let initialClip = viewport()
        XCTAssertFalse(initialClip.isEmpty)
        capture(app, "\(category) \(title) before menu scrolling")
        var scrolls = 0
        while !viewport().contains(item.frame), scrolls < 4 {
            let clip = viewport()
            guard !clip.isEmpty else { XCTFail("Empty foreground menu viewport"); return "empty viewport" }
            app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: clip.midX, dy: clip.minY + clip.height * 0.8))
                .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: clip.midX, dy: clip.minY + clip.height * 0.25)))
            scrolls += 1
            capture(app, "\(category) \(title) after menu scroll \(scrolls)")
        }
        XCTAssertTrue(viewport().contains(item.frame), "Menu item must be inside foreground clipping bounds")
        let frame = item.frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        return "initial item \(initial), clipping ancestor \(initialClip), scrolls \(scrolls), final item \(frame)"
    }

    func testLargestTextRouteMenuScrollDiagnostic() {
        let app = application(accessibility: true)
        app.launch()
        assertLibrary(app)
        tap(app.buttons["Open Examples"], in: app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                             "text-area-", "Example Granite")).firstMatch, in: app)
        tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                             "text-route-", "Paper Skyline")).firstMatch, in: app)
        let frame = app.buttons["Route Actions"].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
        XCTAssertTrue(app.buttons["Delete Route"].waitForExistence(timeout: 3))
        let evidence = XCTAttachment(string: app.debugDescription)
        evidence.name = "AX5 native route menu before scrolling"
        evidence.lifetime = .keepAlways
        add(evidence)
        capture(app, "AX5 route menu before ordinary scrolling")
        let top = app.buttons.matching(identifier: "Add Pitch").allElementsBoundByIndex.last!.frame
        let lower = app.buttons["Edit Pitch Order"].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: lower.midX, dy: lower.midY))
            .press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: top.midX, dy: top.midY)))
        capture(app, "AX5 route menu after one ordinary scroll")
        let after = XCTAttachment(string: app.debugDescription)
        after.name = "AX5 native route menu after scrolling"
        after.lifetime = .keepAlways
        add(after)
        let item = app.buttons["Delete Route"].frame
        app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: item.midX, dy: item.midY)).tap()
        XCTAssertTrue(app.collectionViews["textEditorForm"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.navigationBars["Delete Route"].exists)
        capture(app, "AX5 route deletion editor reached after ordinary menu scroll")
        tap(app.buttons["Cancel"], in: app)
        assertClosed(app)
    }

    private func checkOrdinaryTouchActionsMenus(accessibility: Bool) {
        let app = application(accessibility: accessibility)
        app.launch()
        assertLibrary(app)
        tap(app.buttons["Open Examples"], in: app)
        let area = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                  "text-area-", "Example Granite")).firstMatch
        tap(area, in: app)
        for kind in ["Area", "Route", "Pitch"] {
            if kind == "Route" {
                tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                     "text-route-", "Paper Skyline")).firstMatch, in: app)
            }
            if kind == "Pitch" {
                tap(app.buttons["Jump to Pitches"], in: app)
                tap(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
                                                     "text-pitch-", "Opening slab")).firstMatch, in: app)
            }
            var titles = ["Rename \(kind)", "Delete \(kind)"]
            if kind != "Pitch" { titles.append(kind == "Area" ? "Edit Route Order" : "Edit Pitch Order") }
            for title in titles {
                var button = app.buttons["\(kind) Actions"]
                let bars = app.navigationBars.allElementsBoundByIndex
                if !button.exists || button.frame.isEmpty || !bars.contains(where: { $0.frame.contains(button.frame) }) {
                    let overflow = app.navigationBars.buttons["More"]
                    XCTAssertTrue(overflow.exists)
                    capture(app, "Native toolbar overflow before \(title)")
                    let frame = overflow.frame
                    XCTAssertFalse(frame.isEmpty)
                    XCTAssertTrue(bars.contains { $0.frame.contains(frame) })
                    XCTAssertTrue(app.frame.contains(frame))
                    app.coordinate(withNormalizedOffset: .zero)
                        .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
                    button = app.buttons["\(kind) Actions"]
                }
                XCTAssertTrue(button.waitForExistence(timeout: 3))
                let frame = button.frame
                XCTAssertFalse(frame.isEmpty)
                XCTAssertTrue(app.frame.contains(frame))
                if kind != "Pitch" || app.navigationBars.buttons["\(kind) Actions"].exists {
                    XCTAssertTrue(app.navigationBars.allElementsBoundByIndex.contains { $0.frame.contains(frame) })
                }
                let evidence = XCTAttachment(string: "\(kind) Actions: frame=\(frame), AX hittable=\(button.isHittable). Diagnostic visible-center coordinate tap only; not an accessibility pass.")
                evidence.name = "Ordinary-touch diagnostic \(title)"
                evidence.lifetime = .keepAlways
                add(evidence)
                capture(app, "Before ordinary-touch \(title)")
                // Deliberately separate from tap/actions: never substitute this for AX acceptance.
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: frame.midX, dy: frame.midY)).tap()
                let menuEvidence = XCTAttachment(string: touchDiagnosticMenuItem(app, title: title, category: accessibility ? "AX5" : "default"))
                menuEvidence.name = "Coordinate menu visibility \(title)"
                menuEvidence.lifetime = .keepAlways
                add(menuEvidence)
                XCTAssertTrue(app.collectionViews["textEditorForm"].waitForExistence(timeout: 3))
                XCTAssertTrue(app.navigationBars[title].exists)
                capture(app, "Ordinary-touch reached \(title)")
                tap(app.buttons["Cancel"], in: app)
                assertClosed(app)
            }
        }
    }

    func testDefaultAccessibilityAuditOfAreaCreationEditor() throws {
        let app = application()
        app.launch()
        assertLibrary(app)
        beginName(app, action: "Add Area", name: "Accessible synthetic area")
        capture(app, "Area creation default accessibility audit")
        if #available(iOS 17.0, *) { try app.performAccessibilityAudit() }
        discard(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
    }

    func testLibraryStatusColdLaunchDynamicTypeScalingEvidence() {
        let app = application()
        let categories = ["XS", "S", "M", "L", "XL", "XXL", "XXXL",
                          "AccessibilityM", "AccessibilityL", "AccessibilityXL", "AccessibilityXXL", "AccessibilityXXXL"]
        var measurements: [String] = []
        var smallestHeight: CGFloat = 0
        for category in categories {
            app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategory\(category)"]
            app.launch()
            assertLibrary(app)
            let status = app.staticTexts["textSaveStatus"]
            reveal(status, in: app)
            XCTAssertEqual(status.label, "Loaded from this device")
            measurements.append("\(category): \(status.frame)")
            if category == "XS" { smallestHeight = status.frame.height }
            if category == "AccessibilityXXXL" { XCTAssertGreaterThan(status.frame.height, smallestHeight) }
            capture(app, "Library status cold launch \(category)")
            app.terminate()
        }
        let attachment = XCTAttachment(string: measurements.joined(separator: "\n"))
        attachment.name = "Status AX frames across twelve cold-launch categories; live scaling remains separate"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testLiveSceneDynamicTypeStatusAndDirtyEditorDiagnostic() {
        let app = application()
        app.launchEnvironment["NOTEBOOK_TEST_LIVE_SIZE"] = "1"
        app.launchEnvironment["NOTEBOOK_TEST_LIGHT"] = "1"
        app.launch()
        assertLibrary(app)
        var heights: [Int] = []
        var measurements: [String] = []
        let screen = app.screenshot().image
        let scale = CGFloat(screen.cgImage!.height) / app.frame.height
        defer {
            let evidence = XCTAttachment(string: measurements.joined(separator: "\n"))
            evidence.name = "Live category frames, backing-pixel heights and retained draft identity"
            evidence.lifetime = .keepAlways
            add(evidence)
        }
        for category in ["xSmall", "large", "accessibility5", "large"] {
            app.buttons["cycleTestTextSize"].tap()
            let observed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", category),
                                                    object: app.buttons["cycleTestTextSize"])
            XCTAssertEqual(XCTWaiter.wait(for: [observed], timeout: 3), .completed)
            let status = app.staticTexts["textSaveStatus"]
            reveal(status, in: app)
            XCTAssertEqual(status.label, "Loaded from this device")
            heights.append(Int((status.frame.height * scale).rounded()))
            measurements.append("Library observed \(category): \(status.frame), backing-pixel height \(heights.last!)")
            capture(app, "Live same-library status \(category)")
        }
        XCTAssertGreaterThan(heights[1], heights[0])
        XCTAssertGreaterThan(heights[2], heights[1])
        XCTAssertEqual(heights[1], heights[3])
        beginName(app, action: "Add Area", name: "Live draft Cafe\u{301}  ")
        let draftIdentity = (app.buttons["cycleEditorTestTextSize"].value as? String ?? "")
            .split(separator: "|", maxSplits: 1).dropFirst().joined(separator: "|")
        XCTAssertFalse(draftIdentity.isEmpty)
        heights = []
        for category in ["xSmall", "large", "accessibility5", "large"] {
            let editorControl = app.buttons["cycleEditorTestTextSize"]
            editorControl.tap()
            let observed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", category + "|" + draftIdentity),
                                                    object: editorControl)
            XCTAssertEqual(XCTWaiter.wait(for: [observed], timeout: 3), .completed)
            XCTAssertEqual(Array((nameField(app).value as? String ?? "").utf8), Array("Live draft Cafe\u{301}  ".utf8))
            XCTAssertEqual(editorControl.value as? String, category + "|" + draftIdentity)
            assertState(app, "Unsaved changes")
            let status = app.staticTexts["textEditorSaveState"]
            reveal(status, in: app)
            heights.append(Int((status.frame.height * scale).rounded()))
            measurements.append("Editor observed \(category): \(status.frame), backing-pixel height \(heights.last!), identity \(draftIdentity)")
            XCTAssertTrue(app.buttons["Cancel"].isHittable)
            XCTAssertTrue(app.buttons["Add"].isHittable)
            capture(app, "Live same-dirty-editor \(category)")
        }
        XCTAssertGreaterThan(heights[1], heights[0])
        XCTAssertGreaterThan(heights[2], heights[1])
        XCTAssertEqual(heights[1], heights[3])
        discard(app)
        XCTAssertTrue(rowIDs(app, kind: "area").isEmpty)
    }

    func testExplicitLightCreationEditorUnrestrictedAuditDiagnostic() throws {
        try checkCreationEditorAppearanceAudit(dark: false)
    }

    func testExplicitDarkCreationEditorUnrestrictedAuditDiagnostic() throws {
        try checkCreationEditorAppearanceAudit(dark: true)
    }

    private func checkCreationEditorAppearanceAudit(dark: Bool) throws {
        let app = application(dark: dark)
        if !dark { app.launchEnvironment["NOTEBOOK_TEST_LIGHT"] = "1" }
        app.launch()
        assertLibrary(app)
        beginName(app, action: "Add Area", name: "Appearance audit draft")
        capture(app, "Explicit \(dark ? "dark" : "light") editor before unrestricted audit")
        defer { capture(app, "Explicit \(dark ? "dark" : "light") editor after unrestricted audit") }
        try app.performAccessibilityAudit()
        discard(app)
    }

    private func checkReadingAndKeyboard(accessibility: Bool, dark: Bool) {
        let app = application(accessibility: accessibility, dark: dark)
        app.launch()
        assertLibrary(app)
        reveal(app.staticTexts["textSaveStatus"], in: app)
        capture(app, "Library status at \(accessibility ? "AXXXL" : "ordinary") text size")
        let statusEvidence = XCTAttachment(string: "Rendered status: \(app.staticTexts["textSaveStatus"].label); frame: \(app.staticTexts["textSaveStatus"].frame)")
        statusEvidence.name = "Library status Dynamic Type frame"
        statusEvidence.lifetime = .keepAlways
        add(statusEvidence)
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
            let frame = $0.frame
            return frame.origin.x.isFinite && frame.origin.y.isFinite
                && frame.width.isFinite && frame.height.isFinite
                && frame.width > 0 && frame.height > 0
                && !frame.intersection(app.frame).isEmpty && $0.isHittable
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
