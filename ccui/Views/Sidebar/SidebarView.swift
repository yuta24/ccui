import SwiftUI

struct SidebarView: View {
    let onResumeSession: (String) -> Void
    let onNewSession: () -> Void
    let onEvaluateSession: (WorktreeSessionEntry) -> Void
    let onCompareSession: (WorktreeSessionEntry, WorktreeSessionEntry) -> Void

    @Environment(RepositoryStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeaderView(onAddRepository: {
                coordinator.addRepository(store: store)
            })
            .padding(.top, 10)
            .padding(.bottom, 8)

            if store.repositories.isEmpty {
                SidebarEmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.repositories) { repo in
                            if let wtStore = coordinator.worktreeStores[repo.id] {
                                RepositorySectionView(
                                    repository: repo,
                                    worktreeStore: wtStore
                                )
                            } else {
                                repositoryLoadingPlaceholder(repo)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 4)

                    // Session list for selected worktree
                    if let worktree = coordinator.selectedWorktree {
                        Rectangle()
                            .fill(Color.borderSubtle)
                            .frame(height: 1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)

                        SessionListSection(
                            worktree: worktree,
                            onResumeSession: onResumeSession,
                            onNewSession: onNewSession,
                            onEvaluateSession: onEvaluateSession,
                            onCompareSession: onCompareSession
                        )
                        .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    private func repositoryLoadingPlaceholder(_ repo: Repository) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(repo.name)
                .font(.uiCaption)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 8)
            PulsingDotsView()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
    }
}
