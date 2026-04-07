import AppKit

final class ContentViewController: NSViewController {
    private let placeholderLabel = NSTextField(labelWithString: "Select a repository")
    private let tabView = NSTabView()

    private var terminalPlaceholder: TerminalPlaceholderViewController?
    private var codeViewerPlaceholder: CodeViewerPlaceholderViewController?
    private var diffViewerPlaceholder: DiffViewerPlaceholderViewController?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupPlaceholder()
    }

    private func setupPlaceholder() {
        placeholderLabel.font = .systemFont(ofSize: 18, weight: .light)
        placeholderLabel.textColor = .tertiaryLabelColor
        placeholderLabel.alignment = .center
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            placeholderLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }

    func showRepository(_ repo: Repository) {
        placeholderLabel.isHidden = true
        setupContentTabs(for: repo)
    }

    private func setupContentTabs(for repo: Repository) {
        tabView.translatesAutoresizingMaskIntoConstraints = false

        if tabView.superview == nil {
            view.addSubview(tabView)
            NSLayoutConstraint.activate([
                tabView.topAnchor.constraint(equalTo: view.topAnchor),
                tabView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                tabView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                tabView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        }

        while tabView.numberOfTabViewItems > 0 {
            tabView.removeTabViewItem(tabView.tabViewItem(at: 0))
        }

        let terminalVC = TerminalPlaceholderViewController()
        let terminalTab = NSTabViewItem(viewController: terminalVC)
        terminalTab.label = "Terminal"

        let codeVC = CodeViewerPlaceholderViewController()
        let codeTab = NSTabViewItem(viewController: codeVC)
        codeTab.label = "Code"

        let diffVC = DiffViewerPlaceholderViewController()
        let diffTab = NSTabViewItem(viewController: diffVC)
        diffTab.label = "Diff"

        tabView.addTabViewItem(terminalTab)
        tabView.addTabViewItem(codeTab)
        tabView.addTabViewItem(diffTab)
    }
}
