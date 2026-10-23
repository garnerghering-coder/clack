//
//  Typography.swift
//  Clack
//

import SwiftUI

/// Inter for text and Space Grotesk for big numbers and the split-flap digits (docs/SWIFT_PORT.md B6, DESIGN §2.2).
/// Both fonts are bundled (SIL OFL) and listed under "Fonts provided by application" in Info.plist.
enum ClackFont {
    /// Inter's variable font; its PostScript name.
    private static let inter = "InterVariable"
    /// Space Grotesk Bold: the only weight the web shows (it asks for 800 in a few places but only 700 is loaded).
    private static let grotesk = "SpaceGrotesk-Bold"

    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(inter, size: size, relativeTo: style).weight(weight)
    }

    static func grotesk(_ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(grotesk, size: size, relativeTo: style)
    }
}

/// A text role from the design scale: size, line height, weight, tracking (in em) and case (DESIGN_SYSTEM.md §2.3).
struct TextRole {
    var size: CGFloat
    var lineHeight: CGFloat
    var weight: Font.Weight = .regular
    /// Letter spacing in em.
    var tracking: CGFloat = 0
    var uppercase = false
    var display = false
    var style: Font.TextStyle = .body

    // Titles
    static let pageTitle = TextRole(size: 40, lineHeight: 44, weight: .heavy, tracking: -0.02, style: .largeTitle)
    static let sheetTitle = TextRole(size: 28, lineHeight: 34, weight: .heavy, style: .title)
    static let detailRoute = TextRole(size: 28, lineHeight: 34, weight: .heavy, tracking: -0.01, style: .title)
    static let welcomeTitle = TextRole(size: 24, lineHeight: 30, weight: .heavy, style: .title2)
    static let headline = TextRole(size: 20, lineHeight: 26, weight: .bold, style: .title3)
    static let boardSheetTitle = TextRole(size: 20, lineHeight: 26, weight: .heavy, style: .title3)
    static let alertTitle = TextRole(size: 17, lineHeight: 22, weight: .heavy, style: .headline)
    static let boardDestination = TextRole(size: 17, lineHeight: 22, weight: .bold, style: .headline)
    // Body
    static let body = TextRole(size: 16, lineHeight: 22)
    static let rowTitle = TextRole(size: 16, lineHeight: 22, weight: .semibold)
    static let settingsRow = TextRole(size: 16, lineHeight: 22, weight: .medium)
    static let button = TextRole(size: 16, lineHeight: 22, weight: .semibold)
    static let buttonSmall = TextRole(size: 14, lineHeight: 20, weight: .semibold, style: .subheadline)
    static let chipButton = TextRole(size: 14, lineHeight: 20, weight: .semibold, style: .subheadline)
    static let banner = TextRole(size: 14, lineHeight: 20, weight: .medium, style: .subheadline)
    static let delay = TextRole(size: 14, lineHeight: 18, weight: .bold, style: .subheadline)
    static let stopName = TextRole(size: 14, lineHeight: 18, style: .subheadline)
    static let searchField = TextRole(size: 18, lineHeight: 22, weight: .semibold, style: .body)
    // Small
    static let caption = TextRole(size: 13, lineHeight: 18, style: .footnote)
    static let chip = TextRole(size: 13, lineHeight: 18, weight: .semibold, style: .footnote)
    static let sectionHeader = TextRole(size: 13, lineHeight: 18, weight: .bold, tracking: 0.06, uppercase: true, style: .footnote)
    static let monthHeader = TextRole(size: 13, lineHeight: 18, weight: .bold, tracking: 0.05, uppercase: true, style: .footnote)
    static let captionUpper = TextRole(size: 11, lineHeight: 14, weight: .semibold, tracking: 0.06, uppercase: true, style: .caption2)
    static let tab = TextRole(size: 11, lineHeight: 14, weight: .semibold, style: .caption2)
    static let mapAttribution = TextRole(size: 10, lineHeight: 12, style: .caption2)
    static let splashTagline = TextRole(size: 13, lineHeight: 18, weight: .semibold, tracking: 0.22, style: .footnote)
    // Big numbers, in Space Grotesk
    static let passportDistance = TextRole(size: 56, lineHeight: 60, tracking: -0.02, display: true, style: .largeTitle)
    static let passportBig = TextRole(size: 40, lineHeight: 44, display: true, style: .largeTitle)
    static let timeBig = TextRole(size: 36, lineHeight: 40, display: true, style: .largeTitle)
    static let heroTimes = TextRole(size: 34, lineHeight: 40, tracking: -0.01, display: true, style: .largeTitle)
    static let bigTime = TextRole(size: 26, lineHeight: 30, display: true, style: .title)

    var font: Font {
        display ? ClackFont.grotesk(size, relativeTo: style) : ClackFont.inter(size, weight, relativeTo: style)
    }
}

private struct RoleModifier: ViewModifier {
    let role: TextRole

    func body(content: Content) -> some View {
        content
            .font(role.font)
            .tracking(role.tracking * role.size)
            // The web sets a line height; SwiftUI spaces lines by what's added to the font's own.
            .lineSpacing(max(0, role.lineHeight - role.size * 1.21))
            .textCase(role.uppercase ? .uppercase : nil)
    }
}

extension View {
    /// Applies a text role: font, tracking, line height and case. Colour is set separately.
    func clack(_ role: TextRole) -> some View {
        modifier(RoleModifier(role: role))
    }
}
