//
//  Medal.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Milestone medals (owner feedback: "like Apple Health or Duolingo"): a ribbon, a metal rim whose metal steps up with
/// each level of a milestone family (bronze, silver, gold, platinum), a coloured face per family and the target or an
/// icon in the middle. Upcoming ones are greyed out, with a ring showing how far along you are (Medal.tsx).
nonisolated enum MedalStyle {
    /// Face colours per family: light, dark.
    static func face(_ family: MilestoneFamily) -> (String, String) {
        switch family {
        case .journeys: ("#ffe27a", "#d9a400")
        case .distanceKm: ("#7db7ff", "#2563d9")
        case .stations: ("#7ef0b0", "#1f9e5c")
        case .operators: ("#ffb08a", "#e0582a")
        case .countries: ("#cfa8ff", "#7d3fd6")
        case .borderCrossings: ("#ff8fa3", "#d12a4a")
        case .nightTrains: ("#9aa6ff", "#3242b8")
        case .longestTrainKm: ("#d4f07a", "#6b9a14")
        case .hoursOnBoard: ("#6fe0d0", "#12857a")
        case .trainTypes: ("#ffc66b", "#b86a00")
        case .kindsOfTrain: ("#f59be8", "#b3239c")
        case .arcticCircle: ("#bdf0ff", "#2aa7cf")
        case .homeLength: ("#d9b38c", "#8a5a2b")
        case .europeLength: ("#b8c6d9", "#4a5f7a")
        case .unknown: ("#e5e5e5", "#8e8e8e")
        }
    }

    static func icon(_ family: MilestoneFamily, target: Double) -> String {
        if target >= 40_000 { return "globe" }
        switch family {
        case .journeys: return "train-front"
        case .distanceKm: return "route"
        case .stations: return "map-pin"
        case .operators: return "ticket"
        case .countries: return "globe"
        case .borderCrossings: return "flag"
        case .nightTrains: return "moon"
        case .longestTrainKm: return "ruler"
        case .hoursOnBoard: return "hourglass"
        case .trainTypes: return "layers"
        case .kindsOfTrain: return "train-track"
        case .arcticCircle: return "snowflake"
        case .homeLength: return "flag"
        case .europeLength: return "globe"
        case .unknown: return "star"
        }
    }

    /// The one ink for a medal's number and icon: the family's dark face colour taken 80% of the way to black. 80%, not
    /// less, because the number sits mid-gradient and the darker faces (night trains, countries, Europe) need it for 4.5:1.
    static func ink(_ family: MilestoneFamily) -> Color {
        let hex = face(family).1.dropFirst()
        let value = UInt64(hex, radix: 16) ?? 0x8e8e8e
        let keep = 0.2
        return Color(
            red: Double((value >> 16) & 0xff) / 255 * keep,
            green: Double((value >> 8) & 0xff) / 255 * keep,
            blue: Double(value & 0xff) / 255 * keep
        )
    }

    /// Bronze, silver, gold, platinum: light, dark.
    static let metals: [(String, String)] = [("#f0b27a", "#9c5a25"), ("#f4f4f4", "#8e8e8e"), ("#ffe9a0", "#c48a1c"), ("#e9f7ff", "#7fa7c2")]

    /// The thresholds per family, to know which level a target is (mirrors MILESTONES on the server).
    static func levels(_ family: MilestoneFamily) -> [Double] {
        switch family {
        case .journeys: [1, 10, 25, 50, 100, 250]
        case .distanceKm: [100, 500, 1000, 2500, 5000, 10_000, 40_075]
        case .stations: [10, 25, 50, 100, 200]
        case .operators: [3, 5, 10]
        case .countries: [2, 3, 5]
        case .borderCrossings, .nightTrains: [1, 5, 10, 25]
        case .longestTrainKm: [300, 500, 1000]
        case .hoursOnBoard: [10, 50, 100, 250]
        case .trainTypes: [5, 10, 20]
        case .kindsOfTrain: [5]
        case .arcticCircle, .homeLength, .europeLength, .unknown: [1]
        }
    }

    static func metal(_ m: Milestone) -> (String, String) {
        let levels = levels(m.family)
        if levels.count == 1 { return metals[2] }
        let i = max(0, levels.firstIndex(of: m.target) ?? 0)
        return metals[min(metals.count - 1, (i * metals.count) / levels.count)]
    }

    /// "1k", "2.5k", "10k"; the first ones, once-around-the-Earth and the one-off medals get an icon instead of a number.
    static func centre(_ m: Milestone) -> String? {
        if m.target == 1 || m.target >= 40_000 || levels(m.family).count == 1 { return nil }
        if m.target >= 1000 {
            let k = m.target / 1000
            return (k == k.rounded() ? String(Int(k)) : String(format: "%.1f", k)) + "k"
        }
        return String(Int(m.target))
    }
}

/// bare: no number (share cards draw it in their own font). foil: where the pearly sheen sits (0 to 1), for the share
/// cards, which put a holographic sheen on each medal's face (Holo.swift); nil is no sheen.
struct Medal: View {
    let m: Milestone
    var locked = false
    var size: CGFloat = 92
    var bare = false
    var foil: Double?

