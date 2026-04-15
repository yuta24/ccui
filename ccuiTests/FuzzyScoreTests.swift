import Testing
@testable import ccui

struct FuzzyScoreTests {

    // MARK: - No Match

    @Test func noMatchReturnsNil() {
        let result = QuickOpenStore.fuzzyScore(query: "xyz", candidate: "abc")
        #expect(result == nil)
    }

    @Test func emptyQueryMatchesAnything() {
        let result = QuickOpenStore.fuzzyScore(query: "", candidate: "anything")
        #expect(result != nil)
        #expect(result?.matchedIndices.isEmpty == true)
    }

    // MARK: - Exact Match

    @Test func exactMatchScoresHighly() {
        let result = QuickOpenStore.fuzzyScore(query: "file", candidate: "file")
        #expect(result != nil)
        #expect(result!.score > 0)
        #expect(result!.matchedIndices.count == 4)
    }

    // MARK: - Start Bonus

    @Test func startBonusApplied() {
        let startResult = QuickOpenStore.fuzzyScore(query: "f", candidate: "file.swift")
        let midResult = QuickOpenStore.fuzzyScore(query: "s", candidate: "file.swift")
        #expect(startResult != nil)
        #expect(midResult != nil)
        // Start match gets +15, while mid-string gets +5 or +8
        #expect(startResult!.score > midResult!.score)
    }

    // MARK: - Consecutive Bonus

    @Test func consecutiveMatchBonus() {
        // "fi" consecutive at start should score higher than "f" alone at start
        let consecutive = QuickOpenStore.fuzzyScore(query: "fi", candidate: "file")
        let single = QuickOpenStore.fuzzyScore(query: "f", candidate: "file")
        #expect(consecutive != nil)
        #expect(single != nil)
        #expect(consecutive!.score > single!.score)
    }

    // MARK: - Separator Bonus

    @Test func separatorBoundaryBonus() {
        // 's' after '.' (separator boundary) should score higher than 'w' mid-word
        let boundary = QuickOpenStore.fuzzyScore(query: "s", candidate: "file.swift")
        let midWord = QuickOpenStore.fuzzyScore(query: "w", candidate: "file.swift")
        #expect(boundary != nil)
        #expect(midWord != nil)
        #expect(boundary!.score > midWord!.score)
    }

    @Test func slashBoundaryBonus() {
        // 'b' after '/' (separator boundary) should score higher than 'b' mid-word
        let boundary = QuickOpenStore.fuzzyScore(query: "b", candidate: "a/b.swift")
        let midWord = QuickOpenStore.fuzzyScore(query: "b", candidate: "abc.swift")
        #expect(boundary != nil)
        #expect(midWord != nil)
        #expect(boundary!.score >= midWord!.score)
    }

    // MARK: - Length Penalty

    @Test func longCandidatePenalized() {
        let short = QuickOpenStore.fuzzyScore(query: "f", candidate: "file")
        let long = QuickOpenStore.fuzzyScore(query: "f", candidate: "a_very_long_filename_here.swift")
        #expect(short != nil)
        #expect(long != nil)
        #expect(short!.score > long!.score)
    }

    // MARK: - Case Insensitive

    @Test func caseInsensitiveMatching() {
        let result = QuickOpenStore.fuzzyScore(query: "file", candidate: "FILE.swift")
        #expect(result != nil)
        #expect(result!.matchedIndices.count == 4)
    }

    // MARK: - Realistic Filenames

    @Test func realisticFilenameMatch() {
        let result = QuickOpenStore.fuzzyScore(query: "dp", candidate: "DiffParser.swift")
        #expect(result != nil)
    }

    @Test func partialQueryInLongPath() {
        let result = QuickOpenStore.fuzzyScore(query: "qos", candidate: "QuickOpenStore.swift")
        #expect(result != nil)
    }
}
