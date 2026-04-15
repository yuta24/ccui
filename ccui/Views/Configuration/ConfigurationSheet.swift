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
        .background(Color.surfaceBase)
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
        case .hooks: hooksStore.save()
        case .permissions: permissionsStore.save()
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
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
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
                    .foregroundStyle(isSelected ? Color.accent : Color.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isSelected ? Color.accentSubtle : Color.clear)
                    )
                }
                .buttonStyle(.plain)
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
        .background(Color.surfacePrimary)
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
        .background(Color.surfacePrimary)
        .onAppear {
            hooksStore.load(worktreePath: worktreePath)
            refreshFireLogs()
        }
        .onChange(of: worktreePath) { _, newPath in
            hooksStore.load(worktreePath: newPath)
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
            ForEach(HookLevel.allCases) { level in
                Button {
                    hooksStore.selectedLevel = level
                } label: {
                    Text(level.rawValue)
                        .font(.uiCaption)
                        .foregroundStyle(hooksStore.selectedLevel == level ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(hooksStore.selectedLevel == level ? Color.accentSubtle : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if hooksStore.isDirty {
                Button {
                    hooksStore.save()
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
        .background(Color.surfacePrimary)
        .onAppear {
            permissionsStore.load(worktreePath: worktreePath)
        }
        .onChange(of: worktreePath) { _, newPath in
            permissionsStore.load(worktreePath: newPath)
        }
    }

    private var permissionsLevelPicker: some View {
        HStack(spacing: 4) {
            ForEach(PermissionLevel.allCases) { level in
                Button {
                    permissionsStore.selectedLevel = level
                } label: {
                    Text(level.rawValue)
                        .font(.uiCaption)
                        .foregroundStyle(permissionsStore.selectedLevel == level ? Color.accent : Color.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(permissionsStore.selectedLevel == level ? Color.accentSubtle : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
            if permissionsStore.isDirty {
                Button {
                    permissionsStore.save()
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
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private var permissionsDefaultModePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Default Mode")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)

            HStack(spacing: 3) {
                ForEach(PermissionDefaultMode.allCases) { mode in
                    Button {
                        permissionsStore.setDefaultMode(mode)
                    } label: {
                        Text(mode.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(permissionsStore.defaultMode == mode ? Color.accent : Color.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(permissionsStore.defaultMode == mode ? Color.accentSubtle : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
