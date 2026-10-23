//
//  ShareSheet.swift
//  Clack
//

import SwiftUI
import UniformTypeIdentifiers

/// Share card preview (share/ShareSheet.tsx, product brief §10): pick a card, see exactly the image that will be shared,
/// then share it. Nothing leaves the phone unless you tap Share. Four cards: the year, all time, one journey, one medal.
/// The map on a card is the routes drawn alone on a dark panel (the web's real-map snapshot is not ported yet).
struct ShareSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let passport: Passport
    let year: Int?
    let commuter: Bool
    var onClose: () -> Void

    private enum Variant: String, CaseIterable { case year, all, journey, medal }

    @State private var variant: Variant = .year
    @State private var all: Passport?
    @State private var yearData: Passport?
    @State private var legs: [Leg] = []
    @State private var legId: String?
    @State private var medalKey: String?
    @State private var image: Image?
    @State private var file: ShareImage?

    private var unit: DistanceUnit { app.settings.distanceUnit }
    private var language: Language { app.settings.language }
    private var base: Passport { all ?? passport }
    private var shownYear: Int? { year ?? base.years.first }
    private var achieved: [Milestone] { base.milestones.achieved }
    private func key(_ m: Milestone) -> String { "\(m.family.rawValue):\(m.target)" }

    /// Only trips that count can be featured, newest first.
    private var counted: [Leg] {
        let ids = Set(base.map.map(\.legId))
        return legs.filter { ids.contains($0.id) }.sorted { ($0.schedDep?.ms ?? 0) > ($1.schedDep?.ms ?? 0) }
    }

    var body: some View {
        SheetFrame(title: l10n.t("share.title"), onClose: onClose) {
            SegmentedControl(
                selection: $variant,
                options: Variant.allCases.map { v in (v, v == .year ? (shownYear.map(String.init) ?? l10n.t("share.year")) : l10n.t("share.variant.\(v.rawValue)")) },
                small: true
            )
            if variant == .journey, !counted.isEmpty {
                Picker(l10n.t("share.pickJourney"), selection: Binding(get: { legId ?? counted[0].id }, set: { legId = $0 })) {
                    ForEach(counted) { leg in Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "") · \(leg.schedDep.map { monthYear($0.ms) } ?? "")").tag(leg.id) }
                }
                .tint(Ink.accentInk)
            }
            if variant == .medal, !achieved.isEmpty {
                Picker(l10n.t("share.pickMedal"), selection: Binding(get: { medalKey ?? key(achieved[0]) }, set: { medalKey = $0 })) {
                    ForEach(achieved, id: \.self) { m in Text(l10n.milestoneLabel(m, language: language)).tag(key(m)) }
                }
                .tint(Ink.accentInk)
            }
            Group {
                if let image {
                    image.resizable().scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .accessibilityLabel(l10n.t("share.previewAlt"))
                } else if card == nil {
                    Text(l10n.t("share.nothing")).clack(.caption).foregroundStyle(Ink.text2)
                } else {
                    Skeleton(height: 360)
                }
            }
            Text(l10n.t("share.privacy")).clack(.caption).foregroundStyle(Ink.text2)
            if let file {
                ShareLink(item: file, preview: SharePreview(l10n.t("share.title"), image: file.image)) {
                    HStack(spacing: 8) { LucideIcon(name: "share-2", size: 16); Text(l10n.t("share.share")) }
                }
                .buttonStyle(.clack(.primary, wide: true))
            }
        }
        .task {
            if let loaded = try? await app.client.passport(year: nil, commuter: commuter, comparison: app.settings.co2Comparison) { all = loaded }
            legs = (try? await app.client.legs()) ?? []
        }
        .task(id: year ?? base.years.first) {
            if let y = shownYear, let p = try? await app.client.passport(year: y, commuter: commuter, comparison: app.settings.co2Comparison) { yearData = p }
        }
        .task(id: CardKey(variant: variant, legId: legId, medalKey: medalKey, haveAll: all != nil, haveYear: yearData != nil, legs: legs.count)) { render() }
    }

    private struct CardKey: Hashable { var variant: Variant; var legId: String?; var medalKey: String?; var haveAll: Bool; var haveYear: Bool; var legs: Int }

    // MARK: what goes on the card

    private func monthYear(_ ms: Double) -> String {
        let f = DateFormatter()
        f.locale = Format.locale(language)
        f.timeZone = TimeZone(identifier: "Europe/Stockholm")
        f.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return f.string(from: Date(timeIntervalSince1970: ms / 1000))
    }

    /// Distance without its unit, as the card prints the unit separately.
    private func km(_ m: Double) -> String {
        Format.distance(m, unit: unit, language: language).replacingOccurrences(of: #"\s?(km|mi)$"#, with: "", options: .regularExpression)
    }

    private func totals(_ p: Passport) -> [ShareCardView.Stat] {
        [.init(value: String(p.totals.journeys), label: l10n.t("passport.journeys")),
         .init(value: String(p.totals.stations), label: l10n.t("passport.stations")),
         .init(value: String(p.totals.countries), label: l10n.t("share.countries"))]
    }

    private var card: ShareCardView? {
        let tagline = l10n.t("share.tagline")
        switch variant {
        case .medal:
            guard let md = achieved.first(where: { key($0) == medalKey }) ?? achieved.first else { return nil }
            return ShareCardView(
                layout: .medal, kicker: l10n.t("share.medalKicker"), title: l10n.milestoneLabel(md, language: language),
                sub: md.at.map { l10n.t("share.unlocked", ["date": monthYear($0.ms)]) }, heroValue: "", heroUnit: "",
                stats: [.init(value: km(base.totals.distanceM), label: unit.rawValue)] + totals(base).prefix(2), routes: [], labels: [],
                medals: [.init(milestone: md, label: l10n.milestoneLabel(md, language: language))], tagline: tagline
            )
        case .journey:
            guard let leg = counted.first(where: { $0.id == legId }) ?? counted.first, let route = base.map.first(where: { $0.legId == leg.id }) else { return nil }
            let dep = leg.schedDep?.ms
            let ends = route.stops.compactMap { $0.count == 2 ? LatLon($0[0], $0[1]) : nil }
            let labels = ends.count == 2 ? [ShareCardView.Label(at: ends[0], text: leg.origin?.name ?? ""), .init(at: ends[1], text: leg.destination?.name ?? "")] : []
            var onBoard = "—"
            if let dep, let arr = leg.schedArr?.ms {
                onBoard = Format.duration(((leg.actualArr?.ms ?? arr) - (leg.actualDep?.ms ?? dep)) / 60_000)
            }
            return ShareCardView(
                layout: .stats, kicker: [l10n.t("share.featured"), dep.map(monthYear)].compactMap { $0 }.joined(separator: " · "),
                title: "\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")", sub: nil,
                heroValue: km(leg.distanceM ?? 0), heroUnit: unit.rawValue,
                stats: [.init(value: onBoard, label: l10n.t("share.onBoard")), .init(value: leg.operator?.name ?? "—", label: l10n.t("share.operator"))],
                routes: [.init(geometry: route.geometry, ends: ends)], labels: labels,
                medals: achieved.filter { $0.legId == leg.id }.map { .init(milestone: $0, label: l10n.milestoneLabel($0, language: language)) }, tagline: tagline
            )
        case .year, .all:
            guard let p = variant == .year ? yearData : all else { return nil }
            let routes = p.map.map { r in ShareCardView.Route(geometry: r.geometry, ends: r.stops.compactMap { $0.count == 2 ? LatLon($0[0], $0[1]) : nil }) }
            let inYear: (Milestone) -> Bool = { m in
                guard let at = m.at, let y = shownYear else { return false }
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
                return calendar.component(.year, from: Date(timeIntervalSince1970: at.ms / 1000)) == y
            }
            let medals = (variant == .year ? achieved.filter(inYear) : achieved).prefix(4).map { ShareCardView.CardMedal(milestone: $0, label: l10n.milestoneLabel($0, language: language)) }
            if variant == .year {
                return ShareCardView(
                    layout: .stats, kicker: l10n.t("share.yearKicker"), title: l10n.t("share.yearTitle", ["year": String(shownYear ?? 0)]), sub: nil,
                    heroValue: km(p.totals.distanceM), heroUnit: unit.rawValue,
                    stats: [.init(value: String(p.totals.journeys), label: l10n.t("passport.journeys")), .init(value: Format.duration(p.totals.minutes), label: l10n.t("share.onBoard")), .init(value: String(p.totals.stations), label: l10n.t("passport.stations"))],
                    routes: routes, labels: [], medals: Array(medals), tagline: tagline
                )
            }
            return ShareCardView(
                layout: .stats, kicker: l10n.t("share.allKicker"), title: l10n.t("share.allTitle"), sub: nil,
                heroValue: km(p.totals.distanceM), heroUnit: unit.rawValue, stats: totals(p), routes: routes, labels: [], medals: Array(medals), tagline: tagline
            )
        }
    }

    private func render() {
        image = nil
        file = nil
        guard let card else { return }
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .dark))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: ShareCardView.width, height: ShareCardView.height)
        guard let ui = renderer.uiImage else { return }
        image = Image(uiImage: ui)
        if let data = ui.pngData() {
            let name = "clack-\(variant == .year ? String(shownYear ?? 0) : variant == .all ? "passport" : variant.rawValue).png"
            file = ShareImage(data: data, name: name, image: Image(uiImage: ui))
        }
    }
}

