import SwiftUI

struct BottomTerminalPanelView: View {
    let worktreePath: String
    @Binding var isExpanded: Bool
    @Environment(ShellSessionStore.self) private var shellStore

    var body: some View {
        let tabs = shellStore.tabs(for: worktreePath)
        let activeTabID = shellStore.activeTabID(for: worktreePath)

        VStack(spacing: 0) {
            if !isExpanded {
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)
            }

            // Tab bar (always visible)
            HStack(spacing: 0) {
                Button {
                    isExpanded.toggle()
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
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
                            tabChip(tab: tab, isActive: tab.id == activeTabID)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                Spacer()

                Button {
                    let isFirst = tabs.isEmpty
                    shellStore.addTab(for: worktreePath)
                    if isFirst {
                        isExpanded = true
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

            // Terminal content (only when expanded)
            if isExpanded {
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)

                if tabs.isEmpty {
                    emptyState
                } else {
                    ZStack {
                        ForEach(tabs) { tab in
                            TerminalContainerView(session: tab.session, isActive: tab.id == activeTabID)
                                .opacity(tab.id == activeTabID ? 1 : 0)
                                .allowsHitTesting(tab.id == activeTabID)
                        }
                    }
                }
            }
        }
    }

    private func tabChip(tab: ShellTab, isActive: Bool) -> some View {
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
            if !isExpanded {
                isExpanded = true
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "terminal")
                .font(.system(size: 24))
                .foregroundStyle(Color.textTertiary)
            Button {
                shellStore.addTab(for: worktreePath)
            } label: {
                Text("New Terminal")
                    .font(.uiCaption)
                    .foregroundStyle(Color.surfaceBase)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
