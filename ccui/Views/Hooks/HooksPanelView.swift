import SwiftUI

struct HooksPanelView: View {
    let worktreePath: String
    @Bindable var store: HooksStore
    @Bindable var testRunner: HookTestRunner
    @Environment(ClaudeEventStore.self) private var claudeEventStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            levelPicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            HooksEventListView(store: store)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            HooksEntryEditorView(worktreePath: worktreePath, store: store, testRunner: testRunner)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 360)
        .background(Color.surfacePrimary)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
        }
        .task {
            await store.load(worktreePath: worktreePath)
            refreshFireLogs()
        }
        .onChange(of: worktreePath) { _, newPath in
            Task { await store.load(worktreePath: newPath) }
            refreshFireLogs()
        }
        .onChange(of: claudeEventStore.sessions[worktreePath]) { _, _ in
            refreshFireLogs()
        }
        .onChange(of: store.selectedEventName) { _, _ in
            refreshFireLogs()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("HOOKS")
                .sectionHeader()
            Spacer()
            if store.isDirty {
                Button {
                    Task { await store.save() }
                } label: {
                    Text("Save")
                        .font(.uiCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func refreshFireLogs() {
        guard let sessions = claudeEventStore.sessions[worktreePath] else { return }
        let allEvents = sessions.values.flatMap(\.events)
        store.updateFireLogs(events: allEvents)
    }

    // MARK: - Level Picker

    private var levelPicker: some View {
        HStack(spacing: 4) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(HookLevel.allCases) { level in
                        Button {
                            store.selectedLevel = level
                        } label: {
                            Text(level.rawValue)
                                .font(.uiCaption)
                                .foregroundStyle(store.selectedLevel == level ? Color.accent : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 4))
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
