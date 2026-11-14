//
//  PressStyle.swift
//  ClackDesign
//

import SwiftUI

/// The one pressed state for everything tappable that isn't a system button: cards, rows, icon buttons, tags
/// (polish pass 1, DECISIONS C1). The press shows the moment the finger lands (no network call in between): the
/// thing dims a little under a raised-surface veil and, unless Reduce Motion is on, sinks to 97 %.
///
/// `shape` is the outline the veil follows (the card's corners); `scales` is off for full-width rows, where a shrink
/// would pull the edges in from the screen's.
public struct PressStyle: ButtonStyle {
    public var radius: CGFloat
    public var scales: Bool

    public init(radius: CGFloat = Radius.card, scales: Bool = true) {
        self.radius = radius
        self.scales = scales
    }

    public func makeBody(configuration: Configuration) -> some View {
        PressBody(configuration: configuration, radius: radius, scales: scales)
    }

    private struct PressBody: View {
        let configuration: Configuration
        let radius: CGFloat
        let scales: Bool
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let pressed = configuration.isPressed && isEnabled
            configuration.label
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Ink.text.opacity(pressed ? 0.06 : 0))
                        .allowsHitTesting(false)
                }
                .opacity(pressed ? 0.85 : 1)
                .scaleEffect(pressed && scales && !reduceMotion ? 0.97 : 1)
                // Pressing in is immediate (the finger is already there); letting go eases back.
                .animation(pressed ? nil : Motion.tap.animation(reduceMotion: reduceMotion), value: pressed)
        }
    }
}

extension ButtonStyle where Self == PressStyle {
    /// A card or tile (16 pt corners).
    public static var press: PressStyle { PressStyle() }
    /// A tappable thing with its own corners.
    public static func press(radius: CGFloat, scales: Bool = true) -> PressStyle { PressStyle(radius: radius, scales: scales) }
    /// A full-width row in a list: no shrink.
    public static var pressRow: PressStyle { PressStyle(radius: 0, scales: false) }
}
