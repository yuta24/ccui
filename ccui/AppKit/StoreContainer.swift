import SwiftUI

@MainActor
final class StoreContainer {
    let appSettingsStore: AppSettingsStore
    let repositoryStore: RepositoryStore
    let terminalSessionStore: TerminalSessionStore
    let notificationService: NotificationService
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
        let notificationService = NotificationService()
        self.notificationService = notificationService
        // ClaudeEventStore（書き込み）と SessionAnalyticsStore（読み取り）が
        // 同じ Coordinator を共有することで index.json の整合性を担保する。
        let persistenceCoordinator = ClaudeEventPersistenceCoordinator()
        self.claudeEventStore = ClaudeEventStore(
            coordinator: persistenceCoordinator,
            notificationService: notificationService
        )
        self.worktreeSessionStore = WorktreeSessionStore()
        self.shellSessionStore = ShellSessionStore(appSettingsStore: settingsStore)
        self.appCoordinator = AppCoordinator()
        self.detailUIState = DetailUIState(persistenceCoordinator: persistenceCoordinator)
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
