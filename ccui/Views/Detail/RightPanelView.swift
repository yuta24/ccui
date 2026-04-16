import SwiftUI

struct RightPanelView: View {
    let worktreePath: String
    let repositoryPath: String
    let statsRepositoryPath: String
    let sessionEvaluationStore: SessionEvaluationStore
    @Binding var selectedTab: RightPanelTab
    @Environment(DiffStore.self) private var diffStore
    @State private var panelWidth: CGFloat = 280
    @GestureState private var dragOffset: CGFloat = 0
    @State private var cursorPushed = false
    @State private var handleHovered = false

    private var effectiveWidth: CGFloat {
        max(220, min(600, panelWidth - dragOffset))
    }

    var body: some View {
        HStack(spacing: 0) {
            resizeHandle
            VStack(spacing: 0) {
                tabBar
                Rectangle()
                    .fill(Color.borderSubtle)
                    .frame(height: 1)
                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: effectiveWidth)
        .background(Color.surfacePrimary)
        .onAppear {
            if selectedTab == .changes, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: repositoryPath) }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab == .changes, diffStore.needsLoad {
                Task { await diffStore.load(repositoryPath: repositoryPath) }
            }
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(RightPanelTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func tabButton(_ tab: RightPanelTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 9, weight: .medium))
                Text(tab.rawValue)
                    .font(.uiCaption)
            }
            .foregroundStyle(isSelected ? Color.accent : Color.textTertiary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.accentSubtle : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Resize Handle

    private var resizeHandle: some View {
        Rectangle()
            .fill(handleHovered ? Color.borderStrong : Color.borderSubtle)
            .frame(width: handleHovered ? 3 : 1)
            .animation(.easeInOut(duration: 0.15), value: handleHovered)
            .contentShape(Rectangle().inset(by: -3))
            .gesture(
                DragGesture()
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        panelWidth = max(220, min(600, panelWidth - value.translation.width))
                    }
            )
            .onHover { hovering in
                handleHovered = hovering
                if hovering, !cursorPushed {
                    NSCursor.resizeLeftRight.push()
                    cursorPushed = true
                } else if !hovering, cursorPushed {
                    NSCursor.pop()
                    cursorPushed = false
                }
            }
            .onDisappear {
                if cursorPushed {
                    NSCursor.pop()
                    cursorPushed = false
                }
            }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .timeline:
            TimelineView(worktreePath: worktreePath)
                .frame(maxWidth: .infinity)
        case .changes:
            DiffViewerView(repositoryPath: repositoryPath)
                .frame(maxWidth: .infinity)
        case .stats:
            ToolStatsView(repositoryPath: statsRepositoryPath)
                .frame(maxWidth: .infinity)
        case .eval:
            SessionEvaluationView(
                store: sessionEvaluationStore,
                isVisible: Binding(
                    get: { true },
                    set: { newValue in
                        if !newValue {
                            sessionEvaluationStore.close()
                            selectedTab = .timeline
                        }
                    }
                )
            )
            .frame(maxWidth: .infinity)
        }
    }
}
