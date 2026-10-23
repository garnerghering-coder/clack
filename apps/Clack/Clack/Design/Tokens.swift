//
//  Tokens.swift
//  Clack
//

import SwiftUI

/// One radius scale (DESIGN §2.3; styles.css `--r-*`). Nothing is fully rounded except circles (dots, round buttons).
enum Radius {
    /// Tags (platform chip).
    static let tag: CGFloat = 6
    /// 34 pt buttons, filter chips, the date field, glass labels over a map.
    static let controlSm: CGFloat = 10
    /// Buttons, inputs, the segmented control, banners, skeletons.
    static let input: CGFloat = 12
    /// Cards, time blocks, tiles, mini maps.
    static let card: CGFloat = 16
    /// Sheets (top corners on a phone).
    static let sheet: CGFloat = 24
}

/// The colour tokens, named as the web's CSS custom properties (styles.css). Each is a Color Set in
/// `Assets.xcassets/Colors` with a light and a dark value, written by `scripts/ios/make_colors.py`.
enum Ink {
    // Surfaces
    static let bg = Color("bg")
    static let surface = Color("surface")
    static let surfaceRaised = Color("surface-raised")
    static let glass = Color("glass")
    static let glassStrong = Color("glass-strong")
    static let scrim = Color("scrim")
    static let fillSoft = Color("fill-soft")
    static let mapBg = Color("map-bg")
    // Text
    static let text = Color("text")
    static let text2 = Color("text-2")
    static let text3 = Color("text-3")
    // Accent (signal yellow)
    static let accent = Color("accent")
    static let onAccent = Color("on-accent")
    static let accentInk = Color("accent-ink")
    static let accentSoft = Color("accent-soft")
    static let accentLine = Color("accent-line")
    // Status: fills for bars and dots, `-ink` for text
    static let onTime = Color("on-time")
    static let onTimeInk = Color("on-time-ink")
    static let slight = Color("slight")
    static let slightInk = Color("slight-ink")
    static let late = Color("late")
    static let lateInk = Color("late-ink")
    static let veryLate = Color("very-late")
    static let veryLateInk = Color("very-late-ink")
    static let unknown = Color("unknown")
    // Banners
    static let errorBg = Color("error-bg")
    static let errorText = Color("error-text")
    static let warnBg = Color("warn-bg")
    static let warnText = Color("warn-text")
    // Borders
    static let hairline = Color("hairline")
    static let markerRing = Color("marker-ring")
    // Split-flap tiles
    static let flapTop = Color("flap-top")
    static let flapBottom = Color("flap-bottom")
    static let flapHinge = Color("flap-hinge")
    static let flapText = Color("flap-text")
    static let tflapTop = Color("tflap-top")
    static let tflapBottom = Color("tflap-bottom")
    static let tflapHinge = Color("tflap-hinge")
    static let tflapText = Color("tflap-text")
}

extension Color {
    /// A CSS hex colour (`#1fb14f`, `1fb14f`, or with alpha `#1fb14fcc`); nil when it isn't one.
    init?(hex: String?) {
        guard var text = hex?.trimmingCharacters(in: .whitespaces) else { return nil }
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        let hasAlpha = text.count == 8
        let r = Double((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let g = Double((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let b = Double((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let a = hasAlpha ? Double(value & 0xFF) / 255 : 1
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

/// An operator's colour for lines and tints: its brand colour, or the theme's strong colour when it isn't known
/// (`#f8d64a` dark, `#0a0a0a` light; map/style.ts `opColor`).
func operatorColor(_ brandColor: String?, scheme: ColorScheme) -> Color {
    Color(hex: brandColor) ?? (scheme == .dark ? Color(hex: "#f8d64a")! : Color(hex: "#0a0a0a")!)
}

/// The panel shadow (`--shadow`: `0 8px 24px`, 0.45 black in dark and 0.12 in light).
private struct ClackShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.12), radius: 12, x: 0, y: 8)
    }
}

extension View {
    func clackShadow() -> some View {
        modifier(ClackShadow())
    }

    /// `1px solid var(--hairline)` around a rounded shape.
    func hairlineBorder(radius: CGFloat, color: Color = Ink.hairline) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: 1))
    }
}
