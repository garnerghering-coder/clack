//
//  ShareCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI
import UniformTypeIdentifiers

/// Lives with the design system: it is artwork rendered to a fixed-size image, always dark whatever the theme, so it
/// keeps its own fixed colours and pixel sizes.
///
/// The card itself, 1080 × 1350 (4:5): dark, with a warm glow and faint rings, like the Passport's top card at night.
/// Left out on purpose: times, ticket or booking details, train numbers, anything about where you are now.
struct ShareCardView: View {
    static let width: CGFloat = 1080
    static let height: CGFloat = 1350
    /// The map's box on a stats card, in card pixels (the snapshot is taken at half this, at pixel ratio 2).
    static let mapBox = CGSize(width: 952, height: 500)
    private static let margin: CGFloat = 64
    private static let accent = Color(hex: "#f8d64a")!
    private static let text2 = Color(hex: "#a6a6a6")!

    enum Layout { case stats, medal }
    struct Stat: Hashable { var value: String; var label: String }
    struct Route { var geometry: String?; var ends: [LatLon] }
    struct Label { var at: LatLon; var text: String }
    struct CardMedal { var milestone: Milestone; var label: String }

    var layout: Layout
    var kicker: String
    var title: String
    var sub: String?
    var heroValue: String
    var heroUnit: String
    var stats: [Stat]
    var routes: [Route]
    var labels: [Label]
    var medals: [CardMedal]
    /// The real map behind the routes, when one could be drawn.
    var map: ShareMapSnapshot?

    var body: some View {
        ZStack(alignment: .topLeading) {
            background
            VStack(alignment: .leading, spacing: 0) {
                header
                if layout == .medal { medalLayout } else { statsLayout }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Self.margin)
            .padding(.top, 52)
        }
        .frame(width: Self.width, height: Self.height)
        .clipped()
    }

    private var background: some View {
        ZStack {
            Color(hex: "#0a0a0a")!
            RadialGradient(colors: [Self.accent.opacity(0.2), Self.accent.opacity(0)], center: UnitPoint(x: 0.95, y: 0), startRadius: 0, endRadius: Self.width)
            Canvas { context, size in
                var r = 40.0
                while r < 1500 {
                    context.stroke(Path(ellipseIn: CGRect(x: size.width * 0.9 - r, y: size.height * 0.05 - r, width: r * 2, height: r * 2)), with: .color(Self.accent.opacity(0.05)), lineWidth: 1.5)
                    r += 22
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            Wordmark(fontSize: 36)
            Text(kicker.uppercased()).font(ClackFont.inter(26, .heavy)).foregroundStyle(Self.accent).padding(.top, 52)
        }
    }

    private var statsLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(ClackFont.grotesk(72)).fontWeight(.heavy).foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.6).padding(.top, 14)
            RouteMap(routes: routes, labels: labels, snapshot: map)
                .frame(height: medals.isEmpty ? 540 : 500)
                .padding(.top, 30)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(heroValue).font(ClackFont.grotesk(140)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                Text(heroUnit).font(ClackFont.grotesk(52)).foregroundStyle(Self.text2)
            }
            .padding(.top, 20)
            statsRow(center: false).padding(.top, 20)
            if !medals.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(medals.prefix(4).enumerated()), id: \.offset) { _, md in
                        VStack(spacing: 6) {
                            Medal(m: md.milestone, size: 104)
                            Text(md.label).font(ClackFont.inter(20, .bold)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 30)
            }
        }
    }

    private var medalLayout: some View {
        VStack(spacing: 0) {
            if let md = medals.first { Medal(m: md.milestone, size: 460).padding(.top, 20) }
            Text(title).font(ClackFont.grotesk(72)).fontWeight(.heavy).foregroundStyle(.white).multilineTextAlignment(.center)
                .lineLimit(2).minimumScaleFactor(0.6).padding(.top, 36)
            if let sub { Text(sub).font(ClackFont.inter(30, .semibold)).foregroundStyle(Self.text2).padding(.top, 14) }
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 2).padding(.top, 50)
            statsRow(center: true).padding(.top, 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func statsRow(center: Bool) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(stats, id: \.self) { stat in
                VStack(alignment: center ? .center : .leading, spacing: 4) {
                    Text(stat.value).font(ClackFont.grotesk(54)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.5)
                    Text(stat.label.uppercased()).font(ClackFont.inter(22, .bold)).foregroundStyle(Self.text2).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: center ? .center : .leading)
            }
        }
    }
}

