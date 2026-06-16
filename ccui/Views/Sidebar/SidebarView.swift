import SwiftUI

struct SidebarView: View {
    let onResumeSession: (String) -> Void
    let onNewSession: () -> Void
    let onEvaluateSession: (WorktreeSessionEntry) -> Void

    @Environment(RepositoryStore.self) private var store
    @Environment(NavigationStore.self) private var navigationStore
    @Environment(WorktreeLifecycleCoordinator.self) private var worktreeLifecycleCoordinator

    @State private var searchQuery: String = ""

    private var hasAnyMatch: Bool {
        guard !searchQuery.isEmpty else { return true }
        return store.repositories.contains { matches($0) }
    }

    private func matches(_ repo: Repository) -> Bool {
        guard !searchQuery.isEmpty else { return true }
        if let wtStore = worktreeLifecycleCoordinator.worktreeStores[repo.id] {
            return RepositorySectionView.matches(repository: repo, worktrees: wtStore.worktrees, query: searchQuery)
        }
        return QuickOpenStore.fuzzyScore(query: searchQuery, candidate: repo.name) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeaderView(onAddRepository: {
                worktreeLifecycleCoordinator.addRepository(store: store)
            })
            .padding(.bottom, 8)

            if store.repositories.isEmpty {
                SidebarEmptyStateView()
            } else {
                SidebarSearchFieldView(text: $searchQuery)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)

                ScrollViewReader { proxy in
                    ScrollView {
                        if hasAnyMatch {
                            LazyVStack(spacing: 2) {
                                ForEach(store.repositories) { repo in
                                    if let wtStore = worktreeLifecycleCoordinator.worktreeStores[repo.id] {
                                        RepositorySectionView(
                                            repository: repo,
                                            worktreeStore: wtStore,
                                            searchQuery: searchQuery
                                        )
                                    } else if matches(repo) {
                                        repositoryLoadingPlaceholder(repo)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 4)
                        } else {
                            noMatchesView
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        // Pinned session list for the selected worktree — stays visible
                        // regardless of how far the repository list above is scrolled.
                        if let worktree = navigationStore.selectedWorktree {
                            VStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.borderSubtle)
                                    .frame(height: 1)

                                SessionListSection(
                                    worktree: worktree,
                                    onResumeSession: onResumeSession,
                                    onNewSession: onNewSession,
                                    onEvaluateSession: onEvaluateSession,
                                    onJumpToWorktree: {
                                        // フィルタで対象行が非表示だとスクロール先の id が
                                        // ツリーに存在せず scrollTo が無反応になるため、
                                        // 先にクエリをクリアしてから次の描画後にスクロールする。
                                        searchQuery = ""
                                        DispatchQueue.main.async {
                                            withAnimation {
                                                proxy.scrollTo(worktree.id, anchor: .center)
                                            }
                                        }
                                    }
                                )
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .frame(height: 240, alignment: .top)
                            }
                            .background(Color.surfaceWindow)
                        }
                    }
                }
            }
        }
        .background(.clear)
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

    private var noMatchesView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)
            Text("No matching worktrees")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}
