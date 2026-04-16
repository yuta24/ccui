import SwiftUI

struct RightPanelContainerView: View {
    @Environment(DetailUIState.self) private var uiState
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        if let worktree = coordinator.selectedWorktree {
            let repoPath = coordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
            RightPanelView(
                worktreePath: worktree.path,
                repositoryPath: worktree.path,
                statsRepositoryPath: repoPath,
                sessionEvaluationStore: uiState.sessionEvaluationStore,
                selectedTab: Binding(
                    get: { uiState.rightPanelTab },
                    set: { uiState.rightPanelTab = $0 }
                )
            )
        }
    }
}
