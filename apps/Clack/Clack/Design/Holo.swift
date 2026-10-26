//
//  Holo.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Lives with the design system: it is artwork (a yellow passport cover in its own fixed inks), like the medals.
///
/// The holographic passport surface, drawn once for the Passport card (where `shine` follows the phone) and the share
/// cards (where it is frozen mid-sweep): the guilloche rings, the pearly foil, the sheen and the glint (DESIGN.md,
/// "Holographic surface & share cards").

/// The pearly spectrum: soft pink, lilac, ice blue, mint, champagne, like the foil stamped into a real passport, not a
/// neon rainbow. `shine` (0 to 1) slides it across.
func holoPearl(_ shine: Double) -> LinearGradient {
    LinearGradient(
        colors: [Color(hex: "#f3c4e4")!, Color(hex: "#cdbdf2")!, Color(hex: "#b9dcf2")!, Color(hex: "#c4ecd6")!, Color(hex: "#f4e6b8")!, Color(hex: "#f3c4e4")!],
        startPoint: UnitPoint(x: shine - 0.6, y: 0), endPoint: UnitPoint(x: shine + 0.6, y: 1)
    )
}

/// Fine concentric lines, the security-print pattern on passports and banknotes. `scale` makes the rings and lines
/// coarser for a bigger surface, so a 1080 px share card has the same look as a 350 pt card.
struct Guilloche: View {
    var scale: CGFloat = 1

    var body: some View {
        Canvas { context, size in
            let ink = Color(red: 120 / 255, green: 70 / 255, blue: 0)
            func rings(_ cx: Double, _ cy: Double, step: Double, alpha: Double) {
                let maxR = hypot(size.width * 1.8, size.height * 1.8)
                var r = step * scale
                while r < maxR {
                    context.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(alpha)), lineWidth: scale)
                    r += (step + 1) * scale
                }
            }
            rings(size.width * 0.78, size.height * 0.2, step: 9, alpha: 0.9)
            rings(size.width * 0.1, size.height * 0.95, step: 13, alpha: 0.7)
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}

/// The foil, the sheen and the glint, over whatever is under them. `shine` is where the light sits across the surface
/// (0 to 1; the middle with Reduce Motion). `sweep` plays the sheen's slide in once (the Passport card flips it after it
/// appears); a still image just passes true.
struct HoloSurface: View {
    var shine: Double
    var sweep = true
    var scale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let t = reduceMotion ? 0.5 : shine
        ZStack {
            // A holographic foil: strongest along the guilloche lines, with a faint wash over the rest.
            ZStack {
                holoPearl(t).opacity(0.14)
                holoPearl(t).mask(Guilloche(scale: scale)).opacity(0.45)
            }
            .blendMode(.overlay)
            GeometryReader { proxy in
                LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .white.opacity(0.75), location: 0.45), .init(color: .clear, location: 0.6)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 2.5)
                    .offset(x: sweep || reduceMotion ? -proxy.size.width * 2.5 * 0.45 + proxy.size.width * (reduceMotion ? 0.3 : shine) : proxy.size.width * 0.4)
                    .blendMode(.overlay)
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.6).delay(0.3), value: sweep)
                // The metallic glint: a narrow bright line that runs ahead of the sheen as the phone tilts.
                LinearGradient(stops: [.init(color: .clear, location: 0.46), .init(color: .white.opacity(0.9), location: 0.5), .init(color: .clear, location: 0.54)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: proxy.size.width * 2)
                    .offset(x: -proxy.size.width + proxy.size.width * 1.6 * (reduceMotion ? 0.3 : shine))
                    .blendMode(.softLight)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Signal yellow deepening to amber, lit from the top left like a passport cover under a lamp, with guilloche lines and
/// the holographic surface on top.
struct PassportCover: View {
    var shine: Double
    var sweep = true
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            CSSLinearGradient(angle: 155, stops: [
                .init(color: Color(hex: "#ffe169")!, location: 0), .init(color: Color(hex: "#f8d64a")!, location: 0.45), .init(color: Color(hex: "#eab21c")!, location: 1),
            ])
            CSSRadialGradient(rx: 0.9, ry: 0.9, cx: 1, cy: 1, stops: [.init(color: Color(hex: "#d99a00")!, location: 0), .init(color: Color(hex: "#d99a00")!.opacity(0), location: 0.6)])
            CSSRadialGradient(rx: 1.2, ry: 0.8, cx: 0, cy: 0, stops: [.init(color: Color(hex: "#fff3b0")!, location: 0), .init(color: Color(hex: "#fff3b0")!.opacity(0), location: 0.55)])
            Guilloche(scale: scale).opacity(0.16)
            HoloSurface(shine: shine, sweep: sweep, scale: scale)
        }
    }
}

/// The machine-readable-zone line along the bottom of a passport page, spelled out from your own totals (decoration;
/// nothing personal). A card passes only the numbers it already prints; the rest are left out of the line.
enum PassportMRZ {
    static func line(year: Int?, km: Double, journeys: Int? = nil, stations: Int? = nil, countries: Int? = nil) -> String {
        var text = "P<CLACK<<\(year.map(String.init) ?? "ALL")<<KM\(Int(km.rounded()))"
        if let journeys { text += "<<J\(journeys)" }
        if let stations { text += "<<S\(stations)" }
        if let countries { text += "<<C\(countries)" }
        return String((text + String(repeating: "<", count: 44)).prefix(44))
    }
}
