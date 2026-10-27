import Foundation

/// One attachment of a share request, described without UIKit or `UTType`.
public struct SharedCandidate: Equatable, Sendable {
    /// Position among all attachments of all extension items, in the order the host sent them.
    public var index: Int
    /// The provider's `registeredTypeIdentifiers`, highest fidelity first.
    public var registeredTypeIdentifiers: [String]
    public var suggestedName: String?
    /// The provider offers a `public.file-url` representation.
    public var isFileURL: Bool

    public init(
        index: Int,
        registeredTypeIdentifiers: [String],
        suggestedName: String? = nil,
        isFileURL: Bool? = nil,
    ) {
        self.index = index
        self.registeredTypeIdentifiers = registeredTypeIdentifiers
        self.suggestedName = suggestedName
        self.isFileURL = isFileURL ?? registeredTypeIdentifiers.contains(SharedItemSelection.fileURLType)
    }
}

/// What a shared type is to the reader. Lower raw values are better.
public enum SharedItemKind: Int, Comparable, Sendable, CaseIterable {
    case markdown
    case plainText
    case text
    case fileURL
    case data

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// The attachment to open and the registered type to load from it.
public struct SharedSelection: Equatable, Sendable {
    public var candidate: SharedCandidate
    public var typeIdentifier: String
    public var kind: SharedItemKind

    public init(candidate: SharedCandidate, typeIdentifier: String, kind: SharedItemKind) {
        self.candidate = candidate
        self.typeIdentifier = typeIdentifier
        self.kind = kind
    }
}

/// Picks which shared attachment and type the share extension loads.
/// Rank: Markdown > `public.plain-text` conformers > `public.text` > `public.file-url` > `public.data`.
public enum SharedItemSelection {
    /// `(type, parent)` is true when `type` conforms to `parent`. The extension passes `UTType` conformance.
    public typealias Conformance = @Sendable (_ type: String, _ parent: String) -> Bool

    public static let markdownType = "net.daringfireball.markdown"
    public static let plainTextType = "public.plain-text"
    public static let textType = "public.text"
    public static let fileURLType = "public.file-url"
    public static let dataType = "public.data"

    /// The best attachment, then its best type. Ties keep the host's order (the first attachment, and the
    /// first-registered type, which is the provider's highest fidelity). `public.data` counts only when
    /// `allowsData` is true, which the Debug activation rule mirrors.
    public static func pick(
        _ candidates: [SharedCandidate],
        allowsData: Bool = false,
        conformsTo: Conformance = knownConformance,
    ) -> SharedSelection? {
        var best: SharedSelection?
        for candidate in candidates {
            guard let selection = bestType(in: candidate, allowsData: allowsData, conformsTo: conformsTo) else {
                continue
            }
            if let current = best, current.kind <= selection.kind {
                continue
            }
            best = selection
        }
        return best
    }

    /// The kind a single registered type identifier counts as, or nil when the reader cannot use it.
    public static func kind(
        of typeIdentifier: String,
        allowsData: Bool = false,
        conformsTo: Conformance = knownConformance,
    ) -> SharedItemKind? {
        func conforms(_ parent: String) -> Bool {
            typeIdentifier == parent || conformsTo(typeIdentifier, parent)
        }
        if conforms(markdownType) {
            return .markdown
        }
        if conforms(plainTextType) {
            return .plainText
        }
        if conforms(textType) {
            return .text
        }
        if conforms(fileURLType) {
            return .fileURL
        }
        if allowsData, conforms(dataType) {
            return .data
        }
        return nil
    }

    private static func bestType(
        in candidate: SharedCandidate,
        allowsData: Bool,
        conformsTo: Conformance,
    ) -> SharedSelection? {
        var best: SharedSelection?
        for identifier in candidate.registeredTypeIdentifiers {
            guard let kind = kind(of: identifier, allowsData: allowsData, conformsTo: conformsTo) else {
                continue
            }
            if let current = best, current.kind <= kind {
                continue
            }
            best = SharedSelection(candidate: candidate, typeIdentifier: identifier, kind: kind)
        }
        if best == nil, candidate.isFileURL {
            return SharedSelection(candidate: candidate, typeIdentifier: fileURLType, kind: .fileURL)
        }
        return best
    }

    /// Conformance for the system types hosts commonly share, so selection works without `UTType`
    /// (tests, and identifiers the device has no declaration for). Transitive.
    public static func knownConformance(_ type: String, _ parent: String) -> Bool {
        var pending = [type]
        var seen: Set<String> = []
        while let next = pending.popLast() {
            guard seen.insert(next).inserted else {
                continue
            }
            let parents = knownParents[next] ?? []
            if parents.contains(parent) {
                return true
            }
            pending.append(contentsOf: parents)
        }
        return false
    }

    private static let knownParents: [String: [String]] = [
        "net.ia.markdown": [markdownType],
        "org.daringfireball.markdown": [markdownType],
        markdownType: [plainTextType],
        "public.utf8-plain-text": [plainTextType],
        "public.utf16-plain-text": [plainTextType],
        "public.utf16-external-plain-text": [plainTextType],
        "public.source-code": [plainTextType],
        plainTextType: [textType],
        "public.rtf": [textType],
        "public.html": [textType],
        "public.xml": [textType],
        "public.json": [textType],
        "public.delimited-values-text": [textType],
        "public.comma-separated-values-text": ["public.delimited-values-text"],
        "public.tab-separated-values-text": ["public.delimited-values-text"],
        "public.utf8-tab-separated-values-text": ["public.tab-separated-values-text"],
        textType: [dataType, "public.content"],
        fileURLType: ["public.url"],
        "public.url": [dataType],
        "public.jpeg": ["public.image"],
        "public.png": ["public.image"],
        "public.heic": ["public.image"],
        "public.image": [dataType, "public.content"],
        "com.adobe.pdf": [dataType, "public.composite-content"],
        "public.composite-content": ["public.content"],
    ]
}
