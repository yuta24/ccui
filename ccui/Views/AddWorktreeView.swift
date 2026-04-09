import SwiftUI

struct AddWorktreeView: View {
    let worktreeStore: WorktreeStore
    @Environment(\.dismiss) private var dismiss

    @State private var branch = ""
    @State private var destinationPath = ""
    @State private var createNewBranch = true
    @State private var errorMessage: String?
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Worktree")
                .font(.headline)

            Form {
                TextField("Branch name", text: $branch)

                Toggle("Create new branch", isOn: $createNewBranch)

                HStack {
                    TextField("Destination path", text: $destinationPath)
                    Button("Browse...") {
                        selectDestination()
                    }
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Add") {
                    addWorktree()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(branch.isEmpty || destinationPath.isEmpty || isAdding)
            }
        }
        .padding()
        .frame(width: 400)
    }

    private func addWorktree() {
        isAdding = true
        errorMessage = nil
        Task {
            do {
                try await worktreeStore.add(
                    branch: branch,
                    path: destinationPath,
                    createBranch: createNewBranch
                )
                isAdding = false
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isAdding = false
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
