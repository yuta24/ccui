import SwiftUI

struct SidebarView: View {
    @Environment(RepositoryStore.self) private var store
    @Binding var selectedWorktree: Worktree?
    let worktreeStores: [Repository.ID: WorktreeStore]
    let onAddRepository: () -> Void
    let onShowAddWorktree: (WorktreeStore, String?) -> Void
    let onRemoveWorktree: (Worktree, WorktreeStore) -> Void

    @State private var hoveredWorktree: Worktree?

    var body: some View {
        VStack(spacing: 0) {
            // Drag area for window
            Color.clear
                .frame(height: 12)

            header
                .padding(.bottom, 8)

            if store.repositories.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(store.repositories) { repo in
                            repositorySection(repo)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Repositories")
                .sectionHeader()

            Spacer()

            Button {
                onAddRepository()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.plain)
            .help("Add Repository")
        }
        .padding(.horizontal, 14)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 28, weight: .ultraLight))
                .foregroundStyle(Color.textTertiary)

            Text("Add a repository\nto get started")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
            Spacer()
        }
    }

    // MARK: - Repository Section

    @ViewBuilder
    private func repositorySection(_ repo: Repository) -> some View {
        if let wtStore = worktreeStores[repo.id] {
            VStack(alignment: .leading, spacing: 0) {
                // Section header
                HStack(spacing: 6) {
                    Text(repo.name)
                        .font(.uiCaption)
                        .foregroundStyle(Color.textSecondary)
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        Task { await wtStore.load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Reload worktrees")
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contextMenu {
                    Button("Remove Repository", role: .destructive) {
                        store.remove(repo)
                    }
                }

                // Worktree list
                if wtStore.isLoading && wtStore.worktrees.isEmpty {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else if let error = wtStore.errorMessage, wtStore.worktrees.isEmpty {
                    Text(error)
                        .font(.uiCaption)
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                } else {
                    ForEach(wtStore.worktrees) { wt in
                        worktreeRow(wt, in: wtStore)
                            .contextMenu {
                                if let branch = wt.branch {
                                    Button("Add Worktree from \"\(branch)\"...") {
                                        onShowAddWorktree(wtStore, branch)
                                    }
                                }
                                if !wt.isMain {
                                    Divider()
                                    Button("Remove Worktree", role: .destructive) {
                                        onRemoveWorktree(wt, wtStore)
                                    }
                                }
                            }
                    }

                    // Add worktree button
                    Button {
                        onShowAddWorktree(wtStore, nil)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .medium))
                            Text("Add Worktree")
                                .font(.uiCaption)
                        }
                        .foregroundStyle(Color.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .task(id: repo.id) {
                if wtStore.worktrees.isEmpty && !wtStore.isLoading {
                    await wtStore.load()
                    wtStore.startWatching()
                }
            }

            // Section divider
            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
        } else {
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

    // MARK: - Worktree Row

    private func worktreeRow(_ wt: Worktree, in wtStore: WorktreeStore) -> some View {
        let isSelected = selectedWorktree == wt
        let isHovered = hoveredWorktree == wt

        return Button {
            selectedWorktree = wt
        } label: {
            HStack(spacing: 8) {
                // Icon
                RoundedRectangle(cornerRadius: 3)
                    .fill(wt.isMain ? Color.accent.opacity(0.8) : Color.textTertiary.opacity(0.5))
                    .frame(width: 4, height: 16)

                // Name
                Text(wt.displayName)
                    .font(.uiLabel)
                    .foregroundStyle(isSelected ? Color.textPrimary : Color.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Status badge
                if let count = wtStore.statusCounts[wt.path] {
                    if count > 0 {
                        Text("\(count)")
                            .font(.uiCaptionMono)
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.accentSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Circle()
                            .fill(Color.statusClean)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.surfaceElevated : (isHovered ? Color.surfaceHover : Color.clear))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isSelected ? Color.borderDefault : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredWorktree = hovering ? wt : nil
        }
    }
}
