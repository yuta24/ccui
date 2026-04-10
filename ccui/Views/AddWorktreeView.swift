import SwiftUI

struct AddWorktreeView: View {
    let worktreeStore: WorktreeStore
    let repositoryPath: String
    let initialBaseBranch: String?
    @Environment(\.dismiss) private var dismiss

    @State private var branch = ""
    @State private var destinationPath = ""
    @State private var createNewBranch = true
    @State private var baseBranch = ""
    @State private var errorMessage: String?
    @State private var isAdding = false

    private var isCreateDisabled: Bool {
        branch.isEmpty || destinationPath.isEmpty || isAdding || (createNewBranch && baseBranch.isEmpty)
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
                // Branch name
                VStack(alignment: .leading, spacing: 5) {
                    Text("Branch")
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

                // Create new branch toggle
                HStack {
                    Toggle(isOn: $createNewBranch) {
                        Text("Create new branch")
                            .font(.uiLabel)
                            .foregroundStyle(Color.textSecondary)
                    }
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Color.accent)
                    Spacer()
                }

                // Base branch picker (only for new branch)
                if createNewBranch {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Base Branch")
                            .font(.uiCaption)
                            .foregroundStyle(Color.textSecondary)

                        Picker("", selection: $baseBranch) {
                            ForEach(worktreeStore.branches, id: \.self) { branch in
                                Text(branch)
                                    .font(.monoSmall)
                                    .tag(branch)
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                // Destination path
                VStack(alignment: .leading, spacing: 5) {
                    Text("Destination")
                        .font(.uiCaption)
                        .foregroundStyle(Color.textSecondary)

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

                // Error
                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 10))
                        Text(errorMessage)
                            .font(.uiCaption)
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
        }
        .onChange(of: branch) {
            let defaultDir = (repositoryPath as NSString).appendingPathComponent(".claude/worktrees")
            destinationPath = (defaultDir as NSString).appendingPathComponent(branch)
        }
    }

    private func addWorktree() {
        isAdding = true
        errorMessage = nil
        Task {
            defer { isAdding = false }
            do {
                try await worktreeStore.add(
                    branch: branch,
                    path: destinationPath,
                    createBranch: createNewBranch,
                    startPoint: createNewBranch ? baseBranch : nil
                )
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
