#if DEBUG
    import QuickLook
    import SwiftUI
    import UIKit
    import UniformTypeIdentifiers

    /// Debug-only host for the share-sheet UI tests (`ShareSheetTests`) and for trying MdV's Share
    /// extension by hand. Armed by `MDVIEW_SHARE_HARNESS=<case>`. Shows one `harness.share` button
    /// that presents the real share sheet with the shape of item a chat app would hand over.
    enum ShareHarness {
        enum Case: String {
            case text
            case textDocument
            case fileMarkdown
            case fileText
            case quickLook
        }

        static let defaultMarkdown = "# Shared heading\n\n- [x] done"

        static var requested: Case? {
            let value = ProcessInfo.processInfo.environment["MDVIEW_SHARE_HARNESS"] ?? ""
            return Case(rawValue: value)
        }

        static var markdown: String {
            let value = ProcessInfo.processInfo.environment["MDVIEW_SHARE_MARKDOWN"] ?? ""
            return value.isEmpty ? defaultMarkdown : value
        }

        /// Writes `name` into a fresh directory under `tmp`, so the file keeps its exact name.
        static func writeFile(named name: String) throws -> URL {
            let directory = FileManager.default.temporaryDirectory
                .appendingPathComponent("share-harness-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent(name)
            try Data(markdown.utf8).write(to: url)
            return url
        }

        /// The "Text Document" case: only `public.utf8-plain-text` data, no suggested name.
        static func textDocumentProvider() -> NSItemProvider {
            let provider = NSItemProvider()
            let data = Data(markdown.utf8)
            provider.registerDataRepresentation(
                forTypeIdentifier: UTType.utf8PlainText.identifier,
                visibility: .all,
            ) { completion in
                completion(data, nil)
                return nil
            }
            return provider
        }
    }

    @MainActor
    final class ShareHarnessOpener: NSObject {
        static let shared = ShareHarnessOpener()

        private var window: UIWindow?
        private var attempts = 0
        private var armed = false

        func arm() {
            guard !armed else {
                return
            }
            armed = true
            guard ShareHarness.requested != nil else {
                return
            }
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(activated),
                name: UIScene.didActivateNotification,
                object: nil,
            )
            DispatchQueue.main.async { [weak self] in
                self?.tick()
            }
        }

        @objc private func activated() {
            install()
        }

        private func tick() {
            install()
            attempts += 1
            guard window == nil, attempts < 40 else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.tick()
            }
        }

        private func install() {
            guard window == nil, let harnessCase = ShareHarness.requested,
                  let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first
            else {
                return
            }
            let host = ShareHarnessController(harnessCase: harnessCase)
            let overlay = UIWindow(windowScene: scene)
            overlay.frame = scene.screen.bounds
            overlay.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
            overlay.rootViewController = host
            overlay.makeKeyAndVisible()
            for other in scene.windows where other !== overlay {
                other.isHidden = true
            }
            window = overlay
        }
    }

    @MainActor
    private final class ShareHarnessController: UIViewController, @preconcurrency QLPreviewControllerDataSource {
        let harnessCase: ShareHarness.Case
        private var previewURL: URL?

        init(harnessCase: ShareHarness.Case) {
            self.harnessCase = harnessCase
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            var configuration = UIButton.Configuration.borderedProminent()
            configuration.title = "Share (\(harnessCase.rawValue))"
            let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in
                self?.present()
            })
            button.accessibilityIdentifier = "harness.share"
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)
            NSLayoutConstraint.activate([
                button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ])
        }

        private func present() {
            do {
                switch harnessCase {
                case .text:
                    share([ShareHarness.markdown])
                case .textDocument:
                    share([ShareHarness.textDocumentProvider()])
                case .fileMarkdown:
                    try share([ShareHarness.writeFile(named: "Shared Note.md")])
                case .fileText:
                    try share([ShareHarness.writeFile(named: "notes.txt")])
                case .quickLook:
                    previewURL = try ShareHarness.writeFile(named: "Shared Note.md")
                    let preview = QLPreviewController()
                    preview.dataSource = self
                    present(preview, animated: true)
                }
            } catch {
                assertionFailure("Share harness fixture failed: \(error)")
            }
        }

        private func share(_ items: [Any]) {
            let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
            controller.popoverPresentationController?.sourceView = view
            controller.popoverPresentationController?.sourceRect = CGRect(
                x: view.bounds.midX, y: view.bounds.midY, width: 1, height: 1,
            )
            present(controller, animated: true)
        }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int {
            previewURL == nil ? 0 : 1
        }

        func previewController(_: QLPreviewController, previewItemAt _: Int) -> any QLPreviewItem {
            (previewURL ?? URL(fileURLWithPath: "/dev/null")) as NSURL
        }
    }
#endif
