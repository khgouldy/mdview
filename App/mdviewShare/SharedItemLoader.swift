import Foundation
import MDCore
import UniformTypeIdentifiers

/// One attachment as the host registered it. "What was shared" lists these.
struct SharedAttachment: Identifiable, Equatable, Sendable {
    let index: Int
    let typeIdentifiers: [String]
    let suggestedName: String?

    var id: Int {
        index
    }
}

/// The outcome of loading the picked attachment.
struct SharedLoad: Sendable {
    var name: String?
    /// Bytes read, or the size that was refused. Nil when nothing was read.
    var byteCount: Int?
    var result: Result<SharedContent, SharedContentError>
}

/// `NSItemProvider` loads from any thread; Foundation does not mark it `Sendable`.
struct SendableProvider: @unchecked Sendable {
    let provider: NSItemProvider
}

/// Picks the best attachment with `SharedItemSelection` and loads it off the main actor.
enum SharedItemLoader {
    /// The Debug activation rule also accepts `public.data`, so selection does too.
    static var allowsData: Bool {
        #if DEBUG
            true
        #else
            false
        #endif
    }

    static func attachments(of providers: [NSItemProvider]) -> [SharedAttachment] {
        providers.enumerated().map { index, provider in
            SharedAttachment(
                index: index,
                typeIdentifiers: provider.registeredTypeIdentifiers,
                suggestedName: provider.suggestedName,
            )
        }
    }

    static func select(from attachments: [SharedAttachment]) -> SharedSelection? {
        let candidates = attachments.map {
            SharedCandidate(
                index: $0.index,
                registeredTypeIdentifiers: $0.typeIdentifiers,
                suggestedName: $0.suggestedName,
            )
        }
        return SharedItemSelection.pick(candidates, allowsData: allowsData, conformsTo: conforms)
    }

    /// `UTType` knows the device's declarations, including the app's imported Markdown type.
    /// MDCore's table covers identifiers the device has no declaration for.
    @Sendable static func conforms(_ type: String, _ parent: String) -> Bool {
        if SharedItemSelection.knownConformance(type, parent) {
            return true
        }
        guard let child = UTType(type), let parentType = UTType(parent) else {
            return false
        }
        return child.conforms(to: parentType)
    }

    /// File representation first (it keeps the host's file name), then data, then the item itself.
    nonisolated static func load(_ selection: SharedSelection, from box: SendableProvider) async -> SharedLoad {
        let provider = box.provider
        let suggested = selection.candidate.suggestedName
        do {
            let loaded = try await loadRepresentation(provider, selection: selection)
            return content(from: loaded, kind: selection.kind, suggestedName: suggested)
        } catch {
            return SharedLoad(name: suggested, byteCount: nil, result: .failure(.unreadable))
        }
    }

    private nonisolated static func loadRepresentation(
        _ provider: NSItemProvider,
        selection: SharedSelection,
    ) async throws -> Loaded {
        guard selection.kind != .fileURL, let type = UTType(selection.typeIdentifier) else {
            return try await loadItem(provider, typeIdentifier: selection.typeIdentifier)
        }
        if let file = try? await loadFile(provider, type: type) {
            return file
        }
        if let data = try? await loadData(provider, type: type) {
            return .bytes(data, fileName: nil)
        }
        return try await loadItem(provider, typeIdentifier: selection.typeIdentifier)
    }

    private nonisolated static func content(
        from loaded: Loaded,
        kind: SharedItemKind,
        suggestedName: String?,
    ) -> SharedLoad {
        switch loaded {
        case let .bytes(data, fileName):
            let name = kind == .fileURL ? fileName : SharedContent.displayName(
                suggestedName: suggestedName,
                fileName: fileName,
            )
            return SharedLoad(
                name: name,
                byteCount: data.count,
                result: SharedContent.make(data: data, kind: kind, suggestedName: name),
            )
        case let .text(text):
            return SharedLoad(
                name: suggestedName,
                byteCount: text.utf8.count,
                result: SharedContent.make(text: text, kind: kind, suggestedName: suggestedName),
            )
        case let .tooLarge(byteCount, fileName):
            let name = kind == .fileURL ? fileName : suggestedName
            return SharedLoad(name: name, byteCount: byteCount, result: .failure(.tooLarge(byteCount: byteCount)))
        }
    }

    private enum Loaded: Sendable {
        case bytes(Data, fileName: String?)
        case text(String)
        case tooLarge(Int, fileName: String?)
    }

    private enum LoadError: Error {
        case missing
        case unsupportedItem
    }

    /// The system deletes the file when the callback returns, so the bytes are read inside it.
    private nonisolated static func loadFile(_ provider: NSItemProvider, type: UTType) async throws -> Loaded {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadFileRepresentation(for: type, openInPlace: false) { url, _, error in
                guard let url else {
                    continuation.resume(throwing: error ?? LoadError.missing)
                    return
                }
                continuation.resume(with: Result { try readCapped(url) })
            }
        }
    }

    private nonisolated static func loadData(_ provider: NSItemProvider, type: UTType) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(for: type) { data, error in
                guard let data else {
                    continuation.resume(throwing: error ?? LoadError.missing)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    /// Hosts that register an object hand back a `String`, `Data` or a file `URL`.
    private nonisolated static func loadItem(
        _ provider: NSItemProvider,
        typeIdentifier: String,
    ) async throws -> Loaded {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                continuation.resume(with: Result {
                    switch item {
                    case let text as String:
                        return .text(text)
                    case let url as URL where url.isFileURL:
                        return try readSecurityScoped(url)
                    case let data as Data:
                        if let url = fileURL(fromItemData: data, typeIdentifier: typeIdentifier) {
                            return try readSecurityScoped(url)
                        }
                        return .bytes(data, fileName: nil)
                    case let attributed as NSAttributedString:
                        return .text(attributed.string)
                    default:
                        throw error ?? LoadError.unsupportedItem
                    }
                })
            }
        }
    }

    /// A `public.file-url` item can arrive as the URL's bytes.
    private nonisolated static func fileURL(fromItemData data: Data, typeIdentifier: String) -> URL? {
        guard typeIdentifier == SharedItemSelection.fileURLType,
              let url = URL(dataRepresentation: data, relativeTo: nil),
              url.isFileURL
        else {
            return nil
        }
        return url
    }

    private nonisolated static func readSecurityScoped(_ url: URL) throws -> Loaded {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try readCapped(url)
    }

    /// Checks the size before reading so a large file is never pulled into memory.
    private nonisolated static func readCapped(_ url: URL) throws -> Loaded {
        let fileName = url.lastPathComponent
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > SharedContent.limitBytes {
            return .tooLarge(size, fileName: fileName)
        }
        return try .bytes(Data(contentsOf: url), fileName: fileName)
    }
}
