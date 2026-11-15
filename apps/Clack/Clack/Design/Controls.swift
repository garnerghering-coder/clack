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

        // Content buttons are solid fills (Look.contentButtons, DECISIONS L2): yellow primary, a quiet grey secondary,
        // a red-labelled danger. With `.glass` (the look before) they are Liquid Glass on iOS 26 and later.
        if #available(iOS 26.0, *), Look.contentButtons == .glass {
            switch kind {
            case .primary:
                button.buttonStyle(.glassProminent).tint(Ink.accent).foregroundStyle(Ink.onAccent)
            case .secondary:
                button.buttonStyle(.glass).tint(Ink.text).foregroundStyle(Ink.text)
            case .danger:
                button.buttonStyle(.glass).tint(Ink.veryLate).foregroundStyle(Ink.veryLate)
            }
        } else {
            switch kind {
            case .primary:
                button.buttonStyle(.borderedProminent).tint(Ink.accent).foregroundStyle(Ink.onAccent)
            case .secondary:
                // A quiet grey fill (the tint) under a full-strength label.
                button.buttonStyle(.bordered).tint(Ink.text3).foregroundStyle(Ink.text)
            case .danger:
                button.buttonStyle(.bordered).tint(Ink.veryLate).foregroundStyle(Ink.veryLateInk)
            }
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

/// A `Menu` drawn only as its own label (owner, 2026-11-15: a half-see-through yellow ring around the "…" and the
/// Settings choices). A menu with a custom label took the app's accent tint, which is yellow in dark mode, as a
/// highlight around it; its items read in ink.
extension View {
    func clackMenu() -> some View {
        menuStyle(.button).buttonStyle(.plain).tint(Ink.text)
    }
}

/// An inline action in a line of text or under a card: the system's borderless button in accent ink, at least 44 pt
/// high so it is as easy to hit as any button (DESIGN §16).
struct LinkButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: configuration.trigger) {
            configuration.label.clack(.button).textSelection(.disabled)
        }
        .buttonStyle(.borderless)
        .tint(Ink.accentInk)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// `.segmented`: the glass switch for two to four fixed choices (owner, 2026-11-07: the Trips Upcoming/Past look is
/// now the one pick-one control across the app): equal segments as plain 44 pt buttons on one glass track, with a
/// yellow glass thumb that slides to the chosen one (Liquid Glass on iOS 26 and later; a raised track and a yellow
/// thumb before). `small` keeps it to 260 pt. Inside a system `Form` use `FormSegmentedControl` instead.
struct SegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    var small = false
    @Namespace private var thumb
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    private var thumbShape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.inner(Radius.input, padding: Space.xs), style: .continuous) }
    private var trackShape: RoundedRectangle { RoundedRectangle(cornerRadius: Radius.input, style: .continuous) }

    var body: some View {
        segments
            .padding(Space.xs)
            .modifier(TrackSurface(shape: trackShape))
            // At the accessibility text sizes a small switch takes the width and its words may wrap (2026-11-08:
            // "Sy… D… Li…" at 260 pt).
            .frame(maxWidth: small && !typeSize.isAccessibilitySize ? 260 : .infinity)
            .textSelection(.disabled)
    }

    private var segments: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let chosen = option.value == selection
                Button {
                    withMotion(.tap, reduceMotion: reduceMotion) { selection = option.value }
                } label: {
                    Text(option.label)
                        .clack(.button)
                        .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(chosen ? Look.onSelection : Ink.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background {
                    if chosen { Thumb(shape: thumbShape).matchedGeometryEffect(id: "thumb", in: thumb) }
                }
                .accessibilityAddTraits(chosen ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// The thumb, in the selection fill (Look.selection: ink, or yellow before): glass tinted with it on iOS 26, the
    /// plain fill before.
    private struct Thumb: View {
        let shape: RoundedRectangle

        var body: some View {
            if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular.tint(Look.selectionFill), in: shape)
            } else {
                shape.fill(Look.selectionFill)
            }
        }
    }

    /// The track under all segments: one glass shape (the thumb joins it in a container, so they blend), or a raised surface.
    private struct TrackSurface: ViewModifier {
        let shape: RoundedRectangle

        func body(content: Content) -> some View {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: Space.s) {
                    content.glassEffect(.regular, in: shape)
                }
            } else {
                content
                    .background(Ink.surfaceRaised, in: shape)
                    .overlay(shape.strokeBorder(Ink.hairline, lineWidth: 1))
            }
        }
    }
}

