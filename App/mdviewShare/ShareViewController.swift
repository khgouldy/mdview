import MDCore
import SwiftUI
import UIKit

/// The share extension's principal class. It shows the reader at once and loads the shared item off the main actor.
/// It never opens the app: a Share extension has no supported way to (decision K7).
final class ShareViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    private var state: SharedReaderState?
    private var loadTask: Task<Void, Never>?
    private var isComplete = false

    override func viewDidLoad() {
        super.viewDidLoad()
        // PerfSignposts: M7 starts the share open-to-render interval here.
        let providers = sharedProviders()
        let attachments = SharedItemLoader.attachments(of: providers)
        let selection = SharedItemLoader.select(from: attachments)
        let state = SharedReaderState(attachments: attachments, selection: selection)
        state.onDone = { [weak self] in
            self?.complete()
        }
        self.state = state
        install(SharedReaderView(state: state))

        guard let selection, providers.indices.contains(selection.candidate.index) else {
            return
        }
        let provider = SendableProvider(provider: providers[selection.candidate.index])
        loadTask = Task.detached(priority: .userInitiated) {
            let load = await SharedItemLoader.load(selection, from: provider)
            guard !Task.isCancelled else {
                return
            }
            await state.finish(load)
        }
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)
        presentationController?.delegate = self
        if let screen = view.window?.windowScene?.screen {
            preferredContentSize = CGSize(width: screen.bounds.width, height: screen.bounds.height)
        }
    }

    /// Swiping the sheet away ends the request the same way Done does.
    func presentationControllerDidDismiss(_: UIPresentationController) {
        complete()
    }

    /// Attachments of every input item, in order. `SharedCandidate.index` points into this list.
    private func sharedProviders() -> [NSItemProvider] {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        return items.flatMap { $0.attachments ?? [] }
    }

    /// The hosting controller inherits the host's traits, so dark mode and Dynamic Type follow it.
    private func install(_ rootView: SharedReaderView) {
        let host = UIHostingController(rootView: rootView)
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)
    }

    private func complete() {
        guard !isComplete else {
            return
        }
        isComplete = true
        loadTask?.cancel()
        loadTask = nil
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
