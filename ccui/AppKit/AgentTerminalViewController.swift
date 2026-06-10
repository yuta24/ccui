import AppKit

@MainActor
final class AgentTerminalViewController: NSViewController {
    private let terminalSessionStore: TerminalSessionStore
    private let bottomPanelState: BottomPanelState
    private var worktree: Worktree
    private var embeddedSession: (any TerminalSession)?
    private var isObserving = false
    /// observeSession の世代番号。worktree 切替時にインクリメントして、
    /// 旧 worktree に対する withObservationTracking の onChange が発火しても
    /// 古い世代の Task は guard で抜けるようにする（再帰的な多重観測を防ぐ）。
    private var observationGeneration = 0

    /// ターミナルを view 全体に追従させる制約。アニメーション中は無効化する。
    private var fillConstraints: [NSLayoutConstraint] = []
    private var isFrozen = false

    init(worktree: Worktree, terminalSessionStore: TerminalSessionStore, bottomPanelState: BottomPanelState) {
        self.worktree = worktree
        self.terminalSessionStore = terminalSessionStore
        self.bottomPanelState = bottomPanelState
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        // フリーズ中にターミナルが境界をはみ出した際にクリップする。
        // ターミナルの背景色と揃えることで、サイズ固定中にできる隙間も目立たなくする。
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        container.layer?.masksToBounds = true
        view = container
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        updateTerminal()
        if !isObserving {
            isObserving = true
            observeSession()
            observeBottomPanelResize()
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

    /// ボトムパネルやブラウザパネルの開閉アニメーション中はエージェントターミナルの
    /// サイズを固定し、アニメーション完了後に一度だけ実サイズへ追従させる。
    /// これにより、アニメーション中に何度も resize(cols:rows:) が呼ばれて
    /// SIGWINCH による全画面再描画が連発しカクつくのを防ぐ。
    private func observeBottomPanelResize() {
        withObservationTracking {
            _ = bottomPanelState.isAnimatingResize
        } onChange: {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.bottomPanelState.isAnimatingResize {
                    self.freezeSize()
                } else {
                    self.unfreezeSize()
                }
                self.observeBottomPanelResize()
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
        fillConstraints = [
            terminal.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminal.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminal.topAnchor.constraint(equalTo: view.topAnchor),
            terminal.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]
        NSLayoutConstraint.activate(fillConstraints)
        // Force full refresh after re-parenting so stale content is redrawn.
        session.refreshDisplay()
        embeddedSession = session
        // アニメーション中に worktree 切替やセッション切り替えで再 embed された場合、
        // observeBottomPanelResize の onChange は isAnimatingResize の値が変化しない
        // 限り発火しないため、ここで明示的にフリーズを適用する。
        if bottomPanelState.isAnimatingResize {
            freezeSize()
        }
    }

    private func removeCurrentTerminal() {
        guard let session = embeddedSession else { return }
        unfreezeSize()
        fillConstraints = []
        session.nsView.removeFromSuperview()
        embeddedSession = nil
    }

    // MARK: - Resize Freeze

    /// ターミナルの frame をその場で固定する。Auto Layout の制約を外し、
    /// 旧スタイルの autoresizing も無効化することで、コンテナの bounds が
    /// アニメーションで変化しても frame は一切変化しなくなる
    /// （座標系の flip 状態に依存しない）。はみ出した分は
    /// コンテナの masksToBounds でクリップされる。
    private func freezeSize() {
        guard !isFrozen, let terminal = embeddedSession?.nsView, !fillConstraints.isEmpty else { return }
        isFrozen = true
        NSLayoutConstraint.deactivate(fillConstraints)
        terminal.translatesAutoresizingMaskIntoConstraints = true
        terminal.autoresizingMask = []
    }

    private func unfreezeSize() {
        guard isFrozen else { return }
        isFrozen = false
        embeddedSession?.nsView.translatesAutoresizingMaskIntoConstraints = false
        guard !fillConstraints.isEmpty else { return }
        NSLayoutConstraint.activate(fillConstraints)
    }
}
