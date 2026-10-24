//
//  IconButton.swift
//  ClackDesign
//

import SwiftUI

/// The size of a round icon button: 44 pt everywhere (DESIGN §16), 34 pt only for the small ones over a map.
public enum IconButtonSize: Sendable {
    case regular, overMap

    var diameter: CGFloat { self == .regular ? 44 : 34 }
    var icon: CGFloat { self == .regular ? 20 : 16 }
}

/// The circle every icon button is drawn in: raised surface, hairline ring, the icon in the middle.
private struct IconCircle: View {
    let icon: String
    let size: IconButtonSize
    let tint: Color
    var filled = false

    var body: some View {
        LucideIcon(name: icon, size: size.icon, filled: filled)
            .foregroundStyle(tint)
            .frame(width: size.diameter, height: size.diameter)
            .background(Ink.surfaceRaised, in: Circle())
            .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
            .contentShape(Circle())
    }
}

/// `.icon-button`: a round button with one icon and a label from the strings (VoiceOver reads it). A toggle
/// (`selected` not nil) fills its icon in the accent ink when on (the favourite star) and says it is selected.
public struct IconButton: View {
    public let icon: String
    public let label: String
    public var size: IconButtonSize = .regular
    public var tint: Color = Ink.text
    public var selected: Bool?
    public let action: () -> Void

    public init(
        icon: String, label: String, size: IconButtonSize = .regular, tint: Color = Ink.text, selected: Bool? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.size = size
        self.tint = tint
        self.selected = selected
        self.action = action
    }

    public var body: some View {
        let on = selected == true
        Button(action: action) {
            IconCircle(icon: icon, size: size, tint: on ? Ink.accentInk : tint, filled: on)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The same round button as a link to a screen (`NavigationLink(value:)`).
public struct IconLink<Value: Hashable>: View {
    public let icon: String
    public let label: String
    public let value: Value

    public init(icon: String, label: String, value: Value) {
        self.icon = icon
        self.label = label
        self.value = value
    }

    public var body: some View {
        NavigationLink(value: value) {
            IconCircle(icon: icon, size: .regular, tint: Ink.text)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
