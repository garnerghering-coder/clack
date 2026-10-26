//
//  ShareSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
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
    @State private var snapshots: [String: ShareMapSnapshot?] = [:]

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
                options: Variant.allCases.map { v in (v, v == .year ? (shownYear.map(String.init) ?? l10n.t("share.year")) : l10n.t("share.variant.\(v.rawValue)")) }
            )
            if variant == .journey, !counted.isEmpty {
                Picker(l10n.t("share.pickJourney"), selection: Binding(get: { legId ?? counted[0].id }, set: { legId = $0 })) {
                    ForEach(counted) { leg in Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "") · \(leg.schedDep.map { monthYear($0.ms) } ?? "")").tag(leg.id) }
                }
                .tint(Ink.accentInk)
            }
            if variant == .medal, !achieved.isEmpty {
                Picker(l10n.t("share.pickMedal"), selection: Binding(get: { medalKey ?? key(achieved[0]) }, set: { medalKey = $0 })) {
                    ForEach(achieved, id: \.self) { m in Text(l10n.milestoneLabel(m, language: language, home: base.home)).tag(key(m)) }
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
            InfoNote(l10n.t("share.privacy"), more: l10n.t("share.privacyMore"))
            if let image {
                // The picture itself (not a file of it), so the share sheet offers Save Image and the usual image actions.
                ShareLink(item: image, preview: SharePreview(l10n.t("share.title"), image: image)) {
                    HStack(spacing: 8) { LucideIcon(name: "system:square.and.arrow.up", size: 16); Text(l10n.t("share.share")) }
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
        .task(id: CardKey(variant: variant, legId: legId, medalKey: medalKey, haveAll: all != nil, haveYear: yearData != nil, legs: legs.count)) { await render() }
    }

    private struct CardKey: Hashable { var variant: Variant; var legId: String?; var medalKey: String?; var haveAll: Bool; var haveYear: Bool; var legs: Int }

    // MARK: what goes on the card

    /// The year a trip left, in Stockholm's zone like the months on the cards.
    private static func year(ms: Double) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm") ?? .current
        return calendar.component(.year, from: Date(timeIntervalSince1970: ms / 1000))
    }

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
        switch variant {
        case .medal:
            guard let md = achieved.first(where: { key($0) == medalKey }) ?? achieved.first else { return nil }
            return ShareCardView(
                layout: .medal, kicker: l10n.t("share.medalKicker"), title: l10n.milestoneLabel(md, language: language, home: base.home),
                sub: md.at.map { l10n.t("share.unlocked", ["date": monthYear($0.ms)]) }, heroValue: "", heroUnit: "",
                stats: [.init(value: km(base.totals.distanceM), label: unit.rawValue)] + totals(base).prefix(2), routes: [], labels: [],
                medals: [.init(milestone: md, label: l10n.milestoneLabel(md, language: language, home: base.home))],
                mrz: PassportMRZ.line(year: nil, km: base.totals.distanceM / 1000, journeys: base.totals.journeys, stations: base.totals.stations)
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
                medals: achieved.filter { $0.legId == leg.id }.map { .init(milestone: $0, label: l10n.milestoneLabel($0, language: language, home: base.home)) },
                mrz: PassportMRZ.line(year: leg.schedDep.flatMap { Self.year(ms: $0.ms) }, km: (leg.distanceM ?? 0) / 1000)
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
            let medals = (variant == .year ? achieved.filter(inYear) : achieved).prefix(4).map { ShareCardView.CardMedal(milestone: $0, label: l10n.milestoneLabel($0, language: language, home: base.home)) }
            if variant == .year {
                return ShareCardView(
                    layout: .stats, kicker: l10n.t("share.yearKicker", ["year": String(shownYear ?? 0)]), title: l10n.t("share.yearTitle", ["year": String(shownYear ?? 0)]), sub: nil,
                    heroValue: km(p.totals.distanceM), heroUnit: unit.rawValue,
                    stats: [.init(value: String(p.totals.journeys), label: l10n.t("passport.journeys")), .init(value: Format.duration(p.totals.minutes), label: l10n.t("share.onBoard")), .init(value: String(p.totals.stations), label: l10n.t("passport.stations"))],
                    routes: routes, labels: [], medals: Array(medals),
                    mrz: PassportMRZ.line(year: shownYear, km: p.totals.distanceM / 1000, journeys: p.totals.journeys, stations: p.totals.stations)
                )
            }
            return ShareCardView(
                layout: .stats, kicker: l10n.t("share.allKicker"), title: l10n.t("share.allTitle"), sub: nil,
                heroValue: km(p.totals.distanceM), heroUnit: unit.rawValue, stats: totals(p), routes: routes, labels: [], medals: Array(medals),
                mrz: PassportMRZ.line(year: nil, km: p.totals.distanceM / 1000, journeys: p.totals.journeys, stations: p.totals.stations, countries: p.totals.countries)
            )
        }
    }

    /// The cards' real maps are slow-ish (a second or two), so each set of routes is drawn once per sheet.
    private func snapshot(for card: ShareCardView) async -> ShareMapSnapshot? {
        let lines = card.routes.map { $0.geometry.map(Polyline.decode) ?? $0.ends }
        guard lines.contains(where: { $0.count > 1 }) else { return nil }
        let key = "\(variant.rawValue)|\(lines.map { "\($0.count):\($0.first?.lat ?? 0),\($0.last?.lon ?? 0)" }.joined(separator: ";"))"
        if let cached = snapshots[key] { return cached }
        let made = await ShareMapSnapshotter.make(
            lines: lines, ends: card.routes.flatMap(\.ends), points: card.labels.map(\.at),
            size: CGSize(width: ShareCardView.mapBox.width / 2, height: ShareCardView.mapBox.height / 2),
            base: Config.apiBase, withBasemap: await app.mapHasBasemap()
        )
        snapshots[key] = .some(made)
        return made
    }

    private func render() async {
        image = nil
        guard var card else { return }
        card.map = await snapshot(for: card)
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .dark))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: ShareCardView.width, height: ShareCardView.height)
        guard let ui = renderer.uiImage else { return }
        image = Image(uiImage: ui)
    }
}
