import Foundation

/// The user-visible app name. Every string shown to people uses this, never a literal.
/// The value comes from `APP_DISPLAY_NAME` in `project.yml` through `CFBundleDisplayName`.
enum AppName {
    static var display: String {
        display(from: Bundle.main)
    }

    static func display(from bundle: Bundle) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "MdV"
    }
}
