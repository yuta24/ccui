import SwiftUI

struct SidebarHeaderView: View {
    let onAddRepository: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Text("Repositories")
                .sectionHeader()

            Spacer()

            Button {
                onAddRepository()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 4))
            .help("Add Repository")
        }
        .padding(.horizontal, 14)
    }
}
