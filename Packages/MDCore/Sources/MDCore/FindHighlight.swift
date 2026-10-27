import Foundation

/// How each find match is drawn. Colour alone never marks the current match:
/// it also gets a thick underline and bold, so Differentiate Without Color needs no extra cue for it.
public enum FindHighlight {
    public enum Fill: Equatable, Sendable {
        case soft
        case strong
    }

    public enum Underline: Equatable, Sendable {
        case none
        case dotted
        case thick
    }

    public struct MatchStyle: Equatable, Sendable {
        public var fill: Fill
        public var underline: Underline
        public var bold: Bool
    }

    /// One style per match. `current` outside `0..<matchCount` (or nil) marks no match as current.
    /// Other matches get a dotted underline only when `differentiateWithoutColor` is on.
    public static func styles(
        matchCount: Int,
        current: Int?,
        differentiateWithoutColor: Bool,
    ) -> [MatchStyle] {
        guard matchCount > 0 else {
            return []
        }
        let other = MatchStyle(
            fill: .soft,
            underline: differentiateWithoutColor ? .dotted : .none,
            bold: false,
        )
        let strong = MatchStyle(fill: .strong, underline: .thick, bold: true)
        return (0 ..< matchCount).map { $0 == current ? strong : other }
    }
}
