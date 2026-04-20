import SwiftUI

struct RightPanelView: View {
    let worktreePath: String
    let repositoryPath: String
    let statsRepositoryPath: String
    let sessionEvaluationStore: SessionEvaluationStore
    @Binding var selectedTab: RightPanelTab
    @Environment(DiffStore.self) private var diffStore

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
            tabContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.surfacePrimary)
        .onAppear { loadDiffIfNeeded(for: selectedTab) }
        .onChange(of: selectedTab) { _, newTab in loadDiffIfNeeded(for: newTab) }
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func tabButton(_ tab: RightPanelTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(isSelected ? Color.accent : Color.textTertiary)
                .frame(width: 24, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.accentSubtle : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            switch selectedTab {
            case .timeline:
                TimelineView(worktreePath: worktreePath)
            case .changes:
                DiffViewerView(repositoryPath: repositoryPath)
            case .stats:
                ToolStatsView(repositoryPath: statsRepositoryPath)
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadDiffIfNeeded(for tab: RightPanelTab) {
        guard tab == .changes, diffStore.needsLoad else { return }
        Task { await diffStore.load(repositoryPath: repositoryPath) }
    }
}
