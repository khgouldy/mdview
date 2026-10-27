import MDCore
import SwiftUI
import Textual
import UIKit

/// Block quotes, with GitHub alerts and Obsidian callouts drawn as callouts: a 3 pt accent bar on the left, the
/// kind's symbol and a bold title (the paragraph `CalloutPreprocessor` writes), and a faint tint of the accent.
///
/// The style only sees an opaque label, so the kind arrives the way a task checkbox's state does: the title's
/// `CalloutSymbol` attachment fills in the quote's `QuoteCallout` when it appears. A plain quote keeps the GitHub look.
struct CalloutBlockQuoteStyle: StructuredText.BlockQuoteStyle {
    func makeBody(configuration: Configuration) -> some View {
        CalloutBlockQuote(configuration: configuration)
    }
}

private struct CalloutBlockQuote: View {
    let configuration: StructuredText.BlockStyleConfiguration
    @State private var callout = QuoteCallout()

    /// One view tree for both looks, so the label (and its attachment) is not rebuilt when the kind arrives.
    var body: some View {
        let kind = callout.kind
        HStack(spacing: 0) {
            // Only the bar's own identity changes here; the label stays the HStack's second child.
            if let kind {
                Rectangle()
                    .fill(kind.accent)
                    .frame(width: 3)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Self.border)
                    .textual.frame(width: .fontScaled(0.2))
            }
            configuration.label
                .foregroundStyle(kind == nil ? Self.secondary : Color.primary)
                .textual.padding(.horizontal, .fontScaled(1))
                .padding(.vertical, kind == nil ? 0 : 10)
                .frame(maxWidth: kind == nil ? nil : .infinity, alignment: .leading)
        }
        .background(kind.map { $0.accent.opacity(0.07) } ?? Color.clear)
        .clipShape(.rect(cornerRadius: kind == nil ? 0 : 6))
        .environment(callout)
    }

    /// Textual's GitHub block quote colors (`DynamicColor.gitHubBorder` and `.gitHubSecondary`, internal there).
    private static let border = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 66 / 255, green: 68 / 255, blue: 78 / 255, alpha: 1)
            : UIColor(red: 228 / 255, green: 228 / 255, blue: 232 / 255, alpha: 1)
    })
    private static let secondary = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 146 / 255, green: 148 / 255, blue: 160 / 255, alpha: 1)
            : UIColor(red: 107 / 255, green: 110 / 255, blue: 123 / 255, alpha: 1)
    })
}

/// The callout kind of the block quote around it, if any. `CalloutBlockQuote` puts one in each quote's environment
/// and the title's `CalloutSymbol` fills it in. A nested quote has its own.
@MainActor @Observable
final class QuoteCallout {
    var kind: CalloutKind?
}

/// The kind's SF Symbol before a callout's title, drawn inline like a task checkbox.
struct CalloutSymbol: Attachment {
    var kind: CalloutKind

    /// Copied text gets nothing for the symbol: the title after it already names the callout.
    var description: String {
        ""
    }

    var selectionStyle: AttachmentSelectionStyle {
        .text
    }

    var body: some View {
        CalloutSymbolImage(kind: kind)
    }

    func sizeThatFits(_: ProposedViewSize, in environment: TextEnvironmentValues) -> CGSize {
        let side = TaskCheckbox.side(for: environment.dynamicTypeSize)
        return CGSize(width: side, height: side)
    }
}

/// A `Canvas` symbol still gets the environment and `onAppear`, so this is how the kind reaches the quote. The title
/// text next to it is what VoiceOver reads.
private struct CalloutSymbolImage: View {
    let kind: CalloutKind
    @Environment(QuoteCallout.self) private var callout: QuoteCallout?

    var body: some View {
        Image(systemName: kind.symbolName)
            .resizable()
            .scaledToFit()
            .foregroundStyle(kind.accent)
            .onAppear { callout?.kind = kind }
    }
}

extension CalloutKind {
    var symbolName: String {
        switch self {
        case .note: "info.circle"
        case .tip: "lightbulb"
        case .important: "exclamationmark.bubble"
        case .warning: "exclamationmark.triangle"
        case .caution: "exclamationmark.octagon"
        }
    }

    /// GitHub's alert colors, light and dark.
    var accent: Color {
        let (light, dark): (UInt32, UInt32) = switch self {
        case .note: (0x0969DA, 0x4493F8)
        case .tip: (0x1A7F37, 0x3FB950)
        case .important: (0x8250DF, 0xAB7DF8)
        case .warning: (0x9A6700, 0xD29922)
        case .caution: (0xD1242F, 0xF85149)
        }
        return Color(uiColor: UIColor { traits in
            Self.color(traits.userInterfaceStyle == .dark ? dark : light)
        })
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1,
        )
    }
}