    var body: some View {
        let (f0, f1) = MedalStyle.face(m.family)
        let (m0, m1) = MedalStyle.metal(m)
        let c0 = Color(hex: f0) ?? .gray, c1 = Color(hex: f1) ?? .gray
        let k0 = Color(hex: m0) ?? .gray, k1 = Color(hex: m1) ?? .gray
        let text = MedalStyle.centre(m)
        let progress: Double? = locked ? m.value.map { min(1, $0 / m.target) } : nil
        let scale = size / 120
        ZStack {
            Canvas { context, _ in
                var ctx = context
                ctx.scaleBy(x: scale, y: scale)
                func polygon(_ points: [(Double, Double)], _ color: Color) {
                    var path = Path()
                    path.move(to: CGPoint(x: points[0].0, y: points[0].1))
                    for point in points.dropFirst() { path.addLine(to: CGPoint(x: point.0, y: point.1)) }
                    path.closeSubpath()
                    ctx.fill(path, with: .color(color))
                }
                // Ribbon
                polygon([(30, 0), (54, 0), (70, 62), (48, 66)], c1)
                polygon([(90, 0), (66, 0), (50, 62), (72, 66)], c0)
                polygon([(54, 0), (66, 0), (60, 24)], .black.opacity(0.18))
                // Rim: a gradient across the circle's box, top-left to bottom-right.
                let rim = Path(ellipseIn: CGRect(x: 17, y: 53, width: 86, height: 86))
                ctx.fill(rim, with: .linearGradient(
                    Gradient(stops: [.init(color: k0, location: 0), .init(color: k1, location: 0.55), .init(color: k0, location: 1)]),
                    startPoint: CGPoint(x: 17, y: 53), endPoint: CGPoint(x: 103, y: 139)
                ))
                // Face: a radial gradient centred up and left.
                let face = Path(ellipseIn: CGRect(x: 26, y: 62, width: 68, height: 68))
                ctx.fill(face, with: .radialGradient(
                    Gradient(colors: [c0, c1]), center: CGPoint(x: 26 + 68 * 0.35, y: 62 + 68 * 0.3), startRadius: 0, endRadius: 68 * 0.9
                ))
                ctx.stroke(face, with: .color(.white.opacity(0.35)), lineWidth: 1.5)
                ctx.stroke(Path(ellipseIn: CGRect(x: 21.5, y: 57.5, width: 77, height: 77)), with: .color(.black.opacity(0.18)), lineWidth: 1)
                // The share cards' foil: the pearly spectrum over the face, under the number and icon so they keep their ink.
                if let foil, !locked {
                    let pearl = ["#f3c4e4", "#cdbdf2", "#b9dcf2", "#c4ecd6", "#f4e6b8", "#f3c4e4"].map { Color(hex: $0) ?? .white }
                    var foilCtx = ctx
                    foilCtx.blendMode = .overlay
                    foilCtx.fill(face, with: .linearGradient(
                        Gradient(colors: pearl.map { $0.opacity(0.6) }),
                        startPoint: CGPoint(x: 26 + 68 * (foil - 0.6), y: 62), endPoint: CGPoint(x: 26 + 68 * (foil + 0.6), y: 130)
                    ))
                }
                // Number and icon
                let ink = MedalStyle.ink(m.family)
                if let text {
                    if !bare {
                        let fontSize: CGFloat = text.count > 3 ? 21 : 26
                        let y: CGFloat = text.count > 3 ? 113 : 115
                        ctx.draw(
                            Text(text).font(ClackFont.grotesk(fontSize)).foregroundColor(ink),
                            at: CGPoint(x: 60, y: y - fontSize * 0.36), anchor: .center
                        )
                    }
                    drawIcon(&ctx, name: MedalStyle.icon(m.family, target: m.target), rect: CGRect(x: 53, y: 68, width: 14, height: 14), ink: ink)
                } else {
                    drawIcon(&ctx, name: MedalStyle.icon(m.family, target: m.target), rect: CGRect(x: 42, y: 78, width: 36, height: 36), ink: ink)
                }
                // Shine
                var shine = Path(ellipseIn: CGRect(x: 28, y: 65, width: 36, height: 18))
                shine = shine.applying(CGAffineTransform(translationX: -46, y: -74).concatenating(CGAffineTransform(rotationAngle: -30 * .pi / 180)).concatenating(CGAffineTransform(translationX: 46, y: 74)))
                ctx.fill(shine, with: .color(.white.opacity(0.28)))
            }
            .saturation(locked ? 0 : 1)
            .opacity(locked ? 0.38 : 1)

            // An upcoming medal fills its own rim as you get closer (drawn over the greyed body, in colour).
            if let progress, progress > 0 {
                Canvas { context, _ in
                    var ctx = context
                    ctx.scaleBy(x: scale, y: scale)
                    var arc = Path()
                    arc.addArc(center: CGPoint(x: 60, y: 96), radius: 38.5, startAngle: .degrees(-90), endAngle: .degrees(-90 + 360 * progress), clockwise: false)
                    ctx.stroke(arc, with: .color(Ink.accent), style: StrokeStyle(lineWidth: 8.5, lineCap: .round))
                }
            }
        }
        .frame(width: size, height: size * 1.25)
        .shadow(color: .black.opacity(0.35), radius: 5, y: 6)
        .accessibilityHidden(true)
    }

    /// The icon in `ink`. The tint is a fill over the icon's own shape (a layer drawn with source-atop): setting the
    /// resolved image's shading left these template icons white, so the number was dark and the icon was not.
    private func drawIcon(_ ctx: inout GraphicsContext, name: String, rect: CGRect, ink: Color) {
        let image = ctx.resolve(Image("lucide-\(name)", bundle: ClackDesignBundle.bundle).renderingMode(.template))
        ctx.drawLayer { layer in
            layer.draw(image, in: rect)
            layer.blendMode = .sourceAtop
            layer.fill(Path(rect), with: .color(ink))
        }
    }
}

// `L10n.milestoneLabel` is in ClackCore (Logic/Words.swift), so the widgets word medals the same way.
