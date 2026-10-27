import SwiftUI
import UIKit

/// Presents a screen from a launch-screen action with UIKit.
///
/// On iOS 26 `DocumentGroupLaunchScene` redraws its actions as its own buttons (folded into a More… menu when there
/// are two) and keeps the SwiftUI views that define them hidden. A `.sheet` or `.fullScreenCover` on those hidden views
/// never appears: in CI run 40510800702 More… > How to Open Files was tapped and no guide opened. So the actions
/// present
/// a hosting controller from the top view controller, and the screen closes through `launchDismiss`.
@MainActor
enum LaunchPresenter {
    static func present(_ content: some View, style: UIModalPresentationStyle) {
        // Next turn of the main queue, so the More… menu that ran the action has started to close.
        DispatchQueue.main.async {
            guard let presenter = topViewController() else {
                return
            }
            let controller = UIHostingController(rootView: AnyView(EmptyView()))
            controller.rootView = AnyView(
                content.environment(\.launchDismiss, LaunchDismissAction { [weak controller] in
                    controller?.dismiss(animated: true)
                }),
            )
            controller.modalPresentationStyle = style
            presenter.present(controller, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windows = scenes.flatMap(\.windows)
        var top = (windows.first(where: \.isKeyWindow) ?? windows.first)?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}

/// Closes a screen that `LaunchPresenter` showed. SwiftUI's `dismiss` doesn't know about that presentation, so the
/// screen's Done calls this when it is set and `dismiss` otherwise.
struct LaunchDismissAction: Sendable {
    let action: @MainActor @Sendable () -> Void

    @MainActor
    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    @Entry var launchDismiss: LaunchDismissAction?
}
