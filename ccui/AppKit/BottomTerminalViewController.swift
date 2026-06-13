import SwiftUI

@MainActor
final class BottomTerminalViewController: NSViewController {
    private static let tabBarHeight: CGFloat = 32
    private static let separatorHeight: CGFloat = 1
    static let collapsedHeight: CGFloat = tabBarHeight + separatorHeight + PanelMetrics.panelGap * 2

    private let stores: AppDependencies
    private let bottomPanelState: BottomPanelState
    private let terminalHost = TerminalHostViewController()
    private var emptyStateVC: NSHostingController<AnyView>?
    private var isObserving = false

    init(stores: AppDependencies, bottomPanelState: BottomPanelState) {
        self.stores = stores
        self.bottomPanelState = bottomPanelState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()

        // Tab bar (SwiftUI, fixed 32px)
        let tabBarView = stores.injectEnvironment(into: BottomTerminalTabBarView())
            .environment(bottomPanelState)
        let tabBarVC = NSHostingController(rootView: tabBarView)
        addChild(tabBarVC)
        tabBarVC.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(tabBarVC.view)

        // Separator
        let separator = SeparatorView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(separator)

        // Terminal container (AppKit, fills remaining space)
        addChild(terminalHost)
        let terminalContainer = terminalHost.view
        terminalContainer.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(terminalContainer)

        NSLayoutConstraint.activate([
            tabBarVC.view.topAnchor.constraint(equalTo: container.topAnchor),
            tabBarVC.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabBarVC.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabBarVC.view.heightAnchor.constraint(equalToConstant: Self.tabBarHeight),

            separator.topAnchor.constraint(equalTo: tabBarVC.view.bottomAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: Self.separatorHeight),

            terminalContainer.topAnchor.constraint(equalTo: separator.bottomAnchor),
            terminalContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            terminalContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            terminalContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
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
            if let wt = stores.navigationStore.selectedWorktree {
                _ = bottomPanelState.isExpanded(for: wt.path)
                _ = stores.shellSessionStore.tabs(for: wt.path)
                _ = stores.shellSessionStore.activeTabID(for: wt.path)
            } else {
                _ = stores.navigationStore.selectedWorktree
            }
        } onChange: {
            Task { @MainActor [weak self] in
                self?.updateTerminal()
                self?.observeTerminalState()
            }
        }
    }

    private func updateTerminal() {
        guard let worktree = stores.navigationStore.selectedWorktree,
              bottomPanelState.isExpanded(for: worktree.path) else {
            terminalHost.remove()
            removeEmptyState()
            return
        }

        let worktreePath = worktree.path
        let activeTab = stores.shellSessionStore.activeTab(for: worktreePath)

        if let tab = activeTab {
            removeEmptyState()
            terminalHost.embed(session: tab.session)
        } else {
            terminalHost.remove()
            let hasTabs = !stores.shellSessionStore.tabs(for: worktreePath).isEmpty
            if !hasTabs {
                showEmptyState(worktreePath: worktreePath)
            } else {
                removeEmptyState()
            }
        }
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
                        .foregroundStyle(Color.textInverted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.surfacePrimary)
        )
        let vc = NSHostingController(rootView: emptyView)
        addChild(vc)
        vc.view.translatesAutoresizingMaskIntoConstraints = false
        let terminalContainer = terminalHost.view
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
