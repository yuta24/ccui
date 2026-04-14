import SwiftUI

struct HooksEntryEditorView: View {
    let worktreePath: String
    @Bindable var store: HooksStore
    @Bindable var testRunner: HookTestRunner

    enum Tab: String, CaseIterable {
        case editor = "Editor"
        case fireLog = "Fire Log"
    }

    @State private var selectedTab: Tab = .editor

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            tabPicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            switch selectedTab {
            case .editor:
                editorContent
            case .fireLog:
                fireLogContent
            }
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 4) {
            ForEach(Tab.allCases, id: \.rawValue) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
                        .font(.uiCaption)
                        .foregroundStyle(selectedTab == tab ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(selectedTab == tab ? Color.accentSubtle : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                store.addEntry()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Add")
                        .font(.uiCaption)
                }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Editor

    private var editorContent: some View {
        let entries = store.currentEntries
        return Group {
            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(entries) { entry in
                            entryRow(entry)
                            Rectangle()
                                .fill(Color.borderSubtle)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: HookEntry) -> some View {
        let isSelected = store.selectedEntryID == entry.id
        return VStack(alignment: .leading, spacing: 0) {
            // Header row
            Button {
                if isSelected {
                    store.selectedEntryID = nil
                } else {
                    store.selectedEntryID = entry.id
                    testRunner.resetState()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isSelected ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 10)

                    if entry.isManagedByCCUI {
                        Text("ccui managed")
                            .font(.uiCaption)
                            .foregroundStyle(Color.textTertiary)
                            .italic()
                    } else {
                        Text(entry.matcher.isEmpty ? "(all tools)" : entry.matcher)
                            .font(.uiCaption)
                            .foregroundStyle(Color.textPrimary)
                    }

                    Spacer()

                    Text("\(entry.hooks.count) cmd")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.textTertiary)

                    if !entry.isManagedByCCUI {
                        Button {
                            store.removeEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 10))
                                .foregroundStyle(Color.textTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .background(isSelected ? Color.surfaceHover : Color.clear)
            }
            .buttonStyle(.plain)

            // Expanded detail
            if isSelected {
                entryDetail(entry)
            }
        }
    }

    private func entryDetail(_ entry: HookEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Matcher
            if !entry.isManagedByCCUI {
                HStack(spacing: 6) {
                    Text("Matcher")
                        .font(.uiCaption)
                        .foregroundStyle(Color.textTertiary)
                        .frame(width: 50, alignment: .trailing)
                    TextField("(all tools)", text: Binding(
                        get: { entry.matcher },
                        set: { store.updateMatcher(entry, matcher: $0) }
                    ))
                    .font(.uiCaptionMono)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.surfaceBase)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(Color.borderDefault, lineWidth: 1)
                    )
                }
            }

            // Commands
            ForEach(entry.hooks) { cmd in
                commandRow(cmd, entry: entry)
            }

            if !entry.isManagedByCCUI {
                Button {
                    store.addCommand(to: entry)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Add Command")
                            .font(.uiCaption)
                    }
                    .foregroundStyle(Color.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, 56)
            }

            // Test runner
            testRunnerSection(entry)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.surfaceBase)
    }

    private func commandRow(_ cmd: HookCommand, entry: HookEntry) -> some View {
        HStack(spacing: 6) {
            Text("cmd")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .frame(width: 50, alignment: .trailing)

            if entry.isManagedByCCUI {
                Text(cmd.command)
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            } else {
                TextField("command", text: Binding(
                    get: { cmd.command },
                    set: { store.updateCommand(cmd, newValue: $0, in: entry) }
                ))
                .font(.uiCaptionMono)
                .textFieldStyle(.plain)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.surfaceBase)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )
            }

            if !entry.isManagedByCCUI && entry.hooks.count > 1 {
                Button {
                    store.removeCommand(cmd, from: entry)
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Test Runner

    private func testRunnerSection(_ entry: HookEntry) -> some View {
        let entryState = testRunner.stateFor(entryID: entry.id)
        return VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                Text("Dry Run")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)

                Spacer()

                switch entryState {
                case .idle:
                    Button {
                        Task {
                            await testRunner.runAll(commands: entry.hooks.map(\.command), entryID: entry.id, eventName: store.selectedEventName, worktreePath: worktreePath)
                        }
                    } label: {
                        Text("Run")
                            .font(.uiCaption)
                            .foregroundStyle(Color.accent)
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.hooks.isEmpty)

                case .running:
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                        Button {
                            testRunner.cancel()
                        } label: {
                            Text("Cancel")
                                .font(.uiCaption)
                                .foregroundStyle(Color.diffDeletion)
                        }
                        .buttonStyle(.plain)
                    }

                case .finished(_, let exitCode):
                    HStack(spacing: 6) {
                        Image(systemName: exitCode == 0 ? "checkmark.circle" : "xmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(exitCode == 0 ? Color.statusClean : Color.diffDeletion)
                        Text("exit \(exitCode)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
            }

            if case .finished(let output, _) = entryState {
                ScrollView {
                    Text(output)
                        .font(.monoCaption)
                        .foregroundStyle(Color.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 120)
                .padding(6)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }

    // MARK: - Fire Log

    private var fireLogContent: some View {
        let logs = store.fireLogs
        return Group {
            if logs.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "bolt.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.textTertiary)
                    Text("No events for \(store.selectedEventName.rawValue)")
                        .font(.uiCaption)
                        .foregroundStyle(Color.textTertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(logs) { log in
                            fireLogRow(log)
                            Rectangle()
                                .fill(Color.borderSubtle)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private func fireLogRow(_ log: HookFireLog) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accent)
                .frame(width: 4, height: 4)

            if let toolName = log.toolName {
                Text(toolName)
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
            }

            Spacer()

            Text(log.sessionId.prefix(8))
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Color.textTertiary)

            Text(log.receivedAt, style: .relative)
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "curlybraces")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Text("No hooks for \(store.selectedEventName.rawValue)")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Button {
                store.addEntry()
            } label: {
                Text("Add Hook")
                    .font(.uiCaption)
                    .foregroundStyle(Color.surfaceBase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
