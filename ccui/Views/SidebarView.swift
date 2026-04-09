import SwiftUI

struct SidebarView: View {
    @Environment(RepositoryStore.self) private var store
    @Binding var selectedWorktree: Worktree?
    let worktreeStores: [Repository.ID: WorktreeStore]
    let onAddRepository: () -> Void
    let onShowAddWorktree: (WorktreeStore) -> Void
    let onRemoveWorktree: (Worktree, WorktreeStore) -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if store.repositories.isEmpty {
                Spacer()
                Text("Add a repository to get started")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding()
                Spacer()
            } else {
                List(selection: $selectedWorktree) {
                    ForEach(store.repositories) { repo in
                        repositorySection(repo)
                    }
                }
                .listStyle(.sidebar)
            }
        }
    }

    private var header: some View {
        HStack {
            Text("Repositories")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            Button {
                onAddRepository()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .help("Add Repository")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func repositorySection(_ repo: Repository) -> some View {
        if let wtStore = worktreeStores[repo.id] {
            Section {
                if wtStore.isLoading && wtStore.worktrees.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let error = wtStore.errorMessage, wtStore.worktrees.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(wtStore.worktrees) { wt in
                        worktreeRow(wt, in: wtStore)
                            .tag(wt)
                            .contextMenu {
                                if !wt.isMain {
                                    Button("Remove Worktree", role: .destructive) {
                                        onRemoveWorktree(wt, wtStore)
                                    }
                                }
                            }
                    }

                    Button {
                        onShowAddWorktree(wtStore)
                    } label: {
                        Label("Add Worktree", systemImage: "plus.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text(repo.name)
                    Spacer()
                    Button {
                        Task { await wtStore.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                    .help("Reload worktrees")
                }
                .contextMenu {
                    Button("Remove Repository", role: .destructive) {
                        store.remove(repo)
                    }
                }
            }
            .task(id: repo.id) {
                if wtStore.worktrees.isEmpty && !wtStore.isLoading {
                    await wtStore.load()
                }
            }
        } else {
            Section(repo.name) {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func worktreeRow(_ wt: Worktree, in wtStore: WorktreeStore) -> some View {
        HStack {
            Label {
                Text(wt.displayName)
                    .lineLimit(1)
            } icon: {
                Image(systemName: wt.isMain ? "house" : "arrow.triangle.branch")
                    .foregroundStyle(wt.isMain ? .blue : .secondary)
            }
            Spacer()
            if let count = wtStore.statusCounts[wt.path] {
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.2))
                        .clipShape(Capsule())
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
        }
    }
}
