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
        .onAppear {
            store.load(worktreePath: worktreePath)
        }
        .onChange(of: worktreePath) { _, newPath in
            store.load(worktreePath: newPath)
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

    // MARK: - Level Picker

    private var levelPicker: some View {
        HStack(spacing: 4) {
            ForEach(PermissionLevel.allCases) { level in
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

    // MARK: - Default Mode Picker

    private var defaultModePicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Default Mode")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)

            HStack(spacing: 3) {
                ForEach(PermissionDefaultMode.allCases) { mode in
                    Button {
                        store.setDefaultMode(mode)
                    } label: {
                        Text(mode.displayName)
                            .font(.system(size: 10))
                            .foregroundStyle(store.defaultMode == mode ? Color.accent : Color.textTertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(store.defaultMode == mode ? Color.accentSubtle : Color.clear)
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
