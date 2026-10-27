import SwiftUI

/// The one place that animates. Pass the `accessibilityReduceMotion` environment value
/// so Reduce Motion applies the change without animation.
enum Motion {
    static func animate(
        _ animation: Animation? = .default,
        reduceMotion: Bool,
        _ body: () -> Void,
    ) {
        if reduceMotion {
            body()
        } else {
            withAnimation(animation, body)
        }
    }
}
