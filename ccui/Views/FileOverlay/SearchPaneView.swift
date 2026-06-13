import SwiftUI

struct SearchPaneView: View {
    @Bindable var searchStore: SearchStore
    let fileOverlayStore: FileOverlayStore
    let fileTreeStore: FileTreeStore?
    let repositoryPath: String

    @FocusState private var isFieldFocused: Bool
    @State private var selectedIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            searchHeader

            Rectangle()
                .fill(Color.borderSubtle)
                .frame(height: 1)

            resultsContent
        }
        .background(Color.surfacePrimary)
        .onAppear {
            isFieldFocused = true
        }
        .onChange(of: searchStore.isActive) { _, newValue in
            if newValue {
                isFieldFocused = true
            }
        }
        .onChange(of: searchStore.mode) { _, _ in
            isFieldFocused = true
            selectedIndex = 0
        }
        .onChange(of: searchStore.fileResults) { _, _ in
            selectedIndex = 0
        }
        .onChange(of: searchStore.contentResults) { _, _ in
            selectedIndex = 0
        }
    }

    // MARK: - Header

    private var searchHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.textTertiary)

            TextField(
                searchStore.mode == .files ? "Search files…" : "Search in files…",
                text: $searchStore.query
            )
            .textFieldStyle(.plain)
            .font(.monoSmall)
            .foregroundStyle(Color.textPrimary)
            .focused($isFieldFocused)
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

            Text(searchStore.mode == .files ? "Files" : "Content")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(Color.textTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.surfaceHover)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsContent: some View {
        switch searchStore.mode {
        case .files:
            fileResultsList
        case .content:
            contentResultsList
        }
    }

    // MARK: - File Results

    @ViewBuilder
    private var fileResultsList: some View {
        if searchStore.fileResults.isEmpty && !searchStore.query.isEmpty {
            emptyState("No matching files")
        } else if !searchStore.fileResults.isEmpty {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searchStore.fileResults.enumerated()), id: \.element.id) { index, result in
                            QuickOpenRowView(
                                result: result,
                                isSelected: index == selectedIndex,
                                repositoryPath: repositoryPath
                            )
                            .id(result.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectFile(result.node)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    if newIndex < searchStore.fileResults.count {
                        proxy.scrollTo(searchStore.fileResults[newIndex].id, anchor: .center)
                    }
                }
            }
        } else {
            emptyState("Type to search files")
        }
    }

    // MARK: - Content Results

    @ViewBuilder
    private var contentResultsList: some View {
        if searchStore.isSearching {
            VStack {
                Spacer()
                PulsingDotsView()
                Spacer()
            }
            .frame(maxWidth: .infinity)
        } else if searchStore.contentResults.isEmpty && !searchStore.query.isEmpty && searchStore.query.count >= 2 {
            emptyState("No matches found")
        } else if !searchStore.contentResults.isEmpty {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchStore.contentResults) { fileResult in
                        ContentSearchFileRow(
                            result: fileResult,
                            query: searchStore.query,
                            onSelectMatch: { match in
                                selectContentMatch(fileResult, match: match)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
        } else {
            emptyState("Type to search in files (min 2 chars)")
        }
    }

    // MARK: - Empty State

    private func emptyState(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.uiCaption)
                .foregroundStyle(Color.textTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func moveSelection(by offset: Int) {
        guard searchStore.mode == .files, !searchStore.fileResults.isEmpty else { return }
        let newIndex = selectedIndex + offset
        selectedIndex = max(0, min(searchStore.fileResults.count - 1, newIndex))
    }

    private func confirmSelection() {
        guard searchStore.mode == .files,
              !searchStore.fileResults.isEmpty,
              selectedIndex < searchStore.fileResults.count else { return }
        selectFile(searchStore.fileResults[selectedIndex].node)
    }

    private func selectFile(_ node: FileNode) {
        fileOverlayStore.selectFile(node)
        fileTreeStore?.selectNode(node)
    }

    private func selectContentMatch(_ result: ContentSearchResult, match: ContentSearchMatch) {
        let node = FileNode(name: result.fileName, path: result.filePath, isDirectory: false)
        fileOverlayStore.selectFile(node)
        fileTreeStore?.selectNode(node)
    }
}

// MARK: - Content Search File Row

struct ContentSearchFileRow: View {
    let result: ContentSearchResult
    let query: String
    let onSelectMatch: (ContentSearchMatch) -> Void

    @State private var isExpanded = true
    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(Color.textTertiary)
                    .frame(width: 12)

                Image(systemName: FileTreeHelpers.fileIcon(for: result.fileName))
                    .font(.system(size: 10))
                    .foregroundStyle(Color.accent.opacity(0.7))

                Text(result.fileName)
                    .font(.uiCaption)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)

                Text(result.relativePath)
                    .font(.uiCaptionMono)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text("\(result.matches.count)")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.textTertiary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.surfaceHover)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isHovered ? Color.surfaceHover : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isExpanded.toggle()
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }

            if isExpanded {
                ForEach(result.matches) { match in
                    ContentSearchMatchRow(match: match, query: query) {
                        onSelectMatch(match)
                    }
                }
            }
        }
    }
}

// MARK: - Content Search Match Row

struct ContentSearchMatchRow: View {
    let match: ContentSearchMatch
    let query: String
    let onSelect: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text("\(match.lineNumber)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Color.gutterText)
                .frame(width: 36, alignment: .trailing)

            highlightedContent
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.leading, 16)
        .padding(.vertical, 2)
        .background(isHovered ? Color.surfaceHover : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { hovering in isHovered = hovering }
    }

    private var highlightedContent: some View {
        let content = match.lineContent.trimmingCharacters(in: .whitespaces)
        var attributed = AttributedString(content)
        attributed.font = .system(.caption2, design: .monospaced)
        attributed.foregroundColor = Color.textSecondary

        if !query.isEmpty {
            var searchStart = content.startIndex
            while searchStart < content.endIndex {
                if let range = content.range(of: query, options: .caseInsensitive, range: searchStart..<content.endIndex),
                   let attrStart = AttributedString.Index(range.lowerBound, within: attributed),
                   let attrEnd = AttributedString.Index(range.upperBound, within: attributed) {
                    attributed[attrStart..<attrEnd].foregroundColor = Color.accent
                    searchStart = range.upperBound
                } else {
                    break
                }
            }
        }

        return Text(attributed)
    }
}
