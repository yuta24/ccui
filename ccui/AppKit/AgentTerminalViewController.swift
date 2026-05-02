import AppKit

@MainActor
final class AgentTerminalViewController: NSViewController {
    private let terminalSessionStore: TerminalSessionStore
    private var worktree: Worktree
    private var embeddedSession: (any TerminalSession)?
    private var isObserving = false
    /// observeSession の世代番号。worktree 切替時にインクリメントして、
    /// 旧 worktree に対する withObservationTracking の onChange が発火しても
    /// 古い世代の Task は guard で抜けるようにする（再帰的な多重観測を防ぐ）。
    private var observationGeneration = 0

    init(worktree: Worktree, terminalSessionStore: TerminalSessionStore) {
        self.worktree = worktree
        self.terminalSessionStore = terminalSessionStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateTerminal()
        if !isObserving {
            isObserving = true
            observeSession()
        }
    }

    func update(worktree: Worktree) {
        guard self.worktree != worktree else { return }
        self.worktree = worktree
        updateTerminal()
        // 旧 worktree に対して張られた observation は新 worktree のセッション変化を
        // 検知できないため、新しい worktree で再登録する。古い tracking の onChange は
        // observationGeneration の比較で抜けるようにし、多重観測の指数増加を防ぐ。
        if isObserving {
            observationGeneration &+= 1
            observeSession()
        }
    }

    // MARK: - Observation

    private func observeSession() {
        let generation = observationGeneration
        withObservationTracking {
            _ = terminalSessionStore.session(for: worktree)
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self, self.observationGeneration == generation else { return }
                self.updateTerminal()
                self.observeSession()
            }
        }
    }

    private func updateTerminal() {
        guard let session = terminalSessionStore.session(for: worktree) else {
            removeCurrentTerminal()
            return
        }
        embedTerminal(session: session)
    }

    // MARK: - Terminal Embedding

    private func embedTerminal(session: any TerminalSession) {
        let terminal = session.nsView
        if terminal.superview === view { return }
        removeCurrentTerminal()

        // Use Auto Layout to avoid setting frame to .zero on the terminal view.
        // Setting frame to .zero triggers processSizeChange → terminal.resize(cols: 2, rows: 1)
        // which sends SIGWINCH to the child process, causing unnecessary full redraws.
        terminal.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(terminal)
        NSLayoutConstraint.activate([
            terminal.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: view.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        // Force full refresh after re-parenting so stale content is redrawn.
        session.refreshDisplay()
        embeddedSession = session
    }

    private func removeCurrentTerminal() {
        guard let session = embeddedSession else { return }
        session.nsView.removeFromSuperview()
        embeddedSession = nil
    }
}
