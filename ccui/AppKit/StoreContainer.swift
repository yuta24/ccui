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
    let quickOpenStore: QuickOpenStore
    let searchStore: SearchStore
    let bottomPanelState: BottomPanelState

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
        self.quickOpenStore = QuickOpenStore()
        self.searchStore = SearchStore()
        self.bottomPanelState = BottomPanelState()
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
            .environment(quickOpenStore)
            .environment(searchStore)
            .environment(bottomPanelState)
    }
}