/// The PNG handed to the share sheet.
struct ShareImage: Transferable {
    let data: Data
    let name: String
    let image: Image

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.data }
    }
}

/// The card itself, 1080 × 1350 (4:5): dark, with a warm glow and faint rings, like the Passport's top card at night.
/// Left out on purpose: times, ticket or booking details, train numbers, anything about where you are now.
struct ShareCardView: View {
    static let width: CGFloat = 1080
    static let height: CGFloat = 1350
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
    var tagline: String

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
            HStack(spacing: 14) {
                Wordmark(fontSize: 36)
                Text(tagline).font(ClackFont.inter(20, .bold)).foregroundStyle(Self.text2)
            }
            Text(kicker.uppercased()).font(ClackFont.inter(26, .heavy)).foregroundStyle(Self.accent).padding(.top, 52)
        }
    }

    private var statsLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(ClackFont.grotesk(72)).fontWeight(.heavy).foregroundStyle(.white)
                .lineLimit(2).minimumScaleFactor(0.6).padding(.top, 14)
            RouteMap(routes: routes, labels: labels)
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

    var body: some View {
        Canvas { context, size in
            let accent = Color(hex: "#f8d64a")!
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
            for (width, alpha) in [(18.0, 0.18), (7.0, 1.0)] {
                for line in lines {
                    var path = Path()
                    for (i, p) in line.enumerated() { i == 0 ? path.move(to: to(p)) : path.addLine(to: to(p)) }
                    context.stroke(path, with: .color(accent.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
                }
            }
            for label in labels {
                let at = to(label.at)
                let text = Text(label.text).font(ClackFont.inter(28, .bold)).foregroundStyle(Color.white)
                let resolved = context.resolve(text)
                let measured = resolved.measure(in: CGSize(width: size.width * 0.45, height: 60))
                let lx = max(20, min(at.x - measured.width / 2, size.width - measured.width - 20))
                let ly = at.y + (at.y < size.height / 2 ? -22 : 46) - measured.height
                context.draw(resolved, at: CGPoint(x: lx, y: ly), anchor: .topLeading)
            }
        }
        .background(Color(hex: "#161616")!)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
    }
}
