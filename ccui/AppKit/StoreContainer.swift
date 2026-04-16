import SwiftUI

@MainActor
final class StoreContainer {
    let appSettingsStore: AppSettingsStore
    let repositoryStore: RepositoryStore
    let terminalSessionStore: TerminalSessionStore
    let claudeEventStore: ClaudeEventStore
    let worktreeSessionStore: WorktreeSessionStore
    let shellSessionStore: ShellSessionStore
    let appCoordinator: AppCoordinator
    let detailUIState: DetailUIState
    let sessionComparisonStore: SessionComparisonStore
    let diffStore: DiffStore

    init() {
        let settingsStore = AppSettingsStore(persistence: JSONFileAppSettingsPersistence())
        self.appSettingsStore = settingsStore
        self.repositoryStore = RepositoryStore(persistence: JSONFileRepositoryPersistence())
        self.terminalSessionStore = TerminalSessionStore(appSettingsStore: settingsStore)
        self.claudeEventStore = ClaudeEventStore()
        self.worktreeSessionStore = WorktreeSessionStore()
        self.shellSessionStore = ShellSessionStore(appSettingsStore: settingsStore)
        self.appCoordinator = AppCoordinator()
        self.detailUIState = DetailUIState()
        self.sessionComparisonStore = SessionComparisonStore()
        self.diffStore = DiffStore()
    }

    func start() {
        claudeEventStore.start()
        terminalSessionStore.startResolvingClaudePath()
    }

    func shutdown() {
        terminalSessionStore.terminateAll()
        shellSessionStore.terminateAll()
        claudeEventStore.stop()
        worktreeSessionStore.save()
    }

    func injectEnvironment<V: View>(into view: V) -> some View {
        view
            .environment(appSettingsStore)
            .environment(repositoryStore)
            .environment(terminalSessionStore)
            .environment(claudeEventStore)
            .environment(worktreeSessionStore)
            .environment(shellSessionStore)
            .environment(appCoordinator)
            .environment(detailUIState)
            .environment(sessionComparisonStore)
            .environment(diffStore)
    }
}
