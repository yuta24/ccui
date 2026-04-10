import SwiftUI

struct DiffModeToggle: View {
    let currentMode: DiffStore.DiffMode
    let onSelectMode: (DiffStore.DiffMode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            modeButton(.staged)
            modeButton(.unstaged)
        }
        .background(Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .strokeBorder(Color.borderSubtle, lineWidth: 1)
        )
    }

    private func modeButton(_ mode: DiffStore.DiffMode) -> some View {
        let isSelected = currentMode == mode

        return Button {
            onSelectMode(mode)
        } label: {
            Text(mode.rawValue)
                .font(.uiLabel)
                .foregroundStyle(isSelected ? Color.textPrimary : Color.textTertiary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.surfaceHover : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
