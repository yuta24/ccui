import SwiftUI

@MainActor
final class RootContainerViewController: NSViewController {
    private let stores: AppDependencies
    private var keyMonitor: Any?
    private var isShowingSheet = false
    private var isShowingAlert = false
    private var presentedSheetVC: NSViewController?
    private var isObserving = false

    init(stores: AppDependencies) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()

        let mainContentView = stores.injectEnvironment(into: MainContentView(stores: stores))
        let hostingVC = NSHostingController(rootView: mainContentView)
        addChild(hostingVC)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(hostingVC.view)

        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        installKeyMonitor()
        if !isObserving {
            isObserving = true
            observeSheetState()
            observeAlertState()
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Sheet Observation

    private func observeSheetState() {
        withObservationTracking {
            _ = stores.worktreeLifecycleCoordinator.showingAddWorktree
            _ = stores.detailUIState.isConfigurationSheetPresented
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleSheetStateChanged()
                self?.observeSheetState()
            }
        }
    }

    private func handleSheetStateChanged() {
        // Present AddWorktree sheet
        if let wtStore = stores.worktreeLifecycleCoordinator.showingAddWorktree, !isShowingSheet {
            presentAddWorktreeSheet(wtStore: wtStore)
            return
        }

        // Present Configuration sheet
        if stores.detailUIState.isConfigurationSheetPresented,
           let worktree = stores.navigationStore.selectedWorktree,
           !isShowingSheet {
            presentConfigurationSheet(worktree: worktree)
            return
        }

        // Dismiss if state says closed
        if stores.worktreeLifecycleCoordinator.showingAddWorktree == nil && !stores.detailUIState.isConfigurationSheetPresented && isShowingSheet {
            dismissSheet()
        }
    }

    private func presentAddWorktreeSheet(wtStore: WorktreeStore) {
        let sheetView = stores.injectEnvironment(into:
            AddWorktreeView(
                worktreeStore: wtStore,
                repositoryPath: wtStore.repositoryPath,
                initialBaseBranch: stores.worktreeLifecycleCoordinator.initialBaseBranch
            )
        )

        let hostingVC = NSHostingController(rootView: sheetView)
        isShowingSheet = true
        presentedSheetVC = hostingVC
        presentAsSheet(hostingVC)
    }

    private func presentConfigurationSheet(worktree: Worktree) {
        let repoPath = stores.worktreeLifecycleCoordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
        let sheetView = stores.injectEnvironment(into:
            ConfigurationSheet(
                worktreePath: worktree.path,
                repositoryPath: repoPath,
                isPresented: Binding(
                    get: { [weak self] in self?.stores.detailUIState.isConfigurationSheetPresented ?? false },
                    set: { [weak self] in self?.stores.detailUIState.isConfigurationSheetPresented = $0 }
                )
            )
        )

        let hostingVC = NSHostingController(rootView: sheetView)
        isShowingSheet = true
        presentedSheetVC = hostingVC
        presentAsSheet(hostingVC)
    }

    private var isDismissingProgrammatically = false

    private func dismissSheet() {
        guard let presented = presentedSheetVC else {
            isShowingSheet = false
            return
        }
        isDismissingProgrammatically = true
        dismiss(presented)
        isDismissingProgrammatically = false
        isShowingSheet = false
        presentedSheetVC = nil
    }

    override func dismiss(_ viewController: NSViewController) {
        super.dismiss(viewController)
        // Only clean up state when dismissing our sheet (not child VCs)
        guard viewController === presentedSheetVC else { return }
        isShowingSheet = false
        presentedSheetVC = nil
        // Clean up state when sheet is dismissed by user (e.g. Esc key),
        // but skip when we're dismissing programmatically (state already correct)
        guard !isDismissingProgrammatically else { return }
        if stores.worktreeLifecycleCoordinator.showingAddWorktree != nil {
            stores.worktreeLifecycleCoordinator.showingAddWorktree = nil
        }
        if stores.detailUIState.isConfigurationSheetPresented {
            stores.detailUIState.isConfigurationSheetPresented = false
        }
    }

    // MARK: - Alert Observation

