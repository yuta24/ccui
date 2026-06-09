import SwiftUI

enum ConfigurationTab: String, CaseIterable {
    case claudeMd = "CLAUDE.md"
    case hooks = "Hooks"
    case permissions = "Permissions"

    var icon: String {
        switch self {
        case .claudeMd: "doc.text"
        case .hooks: "bolt.fill"
        case .permissions: "lock.shield"
        }
    }
}

struct ConfigurationSheet: View {
    let worktreePath: String
    let repositoryPath: String
    @Binding var isPresented: Bool
    @Environment(ClaudeEventStore.self) private var claudeEventStore
    @State private var selectedTab: ConfigurationTab = .claudeMd
    @State private var claudeMdStore = ClaudeMdStore()
    @State private var hooksStore = HooksStore()
    @State private var hookTestRunner = HookTestRunner()
    @State private var permissionsStore = PermissionsStore()

    var body: some View {
        VStack(spacing: 0) {
            sheetHeader
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            tabBar
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 640, height: 520)
        .background(.ultraThinMaterial)
        .background {
            // Cmd+S save shortcut for current tab
            Button("") { saveCurrentTab() }
                .keyboardShortcut("s", modifiers: .command)
                .opacity(0)
                .allowsHitTesting(false)
        }
    }

    private func saveCurrentTab() {
        switch selectedTab {
        case .claudeMd: claudeMdStore.save()
        case .hooks: Task { await hooksStore.save() }
        case .permissions: Task { await permissionsStore.save() }
        }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            Text("Configuration")
                .font(.uiLabel)
                .foregroundStyle(Color.textPrimary)
            Spacer()
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(ConfigurationTab.allCases, id: \.self) { tab in
                        let isSelected = selectedTab == tab
                        Button {
                            selectedTab = tab
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 10, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.uiCaption)
                            }
                            .foregroundStyle(isSelected ? Color.accent : Color.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 5))
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .claudeMd:
            claudeMdContent
        case .hooks:
            hooksContent
        case .permissions:
            permissionsContent
        }
    }

    private var claudeMdContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            ClaudeMdListView(store: claudeMdStore)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            ClaudeMdEditorView(store: claudeMdStore)
                .frame(maxHeight: .infinity)
        }
        .onAppear {
            claudeMdStore.load(repositoryPath: repositoryPath)
        }
        .onChange(of: repositoryPath) { _, newPath in
            claudeMdStore.load(repositoryPath: newPath)
        }
    }

    private var hooksContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            hooksLevelPicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            HooksEventListView(store: hooksStore)
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            HooksEntryEditorView(worktreePath: worktreePath, store: hooksStore, testRunner: hookTestRunner)
                .frame(maxHeight: .infinity)
        }
        .task {
            await hooksStore.load(worktreePath: worktreePath)
            refreshFireLogs()
        }
        .onChange(of: worktreePath) { _, newPath in
            Task { await hooksStore.load(worktreePath: newPath) }
            refreshFireLogs()
        }
        .onChange(of: claudeEventStore.sessions[worktreePath]) { _, _ in
            refreshFireLogs()
        }
        .onChange(of: hooksStore.selectedEventName) { _, _ in
            refreshFireLogs()
        }
    }

    private func refreshFireLogs() {
        guard let sessions = claudeEventStore.sessions[worktreePath] else { return }
        let allEvents = sessions.values.flatMap(\.events)
        hooksStore.updateFireLogs(events: allEvents)
    }

    private var hooksLevelPicker: some View {
        HStack(spacing: 4) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(HookLevel.allCases) { level in
                        Button {
                            hooksStore.selectedLevel = level
                        } label: {
                            Text(level.rawValue)
                                .font(.uiCaption)
                                .foregroundStyle(hooksStore.selectedLevel == level ? Color.accent : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 4))
                    }
                }
            }
            Spacer()
            if hooksStore.isDirty {
                Button {
                    Task { await hooksStore.save() }
                } label: {
                    Text("Save")
                        .font(.uiCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var permissionsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            permissionsLevelPicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            permissionsDefaultModePicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            PermissionsRuleEditorView(store: permissionsStore)
                .frame(maxHeight: .infinity)
        }
        .task {
            await permissionsStore.load(worktreePath: worktreePath)
        }
        .onChange(of: worktreePath) { _, newPath in
            Task { await permissionsStore.load(worktreePath: newPath) }
        }
    }

    private var permissionsLevelPicker: some View {
        HStack(spacing: 4) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(PermissionLevel.allCases) { level in
                        Button {
                            permissionsStore.selectedLevel = level
                        } label: {
                            Text(level.rawValue)
                                .font(.uiCaption)
                                .foregroundStyle(permissionsStore.selectedLevel == level ? Color.accent : Color.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 4))
                    }
                }
            }
            Spacer()
            if permissionsStore.isDirty {
                Button {
                    Task { await permissionsStore.save() }
                } label: {
                    Text("Save")
                        .font(.uiCaption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glassProminent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var permissionsDefaultModePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Default Mode")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)

            GlassEffectContainer(spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(PermissionDefaultMode.allCases) { mode in
                        Button {
                            permissionsStore.setDefaultMode(mode)
                        } label: {
                            Text(mode.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(permissionsStore.defaultMode == mode ? Color.accent : Color.primary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 3))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
