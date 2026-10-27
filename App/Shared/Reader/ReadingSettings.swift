import SwiftUI

/// Reader preferences stored in `UserDefaults` through `@AppStorage`. Rendered and Source both apply them on top of
/// Dynamic Type, never instead of it.
enum ReadingSettings {
    static let textScaleKey = "reader.textScale"
    static let widthKey = "reader.width"
    static let fontDesignKey = "reader.fontDesign"

    static let minimumTextScale = 0.85
    static let maximumTextScale = 1.6
    static let textScaleStep = 0.15
    static let defaultTextScale = 1.0

    /// Steps `scale` by `delta` steps and keeps it inside the range. Scales are rounded to 2 places so repeated
    /// steps do not drift (1.0 + 0.15 × 4 stays 1.6).
    static func stepped(_ scale: Double, by delta: Int) -> Double {
        let next = scale + Double(delta) * textScaleStep
        return min(max((next * 100).rounded() / 100, minimumTextScale), maximumTextScale)
    }

    /// A stored value outside the range (a hand-edited default) is pulled back in.
    static func clamped(_ scale: Double) -> Double {
        min(max(scale, minimumTextScale), maximumTextScale)
    }
}

/// Width of the Rendered column in points. Phones are narrower than all three, so only iPad shows the difference.
enum ReaderWidth: Double, CaseIterable, Identifiable {
    case narrow = 560
    case standard = 680
    case wide = 860

    static let defaultValue = ReaderWidth.standard

    /// The stored points, or standard for a value that is not one of the three.
    static func resolve(_ stored: Double) -> ReaderWidth {
        ReaderWidth(rawValue: stored) ?? defaultValue
    }

    var id: Double {
        rawValue
    }

    var title: String {
        switch self {
        case .narrow: "Narrow"
        case .standard: "Standard"
        case .wide: "Wide"
        }
    }

    var points: CGFloat {
        CGFloat(rawValue)
    }
}

enum ReaderFontDesign: String, CaseIterable, Identifiable {
    case system
    case serif
    case mono

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        case .mono: "Mono"
        }
    }

    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .mono: .monospaced
        }
    }
}

/// The reader menu's reading section: a Text submenu (Smaller, Larger, Reset), a Width picker and a Font picker.
struct ReadingSettingsMenu: View {
    @AppStorage(ReadingSettings.textScaleKey) private var textScale = ReadingSettings.defaultTextScale
    @AppStorage(ReadingSettings.widthKey) private var width = ReaderWidth.defaultValue.rawValue
    @AppStorage(ReadingSettings.fontDesignKey) private var fontDesign = ReaderFontDesign.system

    var body: some View {
        Menu("Text", systemImage: "textformat.size") {
            Button("Smaller", systemImage: "textformat.size.smaller") {
                textScale = ReadingSettings.stepped(textScale, by: -1)
            }
            .disabled(textScale <= ReadingSettings.minimumTextScale)
            .accessibilityIdentifier("reader.text.smaller")
            Button("Larger", systemImage: "textformat.size.larger") {
                textScale = ReadingSettings.stepped(textScale, by: 1)
            }
            .disabled(textScale >= ReadingSettings.maximumTextScale)
            .accessibilityIdentifier("reader.text.larger")
            Button("Reset", systemImage: "arrow.counterclockwise") {
                textScale = ReadingSettings.defaultTextScale
            }
            .disabled(textScale == ReadingSettings.defaultTextScale)
            .accessibilityIdentifier("reader.text.reset")
        }
        .accessibilityIdentifier("reader.text")
        Picker("Width", selection: $width) {
            ForEach(ReaderWidth.allCases) { Text($0.title).tag($0.rawValue) }
        }
        .accessibilityIdentifier("reader.width")
        Picker("Font", selection: $fontDesign) {
            ForEach(ReaderFontDesign.allCases) { Text($0.title).tag($0) }
        }
        .accessibilityIdentifier("reader.fontDesign")
    }
}
