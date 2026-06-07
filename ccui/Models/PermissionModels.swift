import Foundation

// MARK: - Permission Level

enum PermissionLevel: String, CaseIterable, Identifiable, Sendable {
    case worktree = "Worktree"
    case user = "User"

    var id: String { rawValue }

    func settingsPath(worktreePath: String) -> String {
        switch self {
        case .worktree:
            return (worktreePath as NSString)
                .appendingPathComponent(".claude/settings.local.json")
        case .user:
            // User permissions are in settings.json (not settings.local.json)
            return (NSHomeDirectory() as NSString)
                .appendingPathComponent(".claude/settings.json")
        }
    }
}

// MARK: - Permission Rule

struct PermissionRule: Identifiable, Hashable, Sendable {
    let id: UUID
    var value: String

    init(id: UUID = UUID(), value: String = "") {
        self.id = id
        self.value = value
    }

    var toolName: String {
        if let paren = value.firstIndex(of: "(") {
            return String(value[value.startIndex..<paren])
        }
        return value
    }

    var specifier: String? {
        guard let open = value.firstIndex(of: "("),
              let close = value.lastIndex(of: ")") else { return nil }
        let start = value.index(after: open)
        guard start < close else { return nil }
        return String(value[start..<close])
    }

    /// グロブパターンを含むツール名か（例: `"*"`, `mcp__github__*`）
    var isToolNameGlob: Bool {
        toolName.contains("*")
    }

    /// MCP ツール名の慣習（`mcp__<server>__<tool>`）に沿ったグロブか
    var isMCPToolNamePattern: Bool {
        toolName.hasPrefix("mcp__")
    }
}

// MARK: - Default Mode

enum PermissionDefaultMode: String, CaseIterable, Identifiable, Sendable {
    case `default` = "default"
    case acceptEdits = "acceptEdits"
    case plan = "plan"
    case auto = "auto"
    case bypassPermissions = "bypassPermissions"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: "Default"
        case .acceptEdits: "Accept Edits"
        case .plan: "Plan"
        case .auto: "Auto"
        case .bypassPermissions: "Bypass"
        }
    }
}

// MARK: - Permission List Kind

enum PermissionListKind: String, CaseIterable, Identifiable, Sendable {
    case allow = "Allow"
    case deny = "Deny"

    var id: String { rawValue }
}

// MARK: - Wildcard Matching

extension PermissionRule {
    static func wildcardMatches(pattern: String, input: String) -> Bool {
        let regexPattern = wildcardToRegex(pattern)
        guard let regex = try? NSRegularExpression(pattern: regexPattern) else { return false }
        return regex.firstMatch(in: input, range: NSRange(input.startIndex..., in: input)) != nil
    }

    private static func wildcardToRegex(_ pattern: String) -> String {
        var result = "^"
        var i = pattern.startIndex
        while i < pattern.endIndex {
            let c = pattern[i]
            if c == "*" {
                let next = pattern.index(after: i)
                if next < pattern.endIndex && pattern[next] == "*" {
                    result += ".*"
                    i = pattern.index(after: next)
                } else {
                    result += "[^/]*"
                    i = next
                }
            } else {
                result += NSRegularExpression.escapedPattern(for: String(c))
                i = pattern.index(after: i)
            }
        }
        result += "$"
        return result
    }

    /// ツール名位置のグロブパターンが、代表的なツール名候補にどうマッチするかのプレビュー
    static func toolNamePatternSamples(for rule: PermissionRule) -> [(String, Bool)] {
        guard rule.isToolNameGlob else { return [] }

        let candidates = [
            "Bash", "Read", "Write", "Edit", "Glob", "Grep",
            "WebFetch", "Task", "mcp__github__create_issue"
        ]
        return candidates.map { candidate in
            (candidate, wildcardMatches(pattern: rule.toolName, input: candidate))
        }
    }

    static func generateSamples(for rule: PermissionRule) -> [(String, Bool)] {
        guard let spec = rule.specifier else {
            return []
        }

        let candidates = generateCandidates(for: rule.toolName, specifier: spec)
        return candidates.map { candidate in
            (candidate, wildcardMatches(pattern: spec, input: candidate))
        }
    }

    private static func generateCandidates(for tool: String, specifier spec: String) -> [String] {
        var candidates: [String] = []

        switch tool {
        case "Bash":
            let base = spec.replacingOccurrences(of: ":*", with: "")
                .replacingOccurrences(of: "*", with: "")
                .trimmingCharacters(in: .whitespaces)
            if spec.hasSuffix(":*") {
                candidates.append(contentsOf: ["\(base):build", "\(base):test", "other-command"])
            } else if spec.hasSuffix(" *") {
                candidates.append(contentsOf: ["\(base) build", "\(base) test --verbose", "other-command"])
            } else if spec.contains("*") {
                candidates.append(contentsOf: ["\(base)something", "unrelated"])
            } else {
                candidates.append(contentsOf: [spec, "\(spec) extra"])
            }

        case "Read", "Edit", "Write":
            if spec.contains("**") {
                let prefix = spec.replacingOccurrences(of: "**", with: "")
                candidates.append(contentsOf: ["\(prefix)file.txt", "\(prefix)sub/deep/file.ts", "/other/path"])
            } else if spec.contains("*") {
                let prefix = spec.replacingOccurrences(of: "*", with: "")
                candidates.append(contentsOf: ["\(prefix)file.txt", "\(prefix)sub/file.txt"])
            } else {
                candidates.append(contentsOf: [spec, "\(spec).bak"])
            }

        case "WebFetch":
            if spec.hasPrefix("domain:") {
                let domain = String(spec.dropFirst("domain:".count))
                candidates.append(contentsOf: [domain, "other-site.com"])
            } else {
                candidates.append(spec)
            }

        default:
            if spec.contains("*") {
                let base = spec.replacingOccurrences(of: "*", with: "")
                candidates.append(contentsOf: ["\(base)example", "unrelated"])
            } else {
                candidates.append(spec)
            }
        }

        return candidates
    }
}
