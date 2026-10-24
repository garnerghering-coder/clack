//
//  Tokens.swift
//  Clack
//

import ClackCore
import SwiftUI

/// One radius scale (DESIGN §2.3; styles.css `--r-*`). Nothing is fully rounded except circles (dots, round buttons).
public enum Radius {
    /// Tags (platform chip).
    public static let tag: CGFloat = 6
    /// 34 pt buttons, filter chips, the date field, glass labels over a map.
    public static let controlSm: CGFloat = 10
    /// Buttons, inputs, the segmented control, banners, skeletons.
    public static let input: CGFloat = 12
    /// Cards, time blocks, tiles, mini maps.
    public static let card: CGFloat = 16
    /// Sheets (top corners on a phone).
    public static let sheet: CGFloat = 24
}

/// The colour tokens, named as the web's CSS custom properties (styles.css). Each is a Color Set in
/// `Resources/Assets.xcassets/Colors` with a light and a dark value, written by `scripts/ios/make_colors.py`.
public enum Ink {
    // Surfaces
    public static let bg = Color("bg", bundle: .module)
    public static let surface = Color("surface", bundle: .module)
    public static let surfaceRaised = Color("surface-raised", bundle: .module)
    public static let glass = Color("glass", bundle: .module)
    public static let glassStrong = Color("glass-strong", bundle: .module)
    public static let scrim = Color("scrim", bundle: .module)
    public static let fillSoft = Color("fill-soft", bundle: .module)
    public static let mapBg = Color("map-bg", bundle: .module)
    // Text
    public static let text = Color("text", bundle: .module)
    public static let text2 = Color("text-2", bundle: .module)
    public static let text3 = Color("text-3", bundle: .module)
    // Accent (signal yellow)
    public static let accent = Color("accent", bundle: .module)
    public static let onAccent = Color("on-accent", bundle: .module)
    public static let accentInk = Color("accent-ink", bundle: .module)
    public static let accentSoft = Color("accent-soft", bundle: .module)
    public static let accentLine = Color("accent-line", bundle: .module)
    // Status: fills for bars and dots, `-ink` for text
    public static let onTime = Color("on-time", bundle: .module)
    public static let onTimeInk = Color("on-time-ink", bundle: .module)
    public static let slight = Color("slight", bundle: .module)
    public static let slightInk = Color("slight-ink", bundle: .module)
    public static let late = Color("late", bundle: .module)
    public static let lateInk = Color("late-ink", bundle: .module)
    public static let veryLate = Color("very-late", bundle: .module)
    public static let veryLateInk = Color("very-late-ink", bundle: .module)
    public static let unknown = Color("unknown", bundle: .module)
    // Banners
    public static let errorBg = Color("error-bg", bundle: .module)
    public static let errorText = Color("error-text", bundle: .module)
    public static let warnBg = Color("warn-bg", bundle: .module)
    public static let warnText = Color("warn-text", bundle: .module)
    // Borders
    public static let hairline = Color("hairline", bundle: .module)
    public static let markerRing = Color("marker-ring", bundle: .module)
    // Split-flap tiles
    public static let flapTop = Color("flap-top", bundle: .module)
    public static let flapBottom = Color("flap-bottom", bundle: .module)
    public static let flapHinge = Color("flap-hinge", bundle: .module)
    public static let flapText = Color("flap-text", bundle: .module)
    public static let tflapTop = Color("tflap-top", bundle: .module)
    public static let tflapBottom = Color("tflap-bottom", bundle: .module)
    public static let tflapHinge = Color("tflap-hinge", bundle: .module)
    public static let tflapText = Color("tflap-text", bundle: .module)
}

extension Color {
    /// A CSS hex colour (`#1fb14f`, `1fb14f`, or with alpha `#1fb14fcc`); nil when it isn't one.
    public init?(hex: String?) {
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
public func operatorColor(_ brandColor: String?, scheme: ColorScheme) -> Color {
    Color(hex: brandColor) ?? (scheme == .dark ? Color(hex: "#f8d64a")! : Color(hex: "#0a0a0a")!)
}

/// The panel shadow (`--shadow`: `0 8px 24px`, 0.45 black in dark and 0.12 in light).
private struct ClackShadow: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    public func body(content: Content) -> some View {
        content.shadow(color: .black.opacity(scheme == .dark ? 0.45 : 0.12), radius: 12, x: 0, y: 8)
    }
}

extension View {
    public func clackShadow() -> some View {
        modifier(ClackShadow())
    }

    /// `1px solid var(--hairline)` around a rounded shape.
    public func hairlineBorder(radius: CGFloat, color: Color = Ink.hairline) -> some View {
        overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: 1))
    }
}
