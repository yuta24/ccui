import SwiftUI

struct BottomTerminalTabBarView: View {
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(ShellSessionStore.self) private var shellStore
    @Environment(BottomPanelState.self) private var panelState

    var body: some View {
        if let worktree = coordinator.selectedWorktree {
            tabBar(worktreePath: worktree.path)
        } else {
            placeholderTabBar
        }
    }

    private var placeholderTabBar: some View {
        HStack(spacing: 0) {
            Image(systemName: "chevron.up")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color.textTertiary)
                .frame(width: 24, height: 24)
                .padding(.leading, 8)
            Spacer()
        }
        .frame(height: 32)
        .background(Color.surfaceBase)
    }

    private func tabBar(worktreePath: String) -> some View {
        let tabs = shellStore.tabs(for: worktreePath)
        let activeTabID = shellStore.activeTabID(for: worktreePath)

        return HStack(spacing: 0) {
            Button {
                panelState.toggle()
            } label: {
                Image(systemName: panelState.isExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 1) {
                    ForEach(tabs) { tab in
                        tabChip(tab: tab, isActive: tab.id == activeTabID, worktreePath: worktreePath)
                    }
                }
                .padding(.horizontal, 4)
            }

            Spacer()

            Button {
                let isFirst = tabs.isEmpty
                shellStore.addTab(for: worktreePath)
                if isFirst, !panelState.isExpanded {
                    panelState.isExpanded = true
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
        }
        .frame(height: 32)
        .background(Color.surfaceBase)
    }

    private func tabChip(tab: ShellTab, isActive: Bool, worktreePath: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "terminal")
                .font(.system(size: 9, weight: .medium))
            Text(tab.title)
                .font(.uiCaption)
                .lineLimit(1)

            Button {
                shellStore.closeTab(id: tab.id, worktreePath: worktreePath)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 14, height: 14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(isActive ? Color.textPrimary : Color.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentSubtle : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            shellStore.setActiveTab(id: tab.id, worktreePath: worktreePath)
            if !panelState.isExpanded {
                panelState.isExpanded = true
            }
        }
    }
}
