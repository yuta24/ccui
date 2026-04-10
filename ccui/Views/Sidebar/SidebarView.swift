import SwiftUI

struct SidebarView: View {
    @Environment(RepositoryStore.self) private var store
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
                .frame(height: 12)

            SidebarHeaderView(onAddRepository: {
                coordinator.addRepository(store: store)
            })
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
                    .padding(.bottom, 8)
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
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        }
    }
}
