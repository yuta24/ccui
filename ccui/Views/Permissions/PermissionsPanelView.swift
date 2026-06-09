import SwiftUI

struct PermissionsPanelView: View {
    let worktreePath: String
    @Bindable var store: PermissionsStore

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
            defaultModePicker
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            PermissionsRuleEditorView(store: store)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 360)
        .background(Color.surfacePrimary)
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.borderSubtle).frame(width: 1)
        }
        .task {
            await store.load(worktreePath: worktreePath)
        }
        .onChange(of: worktreePath) { _, newPath in
            Task { await store.load(worktreePath: newPath) }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("PERMISSIONS")
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

    // MARK: - Level Picker

    private var levelPicker: some View {
        HStack(spacing: 4) {
            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(PermissionLevel.allCases) { level in
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

    // MARK: - Default Mode Picker

    private var defaultModePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Default Mode")
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)

            GlassEffectContainer(spacing: 3) {
                HStack(spacing: 3) {
                    ForEach(PermissionDefaultMode.allCases) { mode in
                        Button {
                            store.setDefaultMode(mode)
                        } label: {
                            Text(mode.displayName)
                                .font(.system(size: 10))
                                .foregroundStyle(store.defaultMode == mode ? Color.accent : Color.primary)
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