/// The system's segmented `Picker`, only for rows inside a system `Form` (the Explore filter sheet), where the
/// system's own control belongs; everywhere else `SegmentedControl`.
struct FormSegmentedControl<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Text(option.label).tag(option.value)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.large)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

/// `.chip`: a status or fact in a line of text, with no box. `accent` adds a small dot in the accent line colour.
struct Chip: View {
    let text: String
    var accent = false
    /// A different text colour (the review chip is warn-text, a stale chip text-3).
    var tint: Color?

    var body: some View {
        HStack(spacing: Space.xs) {
            if accent {
                Circle().fill(Ink.accentLine).frame(width: 6, height: 6)
            }
            Text(text).lineLimit(1)
        }
        .clack(.chip)
        .foregroundStyle(tint ?? (accent ? Ink.text : Ink.text2))
    }
}

/// `.chip-button`: a filter, as a small system button: the chosen one in the selection fill (Look.selection: ink, or
/// yellow before), the others grey. `removable` adds an x.
struct ChipButton: View {
    let text: String
    var active = false
    var removable = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                Text(text)
                if removable {
                    LucideIcon(name: "x", size: 14)
                }
            }
            .clack(.buttonSmall)
            .lineLimit(1)
            .textSelection(.disabled)
        }
        .controlSize(.regular)
        .buttonBorderShape(.roundedRectangle(radius: Radius.controlSm))
        .modifier(ChipFill(active: active))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private struct ChipFill: ViewModifier {
        let active: Bool

        func body(content: Content) -> some View {
            if active {
                content.buttonStyle(.borderedProminent).tint(Look.selectionFill).foregroundStyle(Look.onSelection)
            } else {
                content.buttonStyle(.bordered).tint(Ink.text3).foregroundStyle(Ink.text)
            }
        }
    }
}

/// `.map-button`: a 44 pt glass circle floating over a map; toggled on, it takes the selection fill (Look.selection).
struct MapButton: View {
    let icon: String
    let label: String
    var pressed = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            MapButtonFace(icon: icon, pressed: pressed)
        }
        .buttonStyle(.press(radius: 22))
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
        .foregroundStyle(pressed ? Look.onSelection : Ink.text)
        .frame(width: 44, height: 44)
        .contentShape(Circle())
        .textSelection(.disabled)
        if #available(iOS 26.0, *) {
            glyph
                // Not `.interactive()`: interactive glass handles touches itself and took the tap from the button.
                .glassEffect(pressed ? .regular.tint(Look.selectionFill) : .regular, in: Circle())
        } else {
            glyph
                .background {
                    Circle().fill(pressed ? Look.selectionFill : Ink.glass)
                    if !pressed { Circle().fill(.ultraThinMaterial).opacity(0.5) }
                }
                .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
                .clackShadow()
        }
    }
}

/// A row that opens more: its words, then a chevron, the full width and at least 44 pt high (designer, 2026-11-14:
/// "All milestones" looked like an underlined web link and "How we calculate this" like another kind of link). Put it
/// in a `NavigationLink` or `Button` with `.buttonStyle(.pressRow)`.
struct DisclosureRowLabel: View {
    let title: String
    var detail: String?

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title).clack(.rowTitle).foregroundStyle(Ink.text)
            if let detail { Text(detail).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2) }
            Spacer(minLength: Space.s)
            LucideIcon(name: "chevron-right", size: 16).foregroundStyle(Ink.text3)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .textSelection(.disabled)
    }
}
