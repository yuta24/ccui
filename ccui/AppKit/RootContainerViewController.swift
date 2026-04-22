import SwiftUI

@MainActor
final class RootContainerViewController: NSViewController {
    private let stores: StoreContainer
    private var keyMonitor: Any?
    private var isShowingSheet = false
    private var isShowingAlert = false
    private var presentedSheetVC: NSViewController?
    private var isObserving = false

    init(stores: StoreContainer) {
        self.stores = stores
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.surfaceWindowColor.cgColor

        let titleBarHeight: CGFloat = PanelMetrics.titleBarHeight
        let edgeInset = PanelMetrics.windowEdgeInset

        let splitVC = MainSplitViewController(stores: stores)
        addChild(splitVC)
        splitVC.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(splitVC.view)

        NSLayoutConstraint.activate([
            splitVC.view.topAnchor.constraint(equalTo: container.topAnchor, constant: titleBarHeight),
            splitVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: edgeInset),
            splitVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -edgeInset),
            splitVC.view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -edgeInset),
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
            _ = stores.appCoordinator.showingAddWorktree
            _ = stores.detailUIState.showingConfiguration
        } onChange: {
            Task { @MainActor [weak self] in
                self?.handleSheetStateChanged()
                self?.observeSheetState()
            }
        }
    }

    private func handleSheetStateChanged() {
        // Present AddWorktree sheet
        if let wtStore = stores.appCoordinator.showingAddWorktree, !isShowingSheet {
            presentAddWorktreeSheet(wtStore: wtStore)
            return
        }

        // Present Configuration sheet
        if stores.detailUIState.showingConfiguration,
           let worktree = stores.appCoordinator.selectedWorktree,
           !isShowingSheet {
            presentConfigurationSheet(worktree: worktree)
            return
        }

        // Dismiss if state says closed
        if stores.appCoordinator.showingAddWorktree == nil && !stores.detailUIState.showingConfiguration && isShowingSheet {
            dismissSheet()
        }
    }

    private func presentAddWorktreeSheet(wtStore: WorktreeStore) {
        let sheetView = stores.injectEnvironment(into:
            AddWorktreeView(
                worktreeStore: wtStore,
                repositoryPath: wtStore.repositoryPath,
                initialBaseBranch: stores.appCoordinator.initialBaseBranch
            )
        )
        .preferredColorScheme(.dark)

        let hostingVC = NSHostingController(rootView: sheetView)
        isShowingSheet = true
        presentedSheetVC = hostingVC
        presentAsSheet(hostingVC)
    }

    private func presentConfigurationSheet(worktree: Worktree) {
        let repoPath = stores.appCoordinator.worktreeStores[worktree.repositoryID]?.repositoryPath ?? worktree.path
        let sheetView = stores.injectEnvironment(into:
            ConfigurationSheet(
                worktreePath: worktree.path,
                repositoryPath: repoPath,
                isPresented: Binding(
                    get: { [weak self] in self?.stores.detailUIState.showingConfiguration ?? false },
                    set: { [weak self] in self?.stores.detailUIState.showingConfiguration = $0 }
                )
            )
        )
        .preferredColorScheme(.dark)

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
        if stores.appCoordinator.showingAddWorktree != nil {
            stores.appCoordinator.showingAddWorktree = nil
        }
        if stores.detailUIState.showingConfiguration {
            stores.detailUIState.showingConfiguration = false
        }
    }

    // MARK: - Alert Observation

    private func observeAlertState() {
        withObservationTracking {
            _ = stores.appCoordinator.showForceDeleteAlert
            _ = stores.appCoordinator.showErrorAlert
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
        if stores.appCoordinator.showForceDeleteAlert {
            showForceDeleteAlert()
        } else if stores.appCoordinator.showErrorAlert {
            showCoordinatorErrorAlert()
        } else if stores.repositoryStore.lastError != nil {
            showStoreErrorAlert()
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

        stores.appCoordinator.showForceDeleteAlert = false
        isShowingAlert = true

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self else { return }
            self.isShowingAlert = false
            if response == .alertFirstButtonReturn {
                self.stores.appCoordinator.forceDeleteWorktree(
                    terminalSessionStore: self.stores.terminalSessionStore,
                    shellSessionStore: self.stores.shellSessionStore,
                    bottomPanelState: self.stores.bottomPanelState
                )
            } else {
                self.stores.appCoordinator.forceDeleteTarget = nil
            }
        }
    }

    private func showCoordinatorErrorAlert() {
        guard let window = view.window else { return }
        let message = stores.appCoordinator.errorMessage ?? "An unknown error occurred."
        stores.appCoordinator.showErrorAlert = false
        stores.appCoordinator.errorMessage = nil
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
        let coordinator = stores.appCoordinator
        let sessionComparisonStore = stores.sessionComparisonStore

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let chars = event.charactersIgnoringModifiers?.lowercased() ?? ""
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+Shift+E → toggle Agent/Files mode
            if chars == "e" && mods.contains(.command) && mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                detailUIState.contentMode = detailUIState.contentMode == .agent ? .files : .agent
                return nil
            }

            // Cmd+I → toggle Right Panel (Agent mode only)
            if chars == "i" && mods.contains(.command) && !mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                guard detailUIState.contentMode == .agent else { return event }
                detailUIState.isRightPanelVisible.toggle()
                return nil
            }

            // Cmd+Shift+F → content search (switch to Files mode) — check before Cmd+F
            if chars == "f" && mods.contains(.command) && mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .content)
                return nil
            }

            // Cmd+F → file search (switch to Files mode)
            if chars == "f" && mods.contains(.command) && !mods.contains(.shift) {
                guard coordinator.selectedWorktree != nil else { return event }
                quickOpenStore.close()
                detailUIState.contentMode = .files
                searchStore.activate(mode: .files)
                return nil
            }

            // Cmd+P → quick open
            if chars == "p" && mods.contains(.command) {
                guard coordinator.selectedWorktree != nil else { return event }
                if !quickOpenStore.isVisible {
                    searchStore.deactivate()
                    quickOpenStore.open()
                }
                return nil
            }

            // Esc
            if event.keyCode == 53 {
                if sessionComparisonStore.isVisible {
                    sessionComparisonStore.close()
                    return nil
                }
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
