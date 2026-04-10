import SwiftUI

struct BranchPickerView: View {
    @Binding var selection: String
    let branches: [String]
    let isLoading: Bool
    let isFiltered: Bool

    var body: some View {
        if isLoading {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading branches…")
                    .font(.uiCaption)
                    .foregroundStyle(Color.textTertiary)
            }
            .padding(.vertical, 4)
        } else if branches.isEmpty {
            Text(isFiltered
                 ? "All branches are already checked out"
                 : "No branches available")
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
                .padding(.vertical, 4)
        } else {
            Picker("", selection: $selection) {
                ForEach(branches, id: \.self) { branch in
                    Text(branch)
                        .font(.monoSmall)
                        .tag(branch)
                }
            }
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
