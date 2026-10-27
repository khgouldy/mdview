import Foundation

/// Cuts a tall rendered document into printed pages (V5). Every slice is one page's window onto the content, top
/// down: full pages, then the remainder. The slices cover the content exactly, so no line is drawn twice or lost.
public enum PageSlicer {
    /// A remainder this thin is layout rounding, not content, so it joins the last page instead of making a new one.
    public static let tolerance = 0.5

    /// One page's window onto the content, in points from the top.
    public struct Slice: Equatable, Sendable {
        public var offset: Double
        public var height: Double

        public init(offset: Double, height: Double) {
            self.offset = offset
            self.height = height
        }
    }

    /// Full pages of `pageHeight`, then whatever is left. A document with no content still prints one empty page.
    /// A non-positive or non-finite page height gives one slice of the whole content rather than looping forever.
    public static func slices(contentHeight: Double, pageHeight: Double) -> [Slice] {
        let content = contentHeight.isFinite ? max(contentHeight, 0) : 0
        guard content > 0 else {
            return [Slice(offset: 0, height: 0)]
        }
        guard pageHeight.isFinite, pageHeight > 0 else {
            return [Slice(offset: 0, height: content)]
        }
        var slices: [Slice] = []
        var offset = 0.0
        while content - offset > tolerance || slices.isEmpty {
            let height = min(pageHeight, content - offset)
            slices.append(Slice(offset: offset, height: height))
            offset += height
        }
        // Whatever rounding left behind belongs to the last page.
        slices[slices.count - 1].height += content - offset
        return slices
    }
}

/// The paper a PDF is laid out on: Letter where it is the everyday size, A4 everywhere else.
public enum PaperSize: Equatable, Sendable {
    case usLetter
    case isoA4

    /// Regions whose everyday paper is US Letter.
    public static let letterRegions: Set<String> = ["US", "CA", "MX"]

    /// The paper for an ISO 3166 region code such as `Locale.current.region?.identifier`. Unknown is A4.
    public static func forRegion(_ identifier: String?) -> PaperSize {
        guard let identifier, letterRegions.contains(identifier.uppercased()) else {
            return .isoA4
        }
        return .usLetter
    }

    /// Width in PostScript points (1/72 inch).
    public var width: Double {
        switch self {
        case .usLetter: 612
        case .isoA4: 210 * Self.pointsPerMillimeter
        }
    }

    /// Height in PostScript points (1/72 inch).
    public var height: Double {
        switch self {
        case .usLetter: 792
        case .isoA4: 297 * Self.pointsPerMillimeter
        }
    }

    private static let pointsPerMillimeter = 72 / 25.4
}
