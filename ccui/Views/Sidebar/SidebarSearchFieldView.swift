import SwiftUI

struct SidebarSearchFieldView: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(Color.textTertiary)

            TextField("Filter worktrees", text: $text)
                .textFieldStyle(.plain)
                .font(.uiCaption)
                .focused($isFocused)
                .onKeyPress(.escape) {
                    isFocused = false
                    return .handled
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filter")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.surfaceHover))
        .onAppear {
            // ウィンドウ表示時に AppKit がこの TextField を initial first responder に
            // してしまうため、次の runloop で明示的にフォーカスを外す。
            DispatchQueue.main.async {
                isFocused = false
            }
        }
    }
}
