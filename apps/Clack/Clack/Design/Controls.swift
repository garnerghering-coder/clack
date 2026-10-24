//
//  Controls.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// `.button`: secondary by default, `primary` is the yellow one, `danger` writes its label in the very-late colour.
struct ClackButtonStyle: ButtonStyle {
    enum Kind { case secondary, primary, danger }

    var kind: Kind = .secondary
    var small = false
    var wide = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let radius = small ? Radius.controlSm : Radius.input
        let fill = kind == .primary ? Ink.accent : Ink.surfaceRaised
        let border = kind == .primary ? Ink.accent : Ink.hairline
        let label = kind == .primary ? Ink.onAccent : (kind == .danger ? Ink.veryLate : Ink.text)
        configuration.label
            .clack(small ? .buttonSmall : .button)
            .foregroundStyle(label)
            .padding(.horizontal, small ? 14 : 18)
            .frame(minHeight: small ? 34 : 44)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .hairlineBorder(radius: radius, color: border)
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .textSelection(.disabled)
    }
}

extension ButtonStyle where Self == ClackButtonStyle {
    static func clack(_ kind: ClackButtonStyle.Kind = .secondary, small: Bool = false, wide: Bool = false) -> ClackButtonStyle {
        ClackButtonStyle(kind: kind, small: small, wide: wide)
    }
}

/// `.link-button`: accent-ink text; in the light theme it is underlined in yellow so it still reads as a link. At
/// least 44 pt high, so it is as easy to hit as any button (DESIGN §16).
struct LinkButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clack(.button)
            .foregroundStyle(Ink.accentInk)
            .underline(scheme == .light, color: Ink.accent)
            .opacity(configuration.isPressed ? 0.7 : 1)
            .textSelection(.disabled)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// `.segmented`: equal segments in a surface track; the chosen one is yellow.
struct SegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    var small = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let active = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .clack(small ? .buttonSmall : .button)
                        .foregroundStyle(active ? Ink.onAccent : Ink.text2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .textSelection(.disabled)
                        .padding(.horizontal, small ? 6 : 0)
                        .frame(maxWidth: .infinity, minHeight: small ? 32 : 36)
                        .background(active ? Ink.accent : .clear, in: RoundedRectangle(cornerRadius: Radius.input - 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(maxWidth: small ? 260 : .infinity)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .hairlineBorder(radius: Radius.input)
    }
}

/// `.chip`: a status or fact in a line of text, with no box. `accent` adds a small dot in the accent line colour.
struct Chip: View {
    let text: String
    var accent = false
    /// A different text colour (the review chip is warn-text, a stale chip text-3).
    var tint: Color?

    var body: some View {
        HStack(spacing: 5) {
            if accent {
                Circle().fill(Ink.accentLine).frame(width: 6, height: 6)
            }
            Text(text).lineLimit(1)
        }
        .clack(.chip)
        .foregroundStyle(tint ?? (accent ? Ink.text : Ink.text2))
    }
}

/// `.chip-button`: a filter. Active is yellow; `removable` adds an x.
struct ChipButton: View {
    let text: String
    var active = false
    var removable = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(text)
                if removable {
                    LucideIcon(name: "x", size: 14).foregroundStyle(active ? Ink.onAccent : Ink.text2)
                }
            }
            .clack(.chipButton)
            .foregroundStyle(active ? Ink.onAccent : Ink.text)
            .textSelection(.disabled)
            .padding(.horizontal, 14)
            .frame(minHeight: 34)
            .background(active ? Ink.accent : Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
            .hairlineBorder(radius: Radius.controlSm, color: active ? Ink.accent : Ink.hairline)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

/// `.pill`: a quiet label on a soft fill (radius 10, not a capsule).
struct Pill: View {
    let text: String

    var body: some View {
        Text(text)
            .clack(.chipButton)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Ink.fillSoft, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
    }
}

/// `.map-button`: a 40 pt glass circle floating over a map; pressed or toggled on it turns yellow.
struct MapButton: View {
    let icon: String
    let label: String
    var pressed = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            LucideIcon(name: icon, size: 18)
                .foregroundStyle(pressed ? Ink.onAccent : Ink.text)
                .frame(width: 40, height: 40)
                .background {
                    Circle().fill(pressed ? Ink.accent : Ink.glass)
                    if !pressed { Circle().fill(.ultraThinMaterial).opacity(0.5) }
                }
                .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
                .clackShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(pressed ? .isSelected : [])
    }
}
