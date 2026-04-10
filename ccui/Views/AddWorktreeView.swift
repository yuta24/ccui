import SwiftUI

struct AddWorktreeView: View {
    let worktreeStore: WorktreeStore
    let repositoryPath: String
    let initialBaseBranch: String?
    @Environment(\.dismiss) private var dismiss

    @State private var branch = ""
    @State private var destinationPath = ""
    @State private var mode: WorktreeMode = .newBranch
    @State private var baseBranch = ""

    private enum WorktreeMode: String, CaseIterable {
        case existingBranch = "Existing Branch"
        case newBranch = "New Branch"
    }
    @State private var existingBranch = ""
    @State private var errorMessage: String?
    @State private var isAdding = false
    @State private var showDestination = false

    private var isCreateDisabled: Bool {
        if isAdding || destinationPath.isEmpty { return true }
        if mode == .newBranch {
            return branch.isEmpty || baseBranch.isEmpty
        } else {
            return existingBranch.isEmpty
        }
    }

    private var availableBranches: [String] {
        let checkedOut = Set(worktreeStore.worktrees.compactMap(\.branch))
        return worktreeStore.branches.filter { !checkedOut.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Worktree")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            // Form
            VStack(spacing: 14) {
                // Mode picker
                Picker("", selection: $mode) {
                    ForEach(WorktreeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if mode == .newBranch {
                    // New branch name
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Branch Name")
                            .font(.uiCaption)
                            .foregroundStyle(Color.textSecondary)

                        TextField("feature/my-branch", text: $branch)
                            .textFieldStyle(.plain)
                            .font(.monoSmall)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.surfaceElevated)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.borderDefault, lineWidth: 1)
                            )
                    }

                    // Base branch picker
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Base Branch")
                            .font(.uiCaption)
                            .foregroundStyle(Color.textSecondary)

                        branchPicker(selection: $baseBranch)
                    }
                } else {
                    // Existing branch picker (exclude already checked-out branches)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Branch")
                            .font(.uiCaption)
                            .foregroundStyle(Color.textSecondary)

                        branchPicker(selection: $existingBranch, branches: availableBranches)
                    }
                }

                // Destination path (collapsible)
                VStack(alignment: .leading, spacing: 5) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showDestination.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 8, weight: .semibold))
                                .rotationEffect(.degrees(showDestination ? 90 : 0))
                            Text("Destination")
                                .font(.uiCaption)
                            Spacer()
                            if !showDestination {
                                Text(abbreviatedPath(destinationPath))
                                    .font(.monoCaption)
                                    .foregroundStyle(Color.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .foregroundStyle(Color.textSecondary)
                    }
                    .buttonStyle(.plain)

                    if showDestination {
                        HStack(spacing: 6) {
                            TextField("/path/to/worktree", text: $destinationPath)
                                .textFieldStyle(.plain)
                                .font(.monoCaption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(Color.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                                )

                            Button("Browse") {
                                selectDestination()
                            }
                            .font(.uiLabel)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentSubtle)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                        }
                    }
                }

                // Error
                if let errorMessage {
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                            .padding(.top, 2)
                        Text(errorMessage)
                            .font(.uiCaption)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(Color.diffDeletion)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.plain)
                .font(.uiLabel)
                .foregroundStyle(Color.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )

                Spacer()

                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.trailing, 6)
                }

                Button("Create") {
                    addWorktree()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(isCreateDisabled)
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isCreateDisabled ? Color.textTertiary : Color.surfaceBase)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isCreateDisabled ? Color.surfaceElevated : Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 440)
        .background(Color.surfacePrimary)
        .preferredColorScheme(.dark)
        .task {
            await worktreeStore.loadBranches()
            if let initial = initialBaseBranch,
               worktreeStore.branches.contains(initial) {
                baseBranch = initial
            } else if let defaultBranch = worktreeStore.defaultBranch,
                      worktreeStore.branches.contains(defaultBranch) {
                baseBranch = defaultBranch
            } else if let first = worktreeStore.branches.first {
                baseBranch = first
            }
            if let first = availableBranches.first, existingBranch.isEmpty {
                existingBranch = first
            }
        }
        .onChange(of: branch) {
            updateDestinationPath(from: branch)
        }
        .onChange(of: existingBranch) {
            if mode == .existingBranch {
                updateDestinationPath(from: existingBranch)
            }
        }
        .onChange(of: mode) {
            if mode == .newBranch {
                updateDestinationPath(from: branch)
            } else {
                updateDestinationPath(from: existingBranch)
            }
        }
    }

    @ViewBuilder
    private func branchPicker(selection: Binding<String>, branches: [String]? = nil) -> some View {
        let items = branches ?? worktreeStore.branches
        let isFiltered = branches != nil
        if worktreeStore.isLoadingBranches {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading branches…")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 4)
        } else if items.isEmpty {
            Text(isFiltered && !worktreeStore.branches.isEmpty
                 ? "All branches are already checked out"
                 : "No branches available")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .padding(.vertical, 4)
        } else {
            Picker("", selection: selection) {
                ForEach(items, id: \.self) { branch in
                    Text(branch)
                        .font(.monoSmall)
                        .tag(branch)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func updateDestinationPath(from branchName: String) {
        guard !branchName.isEmpty else {
            destinationPath = ""
            return
        }
        let defaultDir = (repositoryPath as NSString).appendingPathComponent(".claude/worktrees")
        destinationPath = (defaultDir as NSString).appendingPathComponent(branchName)
    }

    private func abbreviatedPath(_ path: String) -> String {
        guard !path.isEmpty else { return "" }
        let home = FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false)
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func addWorktree() {
        isAdding = true
        errorMessage = nil
        Task {
            defer { isAdding = false }
            do {
                if mode == .newBranch {
                    try await worktreeStore.add(
                        branch: branch,
                        path: destinationPath,
                        createBranch: true,
                        startPoint: baseBranch
                    )
                } else {
                    try await worktreeStore.add(
                        branch: existingBranch,
                        path: destinationPath,
                        createBranch: false
                    )
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func selectDestination() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.message = "Choose a directory for the worktree"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        destinationPath = url.path(percentEncoded: false)
    }
}
