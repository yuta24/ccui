import Testing
@testable import ccui

struct ToolCategoryTests {

    @Test func builtinToolsAreCategorizedAsBuiltin() {
        #expect(ToolCategory.categorize(toolName: "Bash") == .builtin)
        #expect(ToolCategory.categorize(toolName: "Read") == .builtin)
        #expect(ToolCategory.categorize(toolName: "WebFetch") == .builtin)
    }

    @Test func taskIsCategorizedAsSubagent() {
        #expect(ToolCategory.categorize(toolName: "Task") == .subagent)
    }

    @Test func mcpToolIsCategorizedByServerName() {
        #expect(ToolCategory.categorize(toolName: "mcp__github__create_issue") == .mcp(server: "github"))
        #expect(ToolCategory.categorize(toolName: "mcp__playwright__navigate") == .mcp(server: "playwright"))
    }

    @Test func mcpToolWithoutToolNameFallsBackToWholeRemainder() {
        #expect(ToolCategory.categorize(toolName: "mcp__github") == .mcp(server: "github"))
    }

    @Test func displayNameIncludesServerForMCP() {
        #expect(ToolCategory.mcp(server: "github").displayName == "MCP: github")
        #expect(ToolCategory.builtin.displayName == "Built-in")
        #expect(ToolCategory.subagent.displayName == "Subagent")
    }
}
