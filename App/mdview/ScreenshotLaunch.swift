#if DEBUG
    import MDCore
    import SwiftUI
    import UIKit

    /// Debug-only entry for `scripts/screenshots.sh`. Release builds omit this file's contents.
    enum ScreenshotLaunch {
        struct Loaded {
            let url: URL
            let document: TextDocument
        }

        static var isRequested: Bool {
            environmentName != nil || argumentName != nil
        }

        static var interfaceStyle: UIUserInterfaceStyle {
            switch ProcessInfo.processInfo.environment["MDVIEW_SCREENSHOT_SCHEME"] {
            case "dark":
                .dark
            case "light":
                .light
            default:
                .unspecified
            }
        }

        static var colorScheme: ColorScheme? {
            switch interfaceStyle {
            case .dark:
                .dark
            case .light:
                .light
            default:
                nil
            }
        }

        /// Prefers `MDVIEW_SCREENSHOT_MARKDOWN` from the UI test. Otherwise reads
        /// `--screenshot-document <file name>` out of Documents.
        static func load() -> Loaded? {
            loadedFromEnvironment() ?? loadedFromDocuments()
        }

        private static func loadedFromEnvironment() -> Loaded? {
            guard let name = environmentName else {
                return nil
            }
            let text = ProcessInfo.processInfo.environment["MDVIEW_SCREENSHOT_MARKDOWN"] ?? ""
            guard !text.isEmpty else {
                return nil
            }
            return Loaded(
                url: URL(fileURLWithPath: name),
                document: TextDocument(text: text, contentType: .markdown),
            )
        }

        private static func loadedFromDocuments() -> Loaded? {
            guard let name = argumentName, let root = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask,
            ).first else {
                return nil
            }
            let url = root.appendingPathComponent(name)
            guard let data = try? Data(contentsOf: url) else {
                return nil
            }
            return Loaded(
                url: url,
                document: TextDocument(text: TextDecoding.decode(data), contentType: .markdown),
            )
        }

        private static var environmentName: String? {
            let name = ProcessInfo.processInfo.environment["MDVIEW_SCREENSHOT_NAME"] ?? ""
            return name.isEmpty ? nil : name
        }

        private static var argumentName: String? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let flag = arguments.firstIndex(of: "--screenshot-document"),
                  arguments.indices.contains(arguments.index(after: flag))
            else {
                return nil
            }
            return arguments[arguments.index(after: flag)]
        }
    }

    /// Covers the document browser. SceneBuilder cannot branch on a runtime flag, and SwiftUI
    /// replaces a window's root view controller after launch. The timer stops once the reader is
    /// key so XCUITest can see the app go idle.
    @MainActor
    final class ScreenshotOpener: NSObject {
        static let shared = ScreenshotOpener()

        private var overlay: UIWindow?
        private var attempts = 0
        private var armed = false
        private var installed = false

        func arm() {
            guard !armed else {
                return
            }
            armed = true
            guard ScreenshotLaunch.isRequested else {
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
            installIfNeeded()
        }

        private func tick() {
            installIfNeeded()
            guard !installed else {
                return
            }
            attempts += 1
            guard attempts < 40 else {
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.tick()
            }
        }

        private func installIfNeeded() {
            guard !installed, let shot = ScreenshotLaunch.load() else {
                return
            }
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            guard let scene = scenes.first else {
                return
            }
            let window = overlay ?? UIWindow(windowScene: scene)
            window.frame = scene.screen.bounds
            window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
            window.overrideUserInterfaceStyle = ScreenshotLaunch.interfaceStyle
            if overlay == nil {
                window.rootViewController = UIHostingController(rootView: ScreenshotReader(shot: shot))
                overlay = window
            }
            window.makeKeyAndVisible()
            for other in scene.windows where other !== window {
                other.isHidden = true
            }
            installed = true
        }
    }

    private struct ScreenshotReader: View {
        let shot: ScreenshotLaunch.Loaded

        var body: some View {
            NavigationStack {
                ReaderView(document: shot.document)
                    .environment(\.screenshotFileURL, shot.url)
            }
            .preferredColorScheme(ScreenshotLaunch.colorScheme)
        }
    }

    private struct ScreenshotFileURLKey: EnvironmentKey {
        static let defaultValue: URL? = nil
    }

    extension EnvironmentValues {
        var screenshotFileURL: URL? {
            get { self[ScreenshotFileURLKey.self] }
            set { self[ScreenshotFileURLKey.self] = newValue }
        }
    }
#endif
