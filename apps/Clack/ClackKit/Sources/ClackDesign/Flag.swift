//
//  Flag.swift
//  Clack
//

import ClackCore
import SwiftUI

/// Circular country flags (Flighty shows round flags next to airports), drawn as shapes so they look the same
/// everywhere (Flag.tsx). Countries without one get a grey disc.
public struct Flag: View {
    public let country: String
    public var size: CGFloat = 44
    /// Hides it from VoiceOver when the country is already written next to it.
    public var decorative = false

    public var body: some View {
        Canvas { context, canvas in
            let s = canvas.width / 32
            func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: String) {
                context.fill(Path(CGRect(x: x * s, y: y * s, width: w * s, height: h * s)), with: .color(Color(hex: color) ?? .gray))
            }
            switch country {
            case "SE":
                rect(0, 0, 32, 32, "#006aa7"); rect(9, 0, 5, 32, "#fecc00"); rect(0, 13.5, 32, 5, "#fecc00")
            case "DK":
                rect(0, 0, 32, 32, "#c8102e"); rect(9, 0, 4.5, 32, "#ffffff"); rect(0, 13.75, 32, 4.5, "#ffffff")
            case "NO":
                rect(0, 0, 32, 32, "#ba0c2f"); rect(8, 0, 8, 32, "#ffffff"); rect(0, 12, 32, 8, "#ffffff")
                rect(10, 0, 4, 32, "#00205b"); rect(0, 14, 32, 4, "#00205b")
            case "FI":
                rect(0, 0, 32, 32, "#ffffff"); rect(8.5, 0, 5.5, 32, "#003580"); rect(0, 13.25, 32, 5.5, "#003580")
            case "DE":
                rect(0, 0, 32, 11, "#000000"); rect(0, 10.67, 32, 11, "#dd0000"); rect(0, 21.33, 32, 11, "#ffce00")
            case "AT":
                rect(0, 0, 32, 32, "#ed2939"); rect(0, 10.67, 32, 10.67, "#ffffff")
            default:
                rect(0, 0, 32, 32, "#555555")
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(decorative)
        .accessibilityLabel(country)
    }

    public init(country: String, size: CGFloat = 44, decorative: Bool = false) {
        self.country = country
        self.size = size
        self.decorative = decorative
    }
}

/// A station in search results and lists: round flag, name, and county (or country abroad). Trafikverket's codes are
/// internal shorthand, so they stay out of the list (owner feedback).
public struct StationRow: View {
    @Environment(L10n.self) private var l10n
    public let station: StationHit
    public var trailing: AnyView?
    public let onPick: () -> Void

    public var body: some View {
        Button(action: onPick) {
            HStack(spacing: 12) {
                Flag(country: station.country, size: 32, decorative: true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(station.name).clack(.rowTitle).foregroundStyle(Ink.text)
                    Text(station.county ?? countryName).clack(.caption).foregroundStyle(Ink.text2)
                }
                Spacer(minLength: 0)
                trailing
            }
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var countryName: String {
        let key = "countries.\(station.country)"
        let name = l10n.t(key)
        return name == key ? station.country : name
    }

    public init(station: StationHit, trailing: AnyView? = nil, onPick: @escaping () -> Void) {
        self.station = station
        self.trailing = trailing
        self.onPick = onPick
    }
}
