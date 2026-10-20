//
//  GhosttyTabSwitcherTests.swift
//  Ghostty
//

import XCTest

final class GhosttyTabSwitcherTests: GhosttyCustomConfigCase {
    override func setUp() async throws {
        try await super.setUp()
        try updateConfig(
            """
            keybind = super+k=toggle_tab_switcher
            keybind = super+alt+a=set_tab_title:alpha tab
            keybind = super+alt+m=set_tab_title:beta tab
            keybind = super+alt+c=set_tab_title:gamma tab
            """
        )
    }

    private func row(_ app: XCUIApplication, _ label: String) -> XCUIElementQuery {
        app.buttons.containing(NSPredicate(format: "label CONTAINS[c] %@", label))
    }

    /// Two tabs (the first split in two) in one window and one in another.
    @MainActor private func launchWithThreeTabs() throws -> XCUIApplication {
        let app = try ghosttyApplication()
        app.launch()
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 5), "New window should appear")

        // Each step types into the front window's pane and waits for its
        // result, so a dropped key fails where it happened. Split panes are
        // labelled "Left pane" and "Right pane", so they aren't matched.
        // With a Dvorak layout, ⌘⌥B was dropped every time; ⌘⌥M works.
        let pane = { app.windows.firstMatch.groups["Terminal pane"] }
        pane().typeKey("a", modifierFlags: [.command, .option])
        XCTAssertTrue(app.windows["alpha tab"].waitForExistence(timeout: 5), "First tab should be titled")
        pane().typeKey("d", modifierFlags: .command)
        XCTAssertTrue(app.groups["Right pane"].waitForExistence(timeout: 5), "Split should appear")
        app.typeKey("t", modifierFlags: .command)
        pane().typeKey("m", modifierFlags: [.command, .option])
        XCTAssertTrue(app.windows["beta tab"].waitForExistence(timeout: 5), "Second tab should be titled")
        pane().typeKey("n", modifierFlags: .command)
        XCTAssertTrue(app.windows.element(boundBy: 1).waitForExistence(timeout: 5), "Second window should appear")
        pane().typeKey("c", modifierFlags: [.command, .option])
        XCTAssertTrue(
            app.windows["gamma tab"].waitForExistence(timeout: 5), "Second window should be titled")
        return app
    }

    @MainActor func testListsEachTabOnceAcrossWindows() throws {
        let app = try launchWithThreeTabs()

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(row(app, "alpha tab").firstMatch.waitForExistence(timeout: 5), "Tab switcher should appear")
        XCTAssertEqual(row(app, "alpha tab").count, 1, "A tab with two splits is one row")
        XCTAssertEqual(row(app, "beta tab").count, 1, "Background tabs are listed")
        XCTAssertEqual(row(app, "gamma tab").count, 1, "The current tab is listed")
        XCTAssertEqual(row(app, "Focus:").count, 0, "No command palette entries")
    }

    @MainActor func testDismissing() throws {
        let app = try launchWithThreeTabs()
        let alpha = row(app, "alpha tab").firstMatch

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), "Tab switcher should appear")
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 5), "Escape should dismiss")
        XCTAssertEqual(app.windows.firstMatch.title, "gamma tab", "Escape should not switch")

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), "Tab switcher should appear")
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 5), "The binding again should dismiss")

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), "Tab switcher should appear")
        app.typeText("zzzz")
        XCTAssertTrue(app.staticTexts["No matches"].waitForExistence(timeout: 5), "No results should say so")
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 5), "Enter without results should dismiss")
        XCTAssertEqual(app.windows.firstMatch.title, "gamma tab", "Nothing to switch to")
    }

    @MainActor func testSwitchingByFuzzyQuery() throws {
        let app = try launchWithThreeTabs()
        let alpha = row(app, "alpha tab").firstMatch

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), "Tab switcher should appear")
        app.typeText("alph")
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 5), "Choosing should dismiss")
        XCTAssertEqual(app.windows.firstMatch.title, "alpha tab", "Should switch to the other window")

        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), "Tab switcher should appear")
        app.typeText("bta")
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 5), "Choosing should dismiss")
        XCTAssertEqual(app.windows.firstMatch.title, "beta tab", "Should switch tabs within the window")
    }

    @MainActor func testArrowKeysChooseARow() throws {
        let app = try launchWithThreeTabs()
        let alpha = row(app, "alpha tab").firstMatch

        // Rows are grouped by window in creation order: alpha, beta, gamma.
        app.typeKey("k", modifierFlags: .command)
        XCTAssertTrue(alpha.waitForExistence(timeout: 5), "Tab switcher should appear")
        app.typeKey(.downArrow, modifierFlags: [])
        app.typeKey("n", modifierFlags: .control)
        app.typeKey(.enter, modifierFlags: [])
        XCTAssertTrue(alpha.waitForNonExistence(timeout: 5), "Choosing should dismiss")
        XCTAssertEqual(app.windows.firstMatch.title, "beta tab", "Down then ctrl-n picks the second row")
    }
}
