//
//  Medal.swift
//  Clack
//

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
        case .unknown: return "star"
        }
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
        case .borderCrossings, .nightTrains, .unknown: [1]
        }
    }

    static func metal(_ m: Milestone) -> (String, String) {
        let levels = levels(m.family)
        if levels.count == 1 { return metals[2] }
        let i = max(0, levels.firstIndex(of: m.target) ?? 0)
        return metals[min(metals.count - 1, (i * metals.count) / levels.count)]
    }

    /// "1k", "2.5k", "10k"; the first ones and once-around-the-Earth get an icon instead of a number.
    static func centre(_ m: Milestone) -> String? {
        if m.target == 1 || m.target >= 40_000 { return nil }
        if m.target >= 1000 {
            let k = m.target / 1000
            return (k == k.rounded() ? String(Int(k)) : String(format: "%.1f", k)) + "k"
        }
        return String(Int(m.target))
    }
}

/// bare: no number (share cards draw it in their own font).
struct Medal: View {
    let m: Milestone
    var locked = false
    var size: CGFloat = 92
    var bare = false

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
                // Number and icon
                let ink = Color.black.opacity(0.72)
                if let text {
                    if !bare {
                        let fontSize: CGFloat = text.count > 3 ? 21 : 26
                        let y: CGFloat = text.count > 3 ? 113 : 115
                        ctx.draw(
                            Text(text).font(ClackFont.grotesk(fontSize)).foregroundColor(ink),
                            at: CGPoint(x: 60, y: y - fontSize * 0.36), anchor: .center
                        )
                    }
                    drawIcon(&ctx, name: MedalStyle.icon(m.family, target: m.target), rect: CGRect(x: 53, y: 68, width: 14, height: 14), alpha: 0.55)
                } else {
                    drawIcon(&ctx, name: MedalStyle.icon(m.family, target: m.target), rect: CGRect(x: 42, y: 78, width: 36, height: 36), alpha: 0.62)
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

    private func drawIcon(_ ctx: inout GraphicsContext, name: String, rect: CGRect, alpha: Double) {
        var image = ctx.resolve(Image("lucide-\(name)").renderingMode(.template))
        image.shading = .color(.black.opacity(alpha))
        ctx.draw(image, in: rect)
    }
}

extension L10n {
    /// What a milestone takes, in words ("10 journeys", "1,000 km", "First border crossing").
    func milestoneLabel(_ m: Milestone, language: Language) -> String {
        switch m.family {
        case .distanceKm:
            if m.target >= 40_000 { return t("passport.milestone.earth") }
            let formatter = NumberFormatter()
            formatter.locale = Format.locale(language)
            formatter.numberStyle = .decimal
            return t("passport.milestone.distanceKm", ["n": formatter.string(from: NSNumber(value: m.target)) ?? String(Int(m.target))])
        case .journeys where m.target == 1:
            return t("passport.milestone.firstJourney")
        default:
            return t("passport.milestone.\(m.family.rawValue)", count: Int(m.target))
        }
    }
}
