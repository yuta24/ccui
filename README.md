# ccui

A native macOS IDE for the [Claude Code](https://claude.com/claude-code) harness — visualize sessions, analyze agent behavior, and edit hooks/permissions in one app.

ccui is a SwiftUI application that wraps the `claude` CLI with repository and git-worktree management, embedded terminals, code/diff viewers, and a real-time view of every Claude Code session it observes.

> **Status:** Pre-release / early. Public API and on-disk formats may change between minor versions. Not affiliated with Anthropic.

## Features

### Workspace
- Git repository and worktree management (add/remove/switch)
- Bottom terminal panel with persistent shell sessions per worktree
- Dedicated agent terminal that launches `claude` against the selected worktree
- File tree with `.gitignore` awareness and live updates
- Quick Open palette (⌘P) and full-text content search (⌘⇧F)
- Inline code viewer and side-by-side diff viewer
- Optional WebView split panel

### Claude Code observability
- Installs Claude Code hooks into each worktree's `.claude/settings.local.json` and streams events over a local Unix domain socket (`/tmp/ccui.sock`)
- Sidebar lists active and historical sessions; selecting one opens an event timeline
- Native macOS notifications when Claude requests permission
- Side-by-side session comparison
- Auto-detected user interventions and session outcomes

### Analytics
- Autonomy score, intervention frequency, session duration, tool distribution
- Aggregated per repository

### Configuration
- Hooks editor — view/edit Claude Code hooks per scope (user / project / local), with a built-in test runner
- Permissions editor — manage allow/deny rules
- CLAUDE.md viewer

## Requirements

- macOS 26.2 or later
- Xcode 26.2 or later (macOS 26.2 SDK, Swift 5 with `MainActor` default isolation)
- [`claude`](https://claude.com/claude-code) CLI on your `PATH` for the agent terminal
- Optional: [`xcbeautify`](https://github.com/cpisciotta/xcbeautify) for readable build output (`brew install xcbeautify`)

## Build

```bash
scripts/build.sh                 # Debug build
scripts/build.sh ccui Release    # Release build
scripts/test.sh                  # Run unit tests
```

The built `.app` is written to `.build/Build/Products/<Configuration>/ccui.app`. You can also open `ccui.xcodeproj` in Xcode and run normally.

## Architecture

| Layer | Responsibility |
|-------|----------------|
| `ccui/Models/` | Value types (`Identifiable`, `Hashable`, `Sendable`) — repositories, worktrees, Claude events, sessions, hooks, permissions |
| `ccui/Store/` | `@Observable @MainActor` state containers, injected via `.environment(...)` |
| `ccui/Services/` | Side-effect adapters — UDS listener, hooks installer, file watchers, notifications |
| `ccui/Views/` | SwiftUI surfaces (sidebar, detail, analytics, hooks, permissions, etc.) |
| `ccui/AppKit/` | `NSWindow` / `NSSplitViewController` scaffolding |
| `ccui/Persistence/` | Protocol-based JSON persistence |

Swift 6 concurrency is enabled (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`). The Xcode project uses `PBXFileSystemSynchronizedRootGroup`, so new files under `ccui/` are auto-discovered without `pbxproj` edits.

## Privacy

ccui itself makes no outbound network calls. Claude Code hook payloads travel only over a local Unix domain socket. Hooks are installed only into worktrees you explicitly add to ccui — and the underlying `claude` CLI follows its own data policies.

## License

[MIT](LICENSE)
