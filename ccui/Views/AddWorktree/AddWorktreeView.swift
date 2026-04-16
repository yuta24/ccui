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
    @State private var existingBranch = ""
    @State private var errorMessage: String?
    @State private var isAdding = false
    @State private var showDestination = false

    private enum WorktreeMode: String, CaseIterable {
        case existingBranch = "Existing Branch"
        case newBranch = "New Branch"
    }

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
            header
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
            form
            Rectangle().fill(Color.borderSubtle).frame(height: 1)
            actions
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

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("New Worktree")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }

    // MARK: - Form

    private var form: some View {
        VStack(spacing: 14) {
            Picker("", selection: $mode) {
                ForEach(WorktreeMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if mode == .newBranch {
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

                VStack(alignment: .leading, spacing: 5) {
                    Text("Base Branch")
                        .font(.uiCaption)
                        .foregroundStyle(Color.textSecondary)

                    BranchPickerView(
                        selection: $baseBranch,
                        branches: worktreeStore.branches,
                        isLoading: worktreeStore.isLoadingBranches,
                        isFiltered: false
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Branch")
                        .font(.uiCaption)
                        .foregroundStyle(Color.textSecondary)

                    BranchPickerView(
                        selection: $existingBranch,
                        branches: availableBranches,
                        isLoading: worktreeStore.isLoadingBranches,
                        isFiltered: !worktreeStore.branches.isEmpty
                    )
                }
            }

            DestinationFieldView(
                destinationPath: $destinationPath,
                showDestination: $showDestination
            )

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
    }

    // MARK: - Actions

    private var actions: some View {
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
                PulsingDotsView(dotSize: 4)
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

    // MARK: - Logic

    private func updateDestinationPath(from branchName: String) {
        guard !branchName.isEmpty else {
            destinationPath = ""
            return
        }
        let defaultDir = (repositoryPath as NSString).appendingPathComponent(".claude/worktrees")
        destinationPath = (defaultDir as NSString).appendingPathComponent(branchName)
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
}
