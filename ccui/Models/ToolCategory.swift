import Foundation

/// ツール名から分類したカテゴリ。
///
/// hook ペイロードにはコスト・トークン使用量が含まれないため、`/usage` のような
/// カテゴリ別コスト内訳は再現できない。代わりに、取得可能なツール呼び出し回数を
/// 発生源（組み込み / サブエージェント / MCP サーバー）で分類し、活動量の内訳として示す。
nonisolated enum ToolCategory: Hashable, Sendable {
    case builtin
    case subagent
    case mcp(server: String)

    var displayName: String {
        switch self {
        case .builtin: "Built-in"
        case .subagent: "Subagent"
        case .mcp(let server): "MCP: \(server)"
        }
    }

    static func categorize(toolName: String) -> ToolCategory {
        if toolName.hasPrefix("mcp__") {
            let trimmed = toolName.dropFirst("mcp__".count)
            if let separator = trimmed.range(of: "__") {
                return .mcp(server: String(trimmed[..<separator.lowerBound]))
            }
            return .mcp(server: String(trimmed))
        }
        if toolName == "Task" {
            return .subagent
        }
        return .builtin
    }
}
