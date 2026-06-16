import SwiftUI

struct RightPanelContainerView: View {
    @Environment(DetailUIState.self) private var uiState
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(WorktreeLifecycleCoordinator.self) private var worktreeLifecycleCoordinator

    var body: some View {
        if let worktree = navigationStore.selectedWorktree {
            let repoPath = worktreeLifecycleCoordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
            RightPanelView(
                worktreePath: worktree.path,
                repositoryPath: repoPath,
                sessionEvaluationStore: uiState.sessionEvaluationStore,
                selectedTab: Binding(
                    get: { uiState.rightPanelTab },
                    set: { uiState.rightPanelTab = $0 }
                )
            )
        }
    }
}
