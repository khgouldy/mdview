import SwiftUI

/// Persisted Rendered / Source choice. Raw values are the `@AppStorage("reader.mode")` strings.
enum ReaderMode: String, CaseIterable, Identifiable {
    case rendered
    case source

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .rendered:
            "Rendered"
        case .source:
            "Source"
        }
    }
}
