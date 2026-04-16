import SwiftUI

struct QuickOpenPaletteView: View {
    @Bindable var quickOpenStore: QuickOpenStore
    let fileOverlayStore: FileOverlayStore
    let fileTreeStore: FileTreeStore?
    let repositoryPath: String

    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    quickOpenStore.close()
                }

            GeometryReader { geometry in
                let panelWidth = min(560, geometry.size.width * 0.6)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        quickOpenStore.close()
                    }

                VStack(spacing: 0) {
                    searchField

                    Rectangle()
                        .fill(Color.borderSubtle)
                        .frame(height: 1)

                    resultsList
                }
                .frame(width: panelWidth)
                .frame(maxHeight: 420)
                .fixedSize(horizontal: false, vertical: true)
                .background(Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.borderDefault, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 8)
                .position(
                    x: geometry.size.width / 2,
                    y: geometry.size.height * 0.3
                )
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: quickOpenStore.results) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            TextField("Go to file…", text: $quickOpenStore.query)
                .textFieldStyle(.plain)
                .font(.monoSmall)
                .foregroundStyle(Color.textPrimary)
                .focused($isTextFieldFocused)
                .onKeyPress(.upArrow) {
                    moveSelection(by: -1)
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    moveSelection(by: 1)
                    return .handled
                }
                .onKeyPress(.return) {
                    confirmSelection()
                    return .handled
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Results List

    private var resultsList: some View {
        Group {
            if quickOpenStore.isIndexing && quickOpenStore.results.isEmpty {
                VStack(spacing: 6) {
                    PulsingDotsView()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if quickOpenStore.results.isEmpty && !quickOpenStore.query.isEmpty {
                VStack(spacing: 6) {
                    Text("No matching files")
                        .font(.uiCaption)
                        .foregroundStyle(Color.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if !quickOpenStore.results.isEmpty {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(quickOpenStore.results.enumerated()), id: \.element.id) { index, result in
                                QuickOpenRowView(
                                    result: result,
                                    isSelected: index == selectedIndex,
                                    repositoryPath: repositoryPath
                                )
                                .id(result.id)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    select(result: result)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: selectedIndex) { _, newIndex in
                        if newIndex < quickOpenStore.results.count {
                            proxy.scrollTo(quickOpenStore.results[newIndex].id, anchor: .center)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func moveSelection(by offset: Int) {
        guard !quickOpenStore.results.isEmpty else { return }
        let newIndex = selectedIndex + offset
        selectedIndex = max(0, min(quickOpenStore.results.count - 1, newIndex))
    }

    private func confirmSelection() {
        guard !quickOpenStore.results.isEmpty,
              selectedIndex < quickOpenStore.results.count else { return }
        select(result: quickOpenStore.results[selectedIndex])
    }

    private func select(result: QuickOpenResult) {
        fileOverlayStore.selectFile(result.node)
        fileTreeStore?.selectNode(result.node)
        quickOpenStore.close()
    }
}
