import Testing
@testable import Ghostty

struct TabMarkRangeTests {
    @Test func withoutMarkOnlyTheCurrentTab() {
        #expect(TabMark.range(mark: nil, current: 3) == 3...3)
    }

    @Test func markLeftOfCurrent() {
        #expect(TabMark.range(mark: 1, current: 4) == 1...4)
    }

    @Test func markRightOfCurrent() {
        #expect(TabMark.range(mark: 5, current: 2) == 2...5)
    }

    @Test func markOnCurrent() {
        #expect(TabMark.range(mark: 2, current: 2) == 2...2)
    }
}

struct WindowNamesLabelTests {
    @Test func namedWindowUsesItsName() {
        #expect(WindowNames.label(name: "proj-x", selectedTitle: "vim", tabCount: 6) == "proj-x")
    }

    @Test func unnamedWindowUsesTitleAndCount() {
        #expect(WindowNames.label(name: nil, selectedTitle: "vim", tabCount: 6) == "vim (6 tabs)")
    }

    @Test func unnamedSingleTab() {
        #expect(WindowNames.label(name: nil, selectedTitle: "vim", tabCount: 1) == "vim (1 tab)")
    }

    @Test func unnamedWithoutTitle() {
        #expect(WindowNames.label(name: nil, selectedTitle: "", tabCount: 2) == "Untitled (2 tabs)")
    }

    @Test func emptyNameCountsAsUnnamed() {
        #expect(WindowNames.label(name: "", selectedTitle: "vim", tabCount: 2) == "vim (2 tabs)")
    }

    @Test func menuTitlePrefixesTheName() {
        #expect(WindowNames.menuTitle(name: "proj-x", tabTitle: "vim") == "proj-x — vim")
    }

    @Test func menuTitleWithoutName() {
        #expect(WindowNames.menuTitle(name: nil, tabTitle: "vim") == "vim")
    }
}
