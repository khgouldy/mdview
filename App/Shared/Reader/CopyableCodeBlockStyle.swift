import SwiftUI
import Textual

/// `GitHubCodeBlockStyle`'s look with a copy button over the block's top trailing corner and a Copy Code context
/// menu as the fallback. The button sits on the `Overflow` view, so it stays put while a wide block scrolls and is not
/// part of Textual's text selection. Textual 0.5 doesn't expose the fence's language, so there is no language hint.
struct CopyableCodeBlockStyle: StructuredText.CodeBlockStyle {
    func makeBody(configuration: Configuration) -> some View {
        CopyableCodeBlock(configuration: configuration)
    }
}

private struct CopyableCodeBlock: View {
    /// How long the button says "Copied".
    static let confirmationDuration: Duration = .milliseconds(1500)

    let configuration: StructuredText.CodeBlockStyleConfiguration

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var copied = false
    @State private var copyCount = 0
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        Overflow {
            configuration.label
                .textual.lineSpacing(.fontScaled(0.225))
                .textual.fontScale(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .monospaced()
                .padding(16)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .overlay(alignment: .topTrailing) { copyButton }
        .clipShape(.rect(cornerRadius: 6))
        .contextMenu {
            Button("Copy Code", systemImage: "doc.on.doc") { copy() }
        }
        .textual.blockSpacing(.init(top: 0, bottom: 16))
        .onDisappear { resetTask?.cancel() }
    }

    private var copyButton: some View {
        Button(action: copy) {
            Label(
                copied ? "Copied" : "Copy code",
                systemImage: copied ? "checkmark" : "doc.on.doc",
            )
            .font(.caption)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(copied ? Color.green : Color.accentColor)
        .accessibilityIdentifier("code.copy")
        .sensoryFeedback(.success, trigger: copyCount)
    }

    private func copy() {
        configuration.codeBlock.copyToPasteboard()
        copyCount += 1
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
