import SwiftUI

@MainActor
final class BottomTerminalViewController: NSViewController {
    private static let tabBarHeight: CGFloat = 32
    private static let separatorHeight: CGFloat = 1
    static let collapsedHeight: CGFloat = tabBarHeight + separatorHeight + PanelMetrics.panelGap * 2

    private let stores: StoreContainer
    private let bottomPanelState: BottomPanelState
    private let terminalContainer = NSView()
    private var embeddedSession: (any TerminalSession)?
    private var emptyStateVC: NSHostingController<AnyView>?
    private var isObserving = false

    init(stores: StoreContainer, bottomPanelState: BottomPanelState) {
        self.stores = stores
        self.bottomPanelState = bottomPanelState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let (outer, panel) = PanelMetrics.makeFloatingPanel()

        // Tab bar (SwiftUI, fixed 32px)
        let tabBarView = stores.injectEnvironment(into: BottomTerminalTabBarView())
            .environment(bottomPanelState)
            .preferredColorScheme(.dark)
        let tabBarVC = NSHostingController(rootView: tabBarView)
        addChild(tabBarVC)
        tabBarVC.view.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(tabBarVC.view)

        // Separator
        let separator = SeparatorView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(separator)

        // Terminal container (AppKit, fills remaining space)
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(terminalContainer)

        NSLayoutConstraint.activate([
            tabBarVC.view.topAnchor.constraint(equalTo: panel.topAnchor),
            tabBarVC.view.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            tabBarVC.view.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            tabBarVC.view.heightAnchor.constraint(equalToConstant: Self.tabBarHeight),

            separator.topAnchor.constraint(equalTo: tabBarVC.view.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight),

            terminalContainer.topAnchor.constraint(equalTo: separator.bottomAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])

        view = outer
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateTerminal()
        if !isObserving {
            isObserving = true
            observeTerminalState()
        }
    }

    // MARK: - State Observation

    private func observeTerminalState() {
        withObservationTracking {
            _ = bottomPanelState.isExpanded
            if let wt = stores.appCoordinator.selectedWorktree {
                _ = stores.shellSessionStore.tabs(for: wt.path)
                _ = stores.shellSessionStore.activeTabID(for: wt.path)
            } else {
                _ = stores.appCoordinator.selectedWorktree
            }
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateTerminal()
                self?.observeTerminalState()
            }
        }
    }

    private func updateTerminal() {
        guard bottomPanelState.isExpanded,
              let worktree = stores.appCoordinator.selectedWorktree else {
            removeCurrentTerminal()
            removeEmptyState()
            return
        }

        let worktreePath = worktree.path
        let activeTab = stores.shellSessionStore.activeTab(for: worktreePath)

        if let tab = activeTab {
            removeEmptyState()
            embedTerminal(session: tab.session)
        } else {
            removeCurrentTerminal()
            let hasTabs = !stores.shellSessionStore.tabs(for: worktreePath).isEmpty
            if !hasTabs {
                showEmptyState(worktreePath: worktreePath)
            } else {
                removeEmptyState()
            }
        }
    }

    // MARK: - Terminal Embedding

    private func embedTerminal(session: any TerminalSession) {
        let terminal = session.nsView
        if terminal.superview === terminalContainer { return }
        removeCurrentTerminal()

        terminal.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: terminalContainer.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: terminalContainer.bottomAnchor),
        ])
        session.refreshDisplay()
        embeddedSession = session
    }

    private func removeCurrentTerminal() {
        guard let session = embeddedSession else { return }
        session.nsView.removeFromSuperview()
        embeddedSession = nil
    }

    // MARK: - Empty State

    private func showEmptyState(worktreePath: String) {
        guard emptyStateVC == nil else { return }
        let emptyView = AnyView(
            VStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 24))
                    .foregroundStyle(Color.textTertiary)
                Button {
                    self.stores.shellSessionStore.addTab(for: worktreePath)
                } label: {
                    Text("New Terminal")
                        .font(.uiCaption)
                        .foregroundStyle(Color.surfaceBase)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .preferredColorScheme(.dark)
        )
        let vc = NSHostingController(rootView: emptyView)
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        terminalContainer.addSubview(vc.view)
        NSLayoutConstraint.activate([
            vc.view.leadingAnchor.constraint(equalTo: terminalContainer.leadingAnchor),
            vc.view.trailingAnchor.constraint(equalTo: terminalContainer.trailingAnchor),
            vc.view.topAnchor.constraint(equalTo: terminalContainer.topAnchor),
            vc.view.bottomAnchor.constraint(equalTo: terminalContainer.bottomAnchor),
        ])
        emptyStateVC = vc
    }

    private func removeEmptyState() {
        guard let vc = emptyStateVC else { return }
        vc.view.removeFromSuperview()
        vc.removeFromParent()
        emptyStateVC = nil
    }
}

// MARK: - Separator View

private class SeparatorView: NSView {
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateLayer() {
        layer?.backgroundColor = NSColor.separatorColor.cgColor
    }
}
