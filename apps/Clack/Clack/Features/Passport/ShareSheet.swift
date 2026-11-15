//
//  ShareSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI
import UniformTypeIdentifiers

/// Share card preview (share/ShareSheet.tsx, product brief §10): pick a card, see exactly the image that will be shared,
/// then share it. Nothing leaves the phone unless you tap Share. Four cards: the year, all time, one journey, one medal,
/// all as the Year in Rail's story card (`RecapShareCard`, 1080 × 1920; owner, 2026-11-15: the old card's line map
/// was no use, "use the same one we've just made on the year in review").
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
                        .frame(maxHeight: 560)
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
                    HStack(spacing: Space.s) { LucideIcon(name: "system:square.and.arrow.up", size: 16); Text(l10n.t("share.share")) }
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

    private func cardMedal(_ m: Milestone) -> RecapShareCard.CardMedal {
        .init(milestone: m, label: l10n.milestoneLabel(m, language: language, home: base.home))
    }

    /// A train type by id: from the Passport's own references, else the app's list.
    private func trainType(_ id: String?, in p: Passport) -> TrainType? {
        guard let id else { return nil }
        return p.refs.trainTypes[id] ?? app.trainTypes.first { $0.id == id }
    }

    private var card: RecapShareCard? {
        switch variant {
        case .medal:
            guard let md = achieved.first(where: { key($0) == medalKey }) ?? achieved.first else { return nil }
            return RecapShareCard(content: .medal(.init(
                kicker: l10n.t("share.medalKicker"), medal: cardMedal(md),
                sub: md.at.map { l10n.t("share.unlocked", ["date": monthYear($0.ms)]) },
                stats: [.init(value: km(base.totals.distanceM), label: unit.rawValue),
                        .init(value: String(base.totals.journeys), label: l10n.t("passport.journeys")),
                        .init(value: String(base.totals.stations), label: l10n.t("passport.stations"))]
            )))
        case .journey:
            guard let leg = counted.first(where: { $0.id == legId }) ?? counted.first else { return nil }
            var stats: [RecapShareCard.Stat] = []
            if let dep = leg.schedDep?.ms, let arr = leg.schedArr?.ms {
                stats.append(.init(value: Format.duration(((leg.actualArr?.ms ?? arr) - (leg.actualDep?.ms ?? dep)) / 60_000, language: l10n.language), label: l10n.t("share.onBoard")))
            }
            if let name = leg.operator?.name { stats.append(.init(value: name, label: l10n.t("share.operator"))) }
            return RecapShareCard(content: .journey(.init(
                kicker: [l10n.t("share.featured"), leg.schedDep.map { monthYear($0.ms) }].compactMap { $0 }.joined(separator: " · "),
                train: trainType(leg.trainType, in: base), operatorId: leg.operatorId,
                title: "\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")",
                distance: leg.distanceM.map(km) ?? "—", unit: leg.distanceM == nil ? "" : unit.rawValue,
                stats: stats,
                medals: achieved.filter { $0.legId == leg.id }.map(cardMedal)
            )))
        case .year, .all:
            guard let p = variant == .year ? yearData : all else { return nil }
            let inYear: (Milestone) -> Bool = { m in
                guard let at = m.at, let y = shownYear else { return false }
                return Self.year(ms: at.ms) == y
            }
            let medals = (variant == .year ? achieved.filter(inYear) : achieved).prefix(4).map(cardMedal)
            let trains = p.trainTypes.compactMap { row in
                trainType(row.key, in: p).map { RecapShareCard.Train(type: $0, operatorId: nil, count: l10n.t("recap.times", ["count": String(row.count)])) }
            }
            let months = variant == .year ? shownYear.map { RecapMonth.year($0, p.months, language: language) } : nil
            return RecapShareCard(content: .recap(.init(
                kicker: variant == .year ? l10n.t("recap.open", ["year": String(shownYear ?? 0)]) : l10n.t("share.allTitle"),
                distance: km(p.totals.distanceM), unit: unit.rawValue,
                trainsCount: String(p.totals.trains),
                trainsLine: l10n.t("recap.trains", ["journeys": String(p.totals.journeys), "time": Format.duration(p.totals.minutes, language: l10n.language)]),
                monthsTitle: l10n.t("recap.monthsTitle"),
                months: (months?.contains { $0.trains > 0 } ?? false) ? months : nil,
                route: p.records.mostRiddenRoute?.route,
                routeLine: p.records.mostRiddenRoute.map { l10n.t("recap.route", ["count": String($0.count)]) },
                trainsTitle: l10n.t("recap.trainsTitle"),
                trains: Array(trains.prefix(3)),
                medals: Array(medals)
            )))
        }
    }

    private func render() async {
        image = nil
        guard let card else { return }
        // Fixed pixel sizes: the light look and the default text size whatever the phone is set to.
        let renderer = ImageRenderer(content: card.environment(\.colorScheme, .light).environment(\.dynamicTypeSize, .large))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: RecapShareCard.width, height: RecapShareCard.height)
        guard let ui = renderer.uiImage else { return }
        image = Image(uiImage: ui)
    }
}
