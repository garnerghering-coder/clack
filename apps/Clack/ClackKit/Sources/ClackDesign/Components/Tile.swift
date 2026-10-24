//
//  Tile.swift
//  ClackDesign
//

import SwiftUI

/// A fact as a small block: the label above, the value under it (`caption` + `headline`), on the raised surface with
/// the input radius and 12 pt of padding. An optional caption line under the value (where a record was set). On the
/// Passport's yellow cover (`onAccent`) the same tile is drawn in black ink on a faint dark tint.
public struct Tile<Value: View>: View {
    public typealias Tone = TileTone

    public let label: String
    public var sub: String?
    public var tone: Tone = .standard
    @ViewBuilder public var value: Value

    public init(label: String, sub: String? = nil, tone: Tone = .standard, @ViewBuilder value: () -> Value) {
        self.label = label
        self.sub = sub
        self.tone = tone
        self.value = value()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).clack(.caption).foregroundStyle(secondary).lineLimit(2)
            value
                .clack(.headline).monospacedDigit().foregroundStyle(primary)
                .lineLimit(1).minimumScaleFactor(0.7)
            if let sub { Text(sub).clack(.caption).foregroundStyle(secondary).lineLimit(1) }
        }
        .tileSurface(tone)
        .accessibilityElement(children: .combine)
    }

    private var primary: Color { tone == .onAccent ? Ink.onAccent : Ink.text }
    private var secondary: Color { tone == .onAccent ? Ink.onAccent.opacity(0.62) : Ink.text2 }
}

extension Tile where Value == Text {
    /// A tile whose value is a line of text.
    public init(label: String, value: String, sub: String? = nil, tone: Tone = .standard) {
        self.init(label: label, sub: sub, tone: tone) { Text(value) }
    }
}

/// Where a tile sits: on the app's surfaces, or on the Passport's yellow cover.
public enum TileTone: Sendable { case standard, onAccent }

extension View {
    /// The tile's surface (raised, input radius, 12 pt padding, full width) for a block that lays out its own content.
    public func tileSurface(_ tone: TileTone = .standard) -> some View {
        padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                tone == .onAccent ? Ink.onAccent.opacity(0.08) : Ink.surfaceRaised,
                in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
            )
    }
}
