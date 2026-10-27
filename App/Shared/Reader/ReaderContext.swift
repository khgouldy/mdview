import SwiftUI

/// Where the shown document came from. The app's DocumentGroup supplies this through
/// `documentConfiguration`; hosts without one (screenshot runs, extensions) inject it here.
struct ReaderContext: Equatable {
    var fileURL: URL?
    var displayName: String?
}

extension EnvironmentValues {
    @Entry var readerContext: ReaderContext?
}