/// The routes in signal yellow on a dark panel, fitted to the box with a faint wide line under a sharp one.
private struct RouteMap: View {
    let routes: [ShareCardView.Route]
    let labels: [ShareCardView.Label]
    var snapshot: ShareMapSnapshot?

    var body: some View {
        Canvas { context, size in
            let accent = Color(hex: "#f8d64a")!
            // The real map covers the box, keeping its aspect; labels sit at where their stations landed on it.
            if let snapshot {
                let s = max(size.width / snapshot.size.width, size.height / snapshot.size.height)
                let (dw, dh) = (snapshot.size.width * s, snapshot.size.height * s)
                let (ox, oy) = ((size.width - dw) / 2, (size.height - dh) / 2)
                context.draw(Image(uiImage: snapshot.image), in: CGRect(x: ox, y: oy, width: dw, height: dh))
                for (i, label) in labels.enumerated() where i < snapshot.points.count {
                    let at = CGPoint(x: ox + snapshot.points[i].x * s, y: oy + snapshot.points[i].y * s)
                    drawLabel(&context, label.text, at: at, size: size)
                }
                return
            }
            let lines = routes.map { r -> [LatLon] in r.geometry.map(Polyline.decode) ?? r.ends }.filter { $0.count > 1 }
            let all = lines.flatMap { $0 }
            guard all.count >= 2 else {
                var path = Path()
                path.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.7))
                path.addCurve(to: CGPoint(x: size.width * 0.88, y: size.height * 0.3), control1: CGPoint(x: size.width * 0.35, y: size.height * 0.1), control2: CGPoint(x: size.width * 0.65, y: size.height * 0.95))
                context.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 10, lineCap: .round, dash: [2, 26]))
                return
            }
            let lat0 = all.reduce(0) { $0 + $1.lat } / Double(all.count)
            let kx = cos(lat0 * .pi / 180)
            func px(_ p: LatLon) -> (Double, Double) { (p.lon * kx, -p.lat) }
            let xs = all.map { px($0).0 }, ys = all.map { px($0).1 }
            let (x0, x1, y0, y1) = (xs.min()!, xs.max()!, ys.min()!, ys.max()!)
            let k = min((size.width - 180) / max(x1 - x0, 0.05), (size.height - 180) / max(y1 - y0, 0.05))
            func to(_ p: LatLon) -> CGPoint {
                let (a, b) = px(p)
                return CGPoint(x: size.width / 2 + (a - (x0 + x1) / 2) * k, y: size.height / 2 + (b - (y0 + y1) / 2) * k)
            }
            // One solid line for each journey (owner, 2026-10-25), no second translucent one under it.
            for line in lines {
                var path = Path()
                for (i, p) in line.enumerated() { i == 0 ? path.move(to: to(p)) : path.addLine(to: to(p)) }
                context.stroke(path, with: .color(accent), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
            for label in labels { drawLabel(&context, label.text, at: to(label.at), size: size) }
        }
        .background(Color(hex: "#161616")!)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }

    /// A station's name under or over its dot (the web draws it white with a dark outline).
    private func drawLabel(_ context: inout GraphicsContext, _ text: String, at: CGPoint, size: CGSize) {
        let outline = context.resolve(Text(text).font(ClackFont.inter(28, .bold)).foregroundStyle(Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255).opacity(0.85)))
        let fill = context.resolve(Text(text).font(ClackFont.inter(28, .bold)).foregroundStyle(Color.white))
        let measured = fill.measure(in: CGSize(width: size.width * 0.45, height: 60))
        let lx = max(20, min(at.x - measured.width / 2, size.width - measured.width - 20))
        // The baseline sits 22 above the dot (upper half of the box) or 46 below it.
        let ly = at.y + (at.y < size.height / 2 ? -22 : 46)
        for (dx, dy) in [(-2.5, 0.0), (2.5, 0.0), (0.0, -2.5), (0.0, 2.5), (-1.8, -1.8), (1.8, 1.8), (-1.8, 1.8), (1.8, -1.8)] {
            context.draw(outline, at: CGPoint(x: lx + dx, y: ly + dy), anchor: .bottomLeading)
        }
        context.draw(fill, at: CGPoint(x: lx, y: ly), anchor: .bottomLeading)
    }
}
