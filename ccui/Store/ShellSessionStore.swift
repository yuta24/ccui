import Foundation

@Observable
@MainActor
final class ShellSessionStore {
    private(set) var tabsByPath: [String: [ShellTab]] = [:]
    private var activeTabIDByPath: [String: UUID] = [:]
    private let appSettingsStore: AppSettingsStore

    init(appSettingsStore: AppSettingsStore, eventBus: AppEventBus) {
        self.appSettingsStore = appSettingsStore
        eventBus.subscribe { [weak self] event in
            self?.handle(event)
        }
    }

    private func handle(_ event: AppEvent) {
        switch event {
        case .worktreesSynced(let allWorktreePaths):
            removeExcept(paths: allWorktreePaths)
        case .worktreeRemoved(let path):
            removeAll(for: path)
        case .worktreesLoaded, .repositoriesRemoved:
            break
        }
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
        let tab = ShellTab(worktreePath: worktreePath, additionalEnvironment: appSettingsStore.resolvedEnvironmentStrings(), font: appSettingsStore.resolvedNSFont)
        tab.session.onProcessTerminated = { [weak self, weak tab] _ in
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
        guard var tabs = tabsByPath[worktreePath],
              let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        if tab.session.isProcessRunning {
            tab.session.terminate()
        }
        tabs.remove(at: index)

        if tabs.isEmpty {
            tabsByPath.removeValue(forKey: worktreePath)
            activeTabIDByPath.removeValue(forKey: worktreePath)
        } else {
            tabsByPath[worktreePath] = tabs
            if activeTabIDByPath[worktreePath] == id {
                let newIndex = min(index, tabs.count - 1)
                activeTabIDByPath[worktreePath] = tabs[newIndex].id
            }
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

    func updateAllFonts() {
        let font = appSettingsStore.resolvedNSFont
        for tabs in tabsByPath.values {
            for tab in tabs {
                tab.session.updateFont(font)
            }
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
