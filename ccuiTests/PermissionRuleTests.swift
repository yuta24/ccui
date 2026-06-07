import Testing
@testable import ccui

struct PermissionRuleTests {

    // MARK: - wildcardMatches

    @Test func exactMatch() {
        #expect(PermissionRule.wildcardMatches(pattern: "npm test", input: "npm test") == true)
    }

    @Test func exactMismatch() {
        #expect(PermissionRule.wildcardMatches(pattern: "npm test", input: "npm build") == false)
    }

    @Test func singleWildcardMatchesWithinSegment() {
        #expect(PermissionRule.wildcardMatches(pattern: "npm *", input: "npm test") == true)
        // * maps to [^/]*, which matches spaces but not slashes
        #expect(PermissionRule.wildcardMatches(pattern: "npm *", input: "npm build --verbose") == true)
    }

    @Test func singleWildcardDoesNotCrossSlash() {
        #expect(PermissionRule.wildcardMatches(pattern: "/src/*", input: "/src/file.txt") == true)
        #expect(PermissionRule.wildcardMatches(pattern: "/src/*", input: "/src/sub/file.txt") == false)
    }

    @Test func doubleWildcardMatchesAnything() {
        #expect(PermissionRule.wildcardMatches(pattern: "/src/**", input: "/src/file.txt") == true)
        #expect(PermissionRule.wildcardMatches(pattern: "/src/**", input: "/src/sub/deep/file.txt") == true)
    }

    @Test func wildcardAtEnd() {
        #expect(PermissionRule.wildcardMatches(pattern: "git:*", input: "git:push") == true)
        #expect(PermissionRule.wildcardMatches(pattern: "git:*", input: "git:pull") == true)
    }

    @Test func noWildcardExactOnly() {
        #expect(PermissionRule.wildcardMatches(pattern: "exact", input: "exact") == true)
        #expect(PermissionRule.wildcardMatches(pattern: "exact", input: "exact extra") == false)
    }

    @Test func specialCharactersEscaped() {
        #expect(PermissionRule.wildcardMatches(pattern: "file.swift", input: "file.swift") == true)
        #expect(PermissionRule.wildcardMatches(pattern: "file.swift", input: "fileXswift") == false)
    }

    // MARK: - toolName / specifier

    @Test func toolNameWithoutSpecifier() {
        let rule = PermissionRule(value: "Bash")
        #expect(rule.toolName == "Bash")
        #expect(rule.specifier == nil)
    }

    @Test func toolNameWithSpecifier() {
        let rule = PermissionRule(value: "Bash(npm *)")
        #expect(rule.toolName == "Bash")
        #expect(rule.specifier == "npm *")
    }

    @Test func toolNameWithPathSpecifier() {
        let rule = PermissionRule(value: "Read(/src/**)")
        #expect(rule.toolName == "Read")
        #expect(rule.specifier == "/src/**")
    }

    @Test func emptySpecifier() {
        let rule = PermissionRule(value: "Bash()")
        #expect(rule.toolName == "Bash")
        #expect(rule.specifier == nil) // start < close fails when empty
    }

    // MARK: - isToolNameGlob / isMCPToolNamePattern

    @Test func denyAllToolsGlob() {
        let rule = PermissionRule(value: "*")
        #expect(rule.toolName == "*")
        #expect(rule.isToolNameGlob == true)
        #expect(rule.isMCPToolNamePattern == false)
    }

    @Test func mcpToolNameGlobIsRecognized() {
        let rule = PermissionRule(value: "mcp__github__*")
        #expect(rule.isToolNameGlob == true)
        #expect(rule.isMCPToolNamePattern == true)
    }

    @Test func plainToolNameIsNotGlob() {
        let rule = PermissionRule(value: "Bash(npm *)")
        #expect(rule.isToolNameGlob == false)
    }

    // MARK: - toolNamePatternSamples

    @Test func toolNamePatternSamplesForWildcardMatchesAllCandidates() {
        let rule = PermissionRule(value: "*")
        let samples = PermissionRule.toolNamePatternSamples(for: rule)
        #expect(!samples.isEmpty)
        #expect(samples.allSatisfy { $0.1 == true })
    }

    @Test func toolNamePatternSamplesForMCPGlobOnlyMatchesMCPTools() {
        let rule = PermissionRule(value: "mcp__github__*")
        let samples = PermissionRule.toolNamePatternSamples(for: rule)
        #expect(samples.contains { $0.0 == "mcp__github__create_issue" && $0.1 == true })
        #expect(samples.contains { $0.0 == "Bash" && $0.1 == false })
    }

    @Test func toolNamePatternSamplesEmptyWithoutGlob() {
        let rule = PermissionRule(value: "Bash")
        #expect(PermissionRule.toolNamePatternSamples(for: rule).isEmpty)
    }

    // MARK: - generateSamples

    @Test func generateSamplesForBashWithColonWildcard() {
        let rule = PermissionRule(value: "Bash(npm:*)")
        let samples = PermissionRule.generateSamples(for: rule)
        #expect(!samples.isEmpty)
        // "npm:build" should match
        #expect(samples.contains { $0.0 == "npm:build" && $0.1 == true })
        // "other-command" should not match
        #expect(samples.contains { $0.0 == "other-command" && $0.1 == false })
    }

    @Test func generateSamplesForReadWithDoubleWildcard() {
        let rule = PermissionRule(value: "Read(/src/**)")
        let samples = PermissionRule.generateSamples(for: rule)
        #expect(!samples.isEmpty)
        // Deep path should match with **
        #expect(samples.contains { $0.1 == true })
        // "/other/path" should not match
        #expect(samples.contains { $0.0 == "/other/path" && $0.1 == false })
    }

    @Test func generateSamplesNoSpecifierReturnsEmpty() {
        let rule = PermissionRule(value: "Bash")
        let samples = PermissionRule.generateSamples(for: rule)
        #expect(samples.isEmpty)
    }
}
