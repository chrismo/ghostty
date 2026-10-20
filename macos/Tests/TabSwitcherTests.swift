//
//  TabSwitcherTests.swift
//  GhosttyTests
//

import Testing
@testable import Ghostty

struct FuzzyMatchTermTests {
    @Test func matchesDespiteLeadingEmoji() {
        #expect(FuzzyMatch.term("ghostty", in: "🔵 ghostty") != nil)
    }

    @Test func allowsGapsWithinATerm() {
        #expect(FuzzyMatch.term("ghsty", in: "🔵 ghostty") != nil)
    }

    @Test func keepsCharacterOrder() {
        #expect(FuzzyMatch.term("ytsohg", in: "ghostty") == nil)
    }

    @Test func isCaseInsensitive() {
        #expect(FuzzyMatch.term("GHO", in: "ghostty") != nil)
        #expect(FuzzyMatch.term("gho", in: "GHOSTTY") != nil)
    }

    @Test func ignoresDiacritics() {
        #expect(FuzzyMatch.term("cafe", in: "café") != nil)
    }

    @Test func highlightsTheMatchedCharacters() throws {
        let text = "🔵 ghostty"
        let match = try #require(FuzzyMatch.term("ghsty", in: text))
        #expect(match.indices.map { text[$0] } == ["g", "h", "s", "t", "y"])
    }

    /// The best alignment wins over the leftmost one: "log" should land on
    /// the word "logs" rather than scattered letters earlier in the text.
    @Test func prefersWordStartsAndRuns() throws {
        let text = "lots of garbage logs"
        let match = try #require(FuzzyMatch.term("log", in: text))
        let start = text.distance(from: text.startIndex, to: match.indices[0])
        #expect(start == 16)
    }

    @Test func contiguousOutranksGapped() throws {
        let run = try #require(FuzzyMatch.term("edit", in: "editor"))
        let gaps = try #require(FuzzyMatch.term("edit", in: "credit"))
        #expect(run.score > gaps.score)
    }
}

struct FuzzyMatchQueryTests {
    private let ghostty = ["proj-x — 🔵 ghostty", "~/dev/ghostty"]

    @Test func singleTerm() {
        #expect(FuzzyMatch.query("ghostty", fields: ghostty) != nil)
    }

    @Test func termsMatchAcrossFields() {
        #expect(FuzzyMatch.query("proj ghostty", fields: ghostty) != nil)
        #expect(FuzzyMatch.query("ghostty dev", fields: ghostty) != nil)
    }

    @Test func termOrderDoesNotMatter() {
        #expect(FuzzyMatch.query("ghostty proj", fields: ghostty) != nil)
    }

    @Test func everyTermIsRequired() {
        #expect(FuzzyMatch.query("proj nonexistent", fields: ghostty) == nil)
    }

    @Test func fuzzyTermsTogether() {
        #expect(FuzzyMatch.query("prd lg", fields: ["ops — production logs"]) != nil)
    }

    @Test func extraWhitespaceIsIgnored() {
        #expect(FuzzyMatch.query("  proj   ghostty ", fields: ghostty) != nil)
    }

    @Test func emptyQueryMatchesNothing() {
        #expect(FuzzyMatch.query("", fields: ghostty) == nil)
        #expect(FuzzyMatch.query("   ", fields: ghostty) == nil)
    }

    /// The earlier field wins a tie.
    @Test func highlightsFollowTheChosenField() throws {
        let match = try #require(FuzzyMatch.query("ghostty dev", fields: ghostty))
        let title = ghostty[0]
        let subtitle = ghostty[1]
        #expect(String(match.highlights[0].map { title[$0] }) == "ghostty")
        #expect(String(match.highlights[1].map { subtitle[$0] }) == "dev")
    }

    @Test func missingFieldsAreSkipped() {
        #expect(FuzzyMatch.query("vim", fields: ["vim", nil]) != nil)
        #expect(FuzzyMatch.query("dev", fields: ["vim", nil]) == nil)
    }
}

struct TabSwitcherFilterTests {
    private func option(_ title: String, _ subtitle: String? = nil) -> CommandOption {
        CommandOption(title: title, subtitle: subtitle) {}
    }

    @Test func dropsNonMatchesAndRanksByScore() {
        let credit = option("finance — credit")
        let editor = option("proj-x — 🔵 editor")
        let logs = option("ops — logs")

        let results = [credit, logs, editor].fuzzyFilteredAndSorted(query: "edit")
        #expect(results == [editor, credit])
    }

    @Test func tiesKeepTheirOriginalOrder() {
        let first = option("proj-x — shell")
        let second = option("proj-y — shell")

        #expect([first, second].fuzzyFilteredAndSorted(query: "shell") == [first, second])
        #expect([second, first].fuzzyFilteredAndSorted(query: "shell") == [second, first])
    }

    @Test func duplicateLabelsBothAppear() {
        let first = option("vim", "~/a")
        let second = option("vim", "~/a")

        #expect([first, second].fuzzyFilteredAndSorted(query: "vim") == [first, second])
    }

    @Test func emptyQueryKeepsEverything() {
        let first = option("b")
        let second = option("a")
        #expect([first, second].fuzzyFilteredAndSorted(query: "") == [first, second])
    }
}

struct TabSwitcherEntryTests {
    @Test func namedWindowPrefixesTheTitle() {
        let entry = TabSwitcherEntry(windowName: "proj-x", tabTitle: "🔵 editor", pwd: "~/dev/proj-x")
        #expect(entry.title == "proj-x — 🔵 editor")
        #expect(entry.subtitle == "~/dev/proj-x")
    }

    @Test func unnamedWindowShowsOnlyTheTabTitle() {
        let entry = TabSwitcherEntry(windowName: nil, tabTitle: "vim", pwd: nil)
        #expect(entry.title == "vim")
        #expect(entry.subtitle == nil)
    }

    @Test func emptyTitleIsUntitled() {
        let entry = TabSwitcherEntry(windowName: "ops", tabTitle: "", pwd: nil)
        #expect(entry.title == "ops — Untitled")
    }

    @Test func directoryInTheTitleIsNotRepeated() {
        let entry = TabSwitcherEntry(windowName: nil, tabTitle: "~/dev/infra", pwd: "~/dev/infra")
        #expect(entry.subtitle == nil)
    }
}
