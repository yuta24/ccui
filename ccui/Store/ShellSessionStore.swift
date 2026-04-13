import Foundation

@Observable
@MainActor
final class ShellSessionStore {
    private(set) var tabsByPath: [String: [ShellTab]] = [:]
    private var activeTabIDByPath: [String: UUID] = [:]
    private let appSettingsStore: AppSettingsStore

    init(appSettingsStore: AppSettingsStore) {
        self.appSettingsStore = appSettingsStore
    }

    func tabs(for worktreePath: String) -> [ShellTab] {
        tabsByPath[worktreePath] ?? []
    }

    func activeTabID(for worktreePath: String) -> UUID? {
        activeTabIDByPath[worktreePath]
    }

    func activeTab(for worktreePath: String) -> ShellTab? {
        guard let id = activeTabIDByPath[worktreePath] else { return nil }
        return tabsByPath[worktreePath]?.first(where: { $0.id == id })
    }

    @discardableResult
    func addTab(for worktreePath: String) -> ShellTab {
        let tab = ShellTab(worktreePath: worktreePath, additionalEnvironment: appSettingsStore.resolvedEnvironmentStrings())
        tab.session.onProcessTerminated = { [weak self, weak tab] in
            guard let self, let tab else { return }
            self.closeTab(id: tab.id, worktreePath: worktreePath)
        }
        tabsByPath[worktreePath, default: []].append(tab)
        activeTabIDByPath[worktreePath] = tab.id
        return tab
    }

    func setActiveTab(id: UUID, worktreePath: String) {
        activeTabIDByPath[worktreePath] = id
    }

    func closeTab(id: UUID, worktreePath: String) {
        guard let index = tabsByPath[worktreePath]?.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabsByPath[worktreePath]![index]
        if tab.session.isProcessRunning {
            tab.session.terminate()
        }
        tabsByPath[worktreePath]!.remove(at: index)

        if tabsByPath[worktreePath]!.isEmpty {
            tabsByPath.removeValue(forKey: worktreePath)
            activeTabIDByPath.removeValue(forKey: worktreePath)
        } else if activeTabIDByPath[worktreePath] == id {
            let newIndex = min(index, tabsByPath[worktreePath]!.count - 1)
            activeTabIDByPath[worktreePath] = tabsByPath[worktreePath]![newIndex].id
        }
    }

    func removeAll(for worktreePath: String) {
        guard let tabs = tabsByPath.removeValue(forKey: worktreePath) else { return }
        activeTabIDByPath.removeValue(forKey: worktreePath)
        for tab in tabs {
            tab.session.terminate()
        }
    }

    func removeExcept(paths: Set<String>) {
        let toRemove = tabsByPath.keys.filter { !paths.contains($0) }
        for path in toRemove {
            removeAll(for: path)
        }
    }

    func terminateAll() {
        for tabs in tabsByPath.values {
            for tab in tabs {
                tab.session.terminate()
            }
        }
        tabsByPath.removeAll()
        activeTabIDByPath.removeAll()
    }
}
