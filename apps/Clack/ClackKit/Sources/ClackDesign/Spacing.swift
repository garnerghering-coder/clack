//
//  Spacing.swift
//  ClackDesign
//

import SwiftUI

/// One spacing scale on the 4 pt grid (DESIGN §2.3). Every padding and stack spacing uses these; the design lint
/// (scripts/ios/lint_design.py) rejects number literals in the feature code.
public enum Space {
    /// Hairline gaps: a tight text pair, a tile's gap.
    public static let xxs: CGFloat = 2
    /// Icon to its label, lines in one block.
    public static let xs: CGFloat = 4
    /// Items in a row, lines in a card.
    public static let s: CGFloat = 8
    /// Blocks in a card, a banner's padding.
    public static let m: CGFloat = 12
    /// The screen gutter, a card's padding, cards in a list.
    public static let l: CGFloat = 16
    /// Sections on a page.
    public static let xl: CGFloat = 24
    /// Large breaks (the end of a page).
    public static let xxl: CGFloat = 32
    /// Empty-state breathing room.
    public static let xxxl: CGFloat = 48
}

extension Radius {
    /// The radius of a shape inset `padding` inside a container of radius `outer`, so the corners stay concentric.
    public static func inner(_ outer: CGFloat, padding: CGFloat) -> CGFloat { max(outer - padding, 2) }
}
