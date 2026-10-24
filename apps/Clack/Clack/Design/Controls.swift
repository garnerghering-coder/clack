//
//  Controls.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The app's buttons are the system's (owner, 2026-10-25: "they should feel like Apple buttons"): `primary` is
/// bordered-prominent in the accent yellow, `secondary` bordered in a neutral tint, `danger` bordered with the
/// destructive role's red. Sizes are the system's control sizes, the label is SF, and the corners use the radius
/// tokens. `wide` stretches the button to the width it is given; side-by-side buttons share it equally.
struct ClackButtonStyle: PrimitiveButtonStyle {
    enum Kind { case secondary, primary, danger }

    var kind: Kind = .secondary
    var small = false
    var wide = false

    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: kind == .danger ? .destructive : configuration.role, action: configuration.trigger) {
            configuration.label
                .clack(small ? .buttonSmall : .button)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: wide ? .infinity : nil)
                .textSelection(.disabled)
        }
        .controlSize(small ? .regular : .large)
        .buttonBorderShape(.roundedRectangle(radius: small ? Radius.controlSm : Radius.input))
        // A small button still has a 44 pt target (DESIGN §16).
        .frame(minHeight: 44)
        .contentShape(Rectangle())

        switch kind {
        case .primary:
            button.buttonStyle(.borderedProminent).tint(Ink.accent).foregroundStyle(Ink.onAccent)
        case .secondary:
            // A quiet grey fill (the tint) under a full-strength label.
            button.buttonStyle(.bordered).tint(Ink.text3).foregroundStyle(Ink.text)
        case .danger:
            button.buttonStyle(.bordered).tint(Ink.veryLate)
        }
    }
}

extension PrimitiveButtonStyle where Self == ClackButtonStyle {
    static func clack(_ kind: ClackButtonStyle.Kind = .secondary, small: Bool = false, wide: Bool = false) -> ClackButtonStyle {
        ClackButtonStyle(kind: kind, small: small, wide: wide)
    }
}

/// A floating control over a map or the camera: Liquid Glass on iOS 26 and later, the bordered style before.
struct GlassControlStyle: PrimitiveButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        let button = Button(role: configuration.role, action: configuration.trigger) {
            configuration.label.clack(.button).lineLimit(1)
        }
        .controlSize(.large)
        if #available(iOS 26.0, *) {
            if prominent {
                button.buttonStyle(.glassProminent).tint(Ink.accent).foregroundStyle(Ink.onAccent)
            } else {
                button.buttonStyle(.glass).tint(Ink.text)
            }
        } else {
            if prominent {
                button.buttonStyle(.borderedProminent).tint(Ink.accent).foregroundStyle(Ink.onAccent)
            } else {
                button.buttonStyle(.bordered).tint(Ink.text)
            }
        }
    }
}

extension PrimitiveButtonStyle where Self == GlassControlStyle {
    static func glassControl(prominent: Bool = false) -> GlassControlStyle { GlassControlStyle(prominent: prominent) }
}

/// An inline action in a line of text or under a card: accent-ink text, no box, no underline (the system's borderless
/// style). At least 44 pt high, so it is as easy to hit as any button (DESIGN §16).
struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .clack(.button)
            .foregroundStyle(Ink.accentInk)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .textSelection(.disabled)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// `.segmented`: the system segmented control, equal segments.
struct SegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    var small = false

    var body: some View {
        // The system's segmented control (owner, 2026-10-25: native controls over hand-drawn ones).
        Picker(selection: $selection) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option.label).tag(option.value)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(small ? .regular : .large)
        .frame(maxWidth: small ? 260 : .infinity)
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
            // 34 pt to look at, 44 pt to hit.
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
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
            MapButtonFace(icon: icon, pressed: pressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(pressed ? .isSelected : [])
    }
}

/// How a map button looks, also the label of a `Menu` over a map: Liquid Glass on iOS 26 and later (yellow-tinted when
/// on), the app's glass colour with a blur before. 44 pt, the system's hit size.
struct MapButtonFace: View {
    let icon: String
    var pressed = false
    /// An SF Symbol instead of a Lucide icon (the system's "…" for a menu).
    var symbol: String?

    var body: some View {
        let glyph = Group {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 17, weight: .semibold))
            } else {
                LucideIcon(name: icon, size: 18)
            }
        }
        .foregroundStyle(pressed ? Ink.onAccent : Ink.text)
        .frame(width: 44, height: 44)
        if #available(iOS 26.0, *) {
            glyph
                .glassEffect(pressed ? .regular.tint(Ink.accent).interactive() : .regular.interactive(), in: Circle())
        } else {
            glyph
                .background {
                    Circle().fill(pressed ? Ink.accent : Ink.glass)
                    if !pressed { Circle().fill(.ultraThinMaterial).opacity(0.5) }
                }
                .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
                .clackShadow()
        }
    }
}