    private func observeAlertState() {
        withObservationTracking {
            _ = stores.worktreeLifecycleCoordinator.isForceDeleteAlertPresented
            _ = stores.worktreeLifecycleCoordinator.isRemoveRepositoryAlertPresented
            _ = stores.worktreeLifecycleCoordinator.isErrorAlertPresented
            _ = stores.repositoryStore.lastError
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleAlertStateChanged()
                self?.observeAlertState()
            }
        }
    }

    private func handleAlertStateChanged() {
        guard !isShowingAlert else { return }
        if stores.worktreeLifecycleCoordinator.isForceDeleteAlertPresented {
            showForceDeleteAlert()
        } else if stores.worktreeLifecycleCoordinator.isRemoveRepositoryAlertPresented {
            showRemoveRepositoryAlert()
        } else if stores.worktreeLifecycleCoordinator.isErrorAlertPresented {
            showCoordinatorErrorAlert()
        } else if stores.repositoryStore.lastError != nil {
            showStoreErrorAlert()
        }
    }

    private func showRemoveRepositoryAlert() {
        guard let window = view.window else { return }
        guard let (repository, _) = stores.worktreeLifecycleCoordinator.removeRepositoryTarget else { return }
        let alert = NSAlert()
        alert.messageText = "Remove Repository"
        alert.informativeText = "Are you sure you want to remove \"\(repository.name)\" from the sidebar? The repository files on disk will not be deleted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")

        stores.worktreeLifecycleCoordinator.isRemoveRepositoryAlertPresented = false
        isShowingAlert = true

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.isShowingAlert = false
            if response == .alertFirstButtonReturn {
                self.stores.worktreeLifecycleCoordinator.executeRemoveRepository()
            } else {
                self.stores.worktreeLifecycleCoordinator.removeRepositoryTarget = nil
            }
        }
    }

    private func showForceDeleteAlert() {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = "Uncommitted Changes"
        alert.informativeText = "This worktree has uncommitted changes. Force delete will discard them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Force Delete")
        alert.addButton(withTitle: "Cancel")

        stores.worktreeLifecycleCoordinator.isForceDeleteAlertPresented = false
        isShowingAlert = true

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.isShowingAlert = false
            if response == .alertFirstButtonReturn {
                self.stores.worktreeLifecycleCoordinator.forceDeleteWorktree()
            } else {
                self.stores.worktreeLifecycleCoordinator.forceDeleteTarget = nil
            }
        }
    }

    private func showCoordinatorErrorAlert() {
        guard let window = view.window else { return }
        let message = stores.worktreeLifecycleCoordinator.errorMessage ?? "An unknown error occurred."
        stores.worktreeLifecycleCoordinator.isErrorAlertPresented = false
        stores.worktreeLifecycleCoordinator.errorMessage = nil
        isShowingAlert = true

        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { [weak self] _ in
            self?.isShowingAlert = false
        }
    }

    private func showStoreErrorAlert() {
        guard let window = view.window else { return }
        let message = stores.repositoryStore.lastError ?? "An unknown error occurred."
        stores.repositoryStore.clearError()
        isShowingAlert = true

        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window) { [weak self] _ in
            self?.isShowingAlert = false
        }
    }

    // MARK: - Keyboard Shortcuts

    private func installKeyMonitor() {
        if let existing = keyMonitor {
            NSEvent.removeMonitor(existing)
            keyMonitor = nil
        }

        let detailUIState = stores.detailUIState
        let quickOpenStore = stores.quickOpenStore
        let searchStore = stores.searchStore
        let navigationStore = stores.navigationStore
        let terminalSessionStore = stores.terminalSessionStore
        let shellSessionStore = stores.shellSessionStore
        let bottomPanelState = stores.bottomPanelState

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+Shift+E → toggle Agent/Files mode
            if chars == "e" && mods.contains(.command) && mods.contains(.shift) {
                guard navigationStore.selectedWorktree != nil else { return event }
                detailUIState.contentMode = detailUIState.contentMode == .agent ? .files : .agent
                return nil
            }

            // Cmd+U → toggle WebView split (Agent mode only)
            if chars == "u" && mods.contains(.command) && !mods.contains(.shift) {
                guard navigationStore.selectedWorktree != nil else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                detailUIState.agentLayoutMode = detailUIState.agentLayoutMode == .full ? .split : .full
                return nil
            }

            // Cmd+I → toggle Right Panel (Agent mode only)
            if chars == "i" && mods.contains(.command) && !mods.contains(.shift) {
                guard navigationStore.selectedWorktree != nil else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                detailUIState.isRightPanelVisible.toggle()
                return nil
            }

            // Cmd+T → new terminal tab in bottom panel (Agent mode only)
            if chars == "t" && mods.contains(.command) && !mods.contains(.shift) {
                guard let worktree = navigationStore.selectedWorktree else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                let isFirst = shellSessionStore.tabs(for: worktree.path).isEmpty
                shellSessionStore.addTab(for: worktree.path)
                if isFirst {
                    bottomPanelState.setExpanded(true, for: worktree.path)
                }
                return nil
            }

            // Cmd+K → clear active terminal tab output (Agent mode only)
            if chars == "k" && mods.contains(.command) && !mods.contains(.shift) {
                guard let worktree = navigationStore.selectedWorktree else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                shellSessionStore.activeTab(for: worktree.path)?.session.clearScreen()
                return nil
            }

            // Cmd+J → toggle bottom terminal panel (Agent mode only)
            if chars == "j" && mods.contains(.command) && !mods.contains(.shift) {
                guard let worktree = navigationStore.selectedWorktree else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                bottomPanelState.toggle(for: worktree.path)
                return nil
            }

            // Cmd+Shift+F → content search (switch to Files mode) — check before Cmd+F
            if chars == "f" && mods.contains(.command) && mods.contains(.shift) {
                guard navigationStore.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .content)
                return nil
            }

            // Cmd+F → Agent mode: ターミナルの内蔵Findバーを表示 / Files mode: ファイル名検索
            if chars == "f" && mods.contains(.command) && !mods.contains(.shift) {
                guard let worktree = navigationStore.selectedWorktree else { return event }
                if detailUIState.contentMode == .agent {
                    terminalSessionStore.session(for: worktree)?.showFindBar()
                    return nil
                }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .files)
                return nil
            }

            // Cmd+P → quick open
            if chars == "p" && mods.contains(.command) {
                guard navigationStore.selectedWorktree != nil else { return event }
                if !quickOpenStore.isVisible {
                    searchStore.deactivate()
                    quickOpenStore.open()
                }
                return nil
            }

            // Esc
            if event.keyCode == 53 {
                if quickOpenStore.isVisible {
                    quickOpenStore.close()
                    return nil
                }
                if searchStore.isActive {
                    searchStore.deactivate()
                    return nil
                }
            }

            return event
        }
    }
}
