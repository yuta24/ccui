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
        .onAppear {
            store.load(worktreePath: worktreePath)
            refreshFireLogs()
        }
        .onChange(of: worktreePath) { _, newPath in
            store.load(worktreePath: newPath)
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
                    store.save()
                } label: {
                    Text("Save")
                        .font(.uiCaption)
                        .foregroundStyle(Color.surfaceBase)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
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
            ForEach(HookLevel.allCases) { level in
                Button {
                    store.selectedLevel = level
                } label: {
                    Text(level.rawValue)
                        .font(.uiCaption)
                        .foregroundStyle(store.selectedLevel == level ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(store.selectedLevel == level ? Color.accentSubtle : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
