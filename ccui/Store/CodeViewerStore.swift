import Foundation

@Observable
@MainActor
final class CodeViewerStore {
    enum State {
        case idle
        case loading
        case loaded(content: String, lines: [String])
        case binary
        case error(String)
    }

    private(set) var state: State = .idle
    private(set) var loadedPath: String?

    func load(path: String) async {
        guard path != loadedPath else { return }
        loadedPath = path
        state = .loading

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.readFile(at: path)
            }.value
            guard loadedPath == path else { return }
            state = result
        } catch {
            guard loadedPath == path else { return }
            state = .error(error.localizedDescription)
        }
    }

    func reset() {
        state = .idle
        loadedPath = nil
    }

    private nonisolated static func readFile(at path: String) throws -> State {
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)

        let checkSize = min(data.count, 8192)
        let prefix = data.prefix(checkSize)
        if prefix.contains(0) {
            return .binary
        }

        guard let content = String(data: data, encoding: .utf8) else {
            return .binary
        }

        let lines = content.components(separatedBy: "\n")
        return .loaded(content: content, lines: lines)
    }
}
