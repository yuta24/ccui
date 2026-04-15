import SwiftUI

struct DetailTopBar: View {
    let worktree: Worktree
    let fileOverlayStore: FileOverlayStore
    let hasActiveSession: Bool
    @Binding var isTimelineVisible: Bool
    @Binding var isStatsVisible: Bool
    @Binding var isClaudeMdVisible: Bool
    @Binding var isEvaluationVisible: Bool
    @Binding var isHooksVisible: Bool
    @Binding var isPermissionsVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            Spacer()

            HStack(spacing: 5) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 9, weight: .medium))
                Text(worktree.displayName)
                    .font(.uiCaption)
            }
            .foregroundStyle(Color.textTertiary)

            Spacer()

            HStack(spacing: 4) {
                if hasActiveSession {
                    topBarButton(
                        icon: "chart.bar.xaxis",
                        label: "Timeline",
                        isActive: isTimelineVisible
                    ) {
                        isTimelineVisible.toggle()
                    }
                }

                topBarButton(
                    icon: "doc.text",
                    label: "CLAUDE.md",
                    isActive: isClaudeMdVisible
                ) {
                    isClaudeMdVisible.toggle()
                }

                topBarButton(
                    icon: "checkmark.seal",
                    label: "Eval",
                    isActive: isEvaluationVisible
                ) {
                    isEvaluationVisible.toggle()
                }

                topBarButton(
                    icon: "bolt.fill",
                    label: "Hooks",
                    isActive: isHooksVisible
                ) {
                    isHooksVisible.toggle()
                }

                topBarButton(
                    icon: "lock.shield",
                    label: "Perms",
                    isActive: isPermissionsVisible
                ) {
                    isPermissionsVisible.toggle()
                }

                topBarButton(
                    icon: "chart.bar",
                    label: "Stats",
                    isActive: isStatsVisible
                ) {
                    isStatsVisible.toggle()
                }

                topBarButton(
                    icon: "doc.text.magnifyingglass",
                    label: "Files",
                    isActive: fileOverlayStore.isVisible,
                    shortcut: "⇧⌘E"
                ) {
                    fileOverlayStore.toggle()
                }
            }
            .padding(.trailing, 12)
        }
        .frame(height: 36)
        .background(Color.surfaceBase)
    }

    private func topBarButton(icon: String, label: String, isActive: Bool, shortcut: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.uiLabel)
            }
            .foregroundStyle(isActive ? Color.accent : Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isActive ? Color.accentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(shortcut.map { "\(label) (\($0))" } ?? label)
    }
}
