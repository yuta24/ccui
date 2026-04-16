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
                    .foregroundStyle(Color.textSecondary)
                    .frame(width: 20, height: 20)
                    .background(Color.surfaceElevated)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .buttonStyle(.hoverScale)
            .help("Add Repository")
        }
        .padding(.horizontal, 14)
    }
}
