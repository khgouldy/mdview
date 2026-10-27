import SwiftUI
import Textual

/// `GitHubCodeBlockStyle`'s look with a slim header row above the code: the fence's language on the left (when the
/// fence names one) and an icon-only copy button on the right, plus a Copy Code context menu. The header sits outside
/// the `Overflow` view, so it never covers the code (one-line blocks included) and stays put while a wide block
/// scrolls sideways. It is not part of Textual's text selection.
struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        CopyableCodeBlock(configuration: configuration)
    }
}

private struct CopyableCodeBlock: View {
    /// How long the button shows a checkmark.
    static let confirmationDuration: Duration = .milliseconds(1500)
    /// The header's visual height. The button keeps a 44 pt hit area and overhangs it a little.
    static let headerHeight: CGFloat = 36

    /// Laid over the code background, so the header reads one step darker in light and dark mode.
    static let headerShade = Color(uiColor: UIColor { traits in
        UIColor.black.withAlphaComponent(traits.userInterfaceStyle == .dark ? 0.3 : 0.06)
    })

    let configuration: StructuredText.CodeBlockStyleConfiguration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    @State private var copyCount = 0
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Overflow {
                configuration.label
                    .textual.lineSpacing(.fontScaled(0.225))
                    .textual.fontScale(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                    .monospaced()
                    .padding(16)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(.rect(cornerRadius: 6))
        .contextMenu {
            Button("Copy Code", systemImage: "doc.on.doc") { copy() }
        }
        .textual.blockSpacing(.init(top: 0, bottom: 16))
        .onDisappear { resetTask?.cancel() }
    }

    private var language: String? {
        guard let hint = configuration.languageHint?.trimmingCharacters(in: .whitespaces), !hint.isEmpty else {
            return nil
        }
        return hint
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let language {
                Text(language)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityLabel("\(language) code")
            }
            Spacer(minLength: 0)
            copyButton
        }
        .padding(.leading, 16)
        .frame(height: Self.headerHeight)
        .background(Self.headerShade)
    }

    private var copyButton: some View {
        Button(action: copy) {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .font(.caption.weight(.semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(copied ? Color.green : Color.accentColor)
        // 44 pt tall in a 36 pt row: the extra overhangs the row and the code's top padding, not the code.
        .padding(.vertical, -(44 - Self.headerHeight) / 2)
        .accessibilityLabel("Copy code")
        .accessibilityValue(copied ? "Copied" : "")
        .accessibilityIdentifier("code.copy")
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private func copy() {
        configuration.codeBlock.copyToPasteboard()
        copyCount += 1
        AccessibilityNotification.Announcement("Copied").post()
        Motion.animate(reduceMotion: reduceMotion) { copied = true }
        resetTask?.cancel()
        resetTask = Task {
            try? await Task.sleep(for: Self.confirmationDuration)
            guard !Task.isCancelled else { return }
            Motion.animate(reduceMotion: reduceMotion) { copied = false }
        }
    }
}

extension StructuredText.CodeBlockStyle where Self == CopyableCodeBlockStyle {
    static var copyable: Self {
        CopyableCodeBlockStyle()
    }
}
