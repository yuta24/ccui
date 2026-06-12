import AppKit

/// ターミナルの `NSView` を embed/remove し、リサイズアニメーション中に
/// frame を固定する（freeze/unfreeze）処理を集約する子 VC。
/// `AgentTerminalViewController`/`BottomTerminalViewController` から
/// 子 VC として利用される。
@MainActor
final class TerminalHostViewController: NSViewController {
    private(set) var embeddedSession: (any TerminalSession)?

    /// ターミナルを view 全体に追従させる制約。フリーズ中は無効化する。
    private var fillConstraints: [NSLayoutConstraint] = []
    private var isFrozen = false

    override func loadView() {
        view = NSView()
    }

    func embed(session: any TerminalSession) {
        let terminal = session.nsView
        if terminal.superview === view { return }
        remove()

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
    }

    func remove() {
        guard let session = embeddedSession else { return }
        unfreeze()
        fillConstraints = []
        session.nsView.removeFromSuperview()
        embeddedSession = nil
    }

    /// ターミナルの frame をその場で固定する。Auto Layout の制約を外し、
    /// 旧スタイルの autoresizing も無効化することで、コンテナの bounds が
    /// アニメーションで変化しても frame は一切変化しなくなる
    /// （座標系の flip 状態に依存しない）。はみ出した分は
    /// 親 view の masksToBounds でクリップされる。
    func freeze() {
        guard !isFrozen, let terminal = embeddedSession?.nsView, !fillConstraints.isEmpty else { return }
        isFrozen = true
        NSLayoutConstraint.deactivate(fillConstraints)
        terminal.translatesAutoresizingMaskIntoConstraints = true
        terminal.autoresizingMask = []
    }

    func unfreeze() {
        guard isFrozen else { return }
        isFrozen = false
        embeddedSession?.nsView.translatesAutoresizingMaskIntoConstraints = false
        guard !fillConstraints.isEmpty else { return }
        NSLayoutConstraint.activate(fillConstraints)
    }
}
