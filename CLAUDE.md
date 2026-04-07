# ccui

macOS native SwiftUI application for repository browsing with integrated terminal, code viewer, and diff viewer.

## Build

```bash
scripts/build.sh              # Debug build (default)
scripts/build.sh ccui Release  # Release build
```

Output is formatted with `xcbeautify`. Exit code is non-zero on failure.

## Architecture

- **Models/**: Value types (`Identifiable`, `Hashable`, `Sendable`)
- **Store/**: `@Observable @MainActor` state management classes
- **Views/**: SwiftUI views
- **Persistence/**: Protocol-based persistence (JSON file)

## Conventions

- Stores use `@Observable` + `@MainActor`, injected via `.environment()`
- Swift 6 concurrency: `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` — new files are auto-discovered, no pbxproj edits needed
