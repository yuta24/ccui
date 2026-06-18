import SwiftUI

@MainActor
final class AppDependencies {
    let eventBus: AppEventBus
    let appSettingsStore: AppSettingsStore
    let repositoryStore: RepositoryStore
    let terminalSessionStore: TerminalSessionStore
    let notificationService: NotificationService
    let claudeEventStore: ClaudeEventStore
    let worktreeSessionStore: WorktreeSessionStore
    let shellSessionStore: ShellSessionStore
    let navigationStore: NavigationStore
    let worktreeLifecycleCoordinator: WorktreeLifecycleCoordinator
    let detailUIState: DetailUIState
    let diffStore: DiffStore
    let quickOpenStore: QuickOpenStore
    let searchStore: SearchStore
    let bottomPanelState: BottomPanelState

    init() {
        let eventBus = AppEventBus()
        self.eventBus = eventBus
        let settingsStore = AppSettingsStore(persistence: JSONFileAppSettingsPersistence())
        self.appSettingsStore = settingsStore
        self.repositoryStore = RepositoryStore(persistence: JSONFileRepositoryPersistence())
        self.terminalSessionStore = TerminalSessionStore(appSettingsStore: settingsStore, eventBus: eventBus)
        let notificationService = NotificationService()
        self.notificationService = notificationService
        let claudeEventPersistence = ClaudeEventPersistence()
        self.claudeEventStore = ClaudeEventStore(
            persistence: claudeEventPersistence,
            notificationService: notificationService,
            eventBus: eventBus
        )
        self.worktreeSessionStore = WorktreeSessionStore(eventBus: eventBus)
        self.shellSessionStore = ShellSessionStore(appSettingsStore: settingsStore, eventBus: eventBus)
        self.navigationStore = NavigationStore(eventBus: eventBus)
        self.worktreeLifecycleCoordinator = WorktreeLifecycleCoordinator(eventBus: eventBus)
        self.detailUIState = DetailUIState()
        self.diffStore = DiffStore()
        self.quickOpenStore = QuickOpenStore()
        self.searchStore = SearchStore()
        self.bottomPanelState = BottomPanelState(eventBus: eventBus)

        let terminalStore = self.terminalSessionStore
        let shellStore = self.shellSessionStore
        settingsStore.onFontChanged = { [weak terminalStore, weak shellStore] in
            terminalStore?.updateAllFonts()
            shellStore?.updateAllFonts()
        }
    }

    func start() {
        claudeEventStore.start()
        terminalSessionStore.startResolvingClaudePath()
        Task { _ = await SearchToolLocator.shared.ripgrepPath() }
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
            .environment(navigationStore)
            .environment(worktreeLifecycleCoordinator)
            .environment(detailUIState)
            .environment(diffStore)
            .environment(quickOpenStore)
            .environment(searchStore)
            .environment(bottomPanelState)
    }
}
