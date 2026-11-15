//
//  NetworkPanel.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Network now on Explore: how each country runs, then what's wrong where, as rows that take the map there (owner,
/// 2026-11-15: "show, don't tell"). The map behind shows it too: trains in their delay colours, slow stretches in
/// orange, track work dashed orange, a closed track dashed red (a pin only where there's no track to draw). A problem
/// tapped, here or on the map, opens its own sheet (`DisruptionSheet`). Read off the live map and the disruption feeds
/// (`GET /api/live/network`). Status is written, never boxed (DESIGN.md).
struct NetworkPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(ExploreModel.self) private var model
    let status: NetworkStatus?
    let failed: Bool
    var onCorridor: (NetworkStatus.Corridor) -> Void
    var onTrain: (NetworkStatus.LateTrain) -> Void
    var onDisruption: (NetworkStatus.Disruption) -> Void = { _ in }
    /// One of your trains tapped: its trip page.
    var onTrip: (String) -> Void = { _ in }
    var onClose: () -> Void
    /// Your trains left to run today, loaded when the panel opens (nil until then; empty: none today).
    @State private var mine: [Leg]?
    @State private var allLate = false
    @State private var allOnTrack = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task {
            let legs = (try? await app.client.legs()) ?? []
            let today = NetworkLogic.today(legs, now: Date.now.timeIntervalSince1970 * 1000)
            mine = today
            model.mineToday = today
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            HStack(alignment: .center, spacing: Space.s) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(l10n.t("network.title")).clack(.headline).foregroundStyle(Ink.text)
                    if let status {
                        Text(l10n.t("network.updated", ["time": Format.time(status.at, tz: TimeZone.current.identifier, clock: app.settings.clock)]))
                            .clack(.micro).foregroundStyle(Ink.text3)
                    }
                }
                Spacer(minLength: Space.s)
                // The close X where every other sheet has it (owner, 2026-11-15); how it's worked out is at the foot.
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            if let status {
                yours(status)
                countries(status)
                counts(status)
                corridors(status)
                onTrack(status)
                if let groups = status.cancelled, !groups.isEmpty { cancelled(groups, tz: TimeZone.current.identifier) }
                if !status.late.isEmpty { lateTrains(status) }
                InfoNote(l10n.t("network.about"), more: l10n.t("network.aboutBody", ["min": String(status.lateMin)]))
            } else if failed {
                // Why, and when it asks again (the poll backs off); Try now sends the waiting ask at once.
                ErrorStateView(
                    message: model.networkFailure == nil ? l10n.t("network.failed") : l10n.t("network.couldNotLoad"),
                    kind: model.networkFailure, status: model.networkRetry, retry: { RetryWake.shared.wake() }
                )
            } else {
                GrowingWait(context: l10n.t("network.slow"), status: model.networkRetry) { Skeleton(height: 120) }
            }
        }
        .padding(Space.l)
    }

    // MARK: your trains

    /// Your trains today first (designer, 2026-11-14: "Your trips today: affected"): that they run as normal, or each one
    /// the network touches and how; tapping one opens it. Nothing when you have none today.
    @ViewBuilder
    private func yours(_ status: NetworkStatus) -> some View {
        if let mine, !mine.isEmpty {
            let hit = NetworkLogic.affected(mine, status: status)
            if hit.isEmpty {
                HStack(spacing: Space.s) {
                    LucideIcon(name: "badge-check", size: 18).foregroundStyle(Ink.onTimeInk)
                    Text(l10n.t("network.mineFine")).clack(.rowTitle).foregroundStyle(Ink.text)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    header("network.mineTitle")
                    ForEach(hit, id: \.leg.id) { a in
                        let service = Format.join([a.leg.operator?.name, a.leg.trainNumber], separator: " ")
                        let (why, ink): (String, Color) = switch a.why {
                        case .canceled: (l10n.t("network.whyCanceled"), Ink.veryLateInk)
                        case .late(let min): (Format.delay(min), min >= 30 ? Ink.veryLateInk : Ink.lateInk)
                        case .near(let station, _): (l10n.t("network.whyNear", ["station": station]), Ink.lateInk)
                        }
                        row(
                            icon: "train-front", color: ink,
                            title: "\(a.leg.origin?.name ?? "") → \(a.leg.destination?.name ?? "")",
                            detail: service.isEmpty ? nil : service, figure: why, figureInk: ink
                        ) { open(a, status: status) }
                    }
                }
            }
        }
    }

    /// A train of yours tapped: what touches it when that has a page (the disruption, the slow stretch), else the
    /// train's own page (cancelled, late, cancellations at its station).
    private func open(_ a: NetworkLogic.Affected, status: NetworkStatus) {
        if case .near(_, let trouble) = a.why {
            switch trouble {
            case .disruption(let id):
                if let d = status.disruptions?.first(where: { $0.id == id }) { return onDisruption(d) }
            case .corridor(let id):
                if let c = status.corridors.first(where: { $0.id == id }) { return onCorridor(c) }
            case .cancelled:
                break
            }
        }
        onTrip(a.leg.id)
    }

    // MARK: countries, as rings

    private func countries(_ status: NetworkStatus) -> some View {
        let codes = ["SE", "NO", "DK", "FI"].filter { status.countries[$0] != nil }
        return HStack(spacing: Space.s) {
            ForEach(codes, id: \.self) { code in
                let c = status.countries[code]!
                let share = c.trains > 0 ? Double(c.trains - c.late) / Double(c.trains) : 1
                let pct = Int((share * 100).rounded(.down))
                let good = !(c.trains > 0 && c.late * 10 >= c.trains)
                VStack(spacing: Space.xs) {
                    ZStack {
                        Circle().stroke(Ink.hairline, lineWidth: 5)
                        Circle().trim(from: 0, to: share)
                            .stroke(good ? Ink.onTime : Ink.late, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(l10n.t("network.onTimePct", ["pct": String(pct)])).clack(.caption).monospacedDigit().foregroundStyle(Ink.text)
                            .minimumScaleFactor(0.7).lineLimit(1).padding(Space.xs)
                    }
                    .frame(width: 58, height: 58)
                    Flag(country: code, size: 18, decorative: true)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(l10n.t("network.countryA11y", ["country": l10n.t("countries.\(code)"), "pct": String(pct), "late": String(c.late), "trains": String(c.trains)]))
            }
        }
    }

    // MARK: the counts (the map's legend too)

    private struct Count: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let count: Int
    }

    @ViewBuilder
    private func counts(_ status: NetworkStatus) -> some View {
        let d = status.disruptions ?? []
        let list = [
            Count(id: "slow", icon: "timer", color: Ink.late, count: status.corridors.count),
            Count(id: "works", icon: "construction", color: Ink.late, count: d.filter { $0.kind == .works }.count),
            Count(id: "closure", icon: "ban", color: Ink.veryLate, count: d.filter { $0.kind == .closure }.count),
            Count(id: "incident", icon: "triangle-alert", color: Ink.veryLate, count: d.filter { $0.kind == .incident }.count),
            Count(id: "cancelled", icon: "x", color: Ink.veryLate, count: status.cancelledTrains ?? 0),
        ].filter { $0.count > 0 }
        if !list.isEmpty {
            HStack(spacing: Space.l) {
                ForEach(list) { c in
                    HStack(spacing: Space.xs) {
                        LucideIcon(name: c.icon, size: 16).foregroundStyle(c.color)
                        Text(String(c.count)).clack(.rowTitle).monospacedDigit().foregroundStyle(Ink.text)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(l10n.t("network.countA11y", ["kind": l10n.t("network.kind.\(c.id)"), "count": String(c.count)]))
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: rows

    /// One row: an icon in its colour, what and where, a figure on the right; taps take the map there.
    private func row(icon: String, color: Color, title: String, detail: String?, figure: String?, figureInk: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Space.m) {
                LucideIcon(name: icon, size: 18).foregroundStyle(color).frame(width: 24)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(title).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2).multilineTextAlignment(.leading)
                    if let detail { Text(detail).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1) }
                }
                Spacer(minLength: Space.s)
                if let figure { Text(figure).clack(.delay).monospacedDigit().foregroundStyle(figureInk) }
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.pressRow)
    }

    private func header(_ key: String) -> some View {
        Text(l10n.t(key)).clack(.captionUpper).foregroundStyle(Ink.text2)
    }

    @ViewBuilder
    private func corridors(_ status: NetworkStatus) -> some View {
        if !status.corridors.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header("network.corridors")
                ForEach(status.corridors) { c in
                    row(
                        icon: "timer", color: Ink.late, title: c.stations.joined(separator: " – "),
                        detail: NetworkWording.reasons(c.causes, l10n: l10n, counted: false),
                        figure: Format.delay(c.medianDelay), figureInk: Ink.lateInk
                    ) { onCorridor(c) }
                    .accessibilityHint(l10n.t("network.showOnMap"))
                }
            }
        }
    }

    @ViewBuilder
    private func onTrack(_ status: NetworkStatus) -> some View {
        let order: [NetworkStatus.Disruption.Kind: Int] = [.closure: 0, .works: 1, .incident: 2]
        let list = (status.disruptions ?? []).sorted { (order[$0.kind] ?? 3, $0.country) < (order[$1.kind] ?? 3, $1.country) }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                header("network.onTrack")
                ForEach(allOnTrack ? list : Array(list.prefix(5))) { d in
                    let kind = l10n.t("network.kind.\(d.kind.rawValue)")
                    row(
                        icon: d.kind == .works ? "construction" : d.kind == .closure ? "ban" : "triangle-alert",
                        color: d.kind == .works ? Ink.late : Ink.veryLate,
                        title: d.places.isEmpty ? kind : d.places.joined(separator: " – "),
                        detail: Format.join([d.places.isEmpty ? nil : kind, d.text(l10n.language).map { l10n.shownWhole($0).text }]),
                        figure: until(d), figureInk: Ink.text2
                    ) { onDisruption(d) }
                    .accessibilityHint(l10n.t("network.openProblem"))
                }
                if list.count > 5 {
                    Button {
                        withMotion(.layout, reduceMotion: reduceMotion) { allOnTrack.toggle() }
                    } label: {
                        DisclosureRowLabel(title: l10n.t(allOnTrack ? "network.fewerLate" : "network.allOnTrack", ["count": String(list.count)]))
                    }
                    .buttonStyle(.pressRow)
                }
            }
        }
    }

    /// "until 15:00" today, "until Tue 17 Nov" later; nothing when open-ended.
    private func until(_ d: NetworkStatus.Disruption) -> String? {
        guard let to = d.to else { return nil }
        let tz = Format.zone(country: d.country)
        let now = Date.now.timeIntervalSince1970 * 1000
        if Format.localDate(to, tz: tz) == Format.localDate(now, tz: tz) {
            return l10n.t("network.until", ["time": Format.time(to, tz: tz, clock: app.settings.clock)])
        }
        return l10n.t("network.untilDay", ["day": Format.day(to, tz: tz, now: now, language: app.settings.language)])
    }

    /// Cancelled in the next two hours, by stretch, with whether a bus runs instead.
    private func cancelled(_ groups: [NetworkStatus.CancelledGroup], tz: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header("network.cancelled")
            ForEach(groups) { g in
                HStack(alignment: .center, spacing: Space.m) {
                    OperatorBadge(op: g.operatorIds.first.flatMap { app.operatorsById[$0] }, size: .small)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(g.stations.joined(separator: " – ")).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2)
                        Text(NetworkWording.cancelledLine(g, l10n: l10n, tz: tz, clock: app.settings.clock))
                            .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2).lineLimit(1)
                    }
                    Spacer(minLength: Space.s)
                    Text(l10n.t("network.cancelledShort", ["count": String(g.trains)])).clack(.delay).monospacedDigit()
                        .foregroundStyle(g.bus == g.trains ? Ink.lateInk : Ink.veryLateInk)
                }
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The late trains as bars: the longer, the later.
    private func lateTrains(_ status: NetworkStatus) -> some View {
        let most = Double(max(30, status.late.map(\.delayMin).max() ?? 30))
        return VStack(alignment: .leading, spacing: 0) {
            header("network.lateTrains")
            // The three latest first, the rest one tap away.
            ForEach(allLate ? status.late : Array(status.late.prefix(3))) { t in
                Button { onTrain(t) } label: {
                    HStack(alignment: .center, spacing: Space.m) {
                        OperatorBadge(op: t.operatorId.flatMap { app.operatorsById[$0] }, size: .small)
                        VStack(alignment: .leading, spacing: Space.xs) {
                            HStack(spacing: Space.s) {
                                Text([t.operatorId.flatMap { app.operatorsById[$0]?.name }, t.number].compactMap { $0 }.joined(separator: " "))
                                    .clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
                                Spacer(minLength: Space.s)
                                Text(Format.delay(t.delayMin)).clack(.delay).monospacedDigit()
                                    .foregroundStyle(t.delayMin >= 30 ? Ink.veryLateInk : Ink.lateInk)
                            }
                            GeometryReader { g in
                                RoundedRectangle(cornerRadius: Radius.bar)
                                    .fill(t.delayMin >= 30 ? Ink.veryLate : Ink.late)
                                    .frame(width: max(4, g.size.width * min(1, Double(t.delayMin) / most)))
                            }
                            .frame(height: 4)
                            .accessibilityHidden(true)
                            if let between = NetworkWording.between(t, l10n: l10n) {
                                Text(between).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
                            }
                        }
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                    .padding(.vertical, Space.xs)
                }
                .buttonStyle(.pressRow)
            }
            if status.late.count > 3 {
                // A row like any other (owner, 2026-11-15: the link styling is gone).
                Button {
                    withMotion(.layout, reduceMotion: reduceMotion) { allLate.toggle() }
                } label: {
                    DisclosureRowLabel(title: l10n.t(allLate ? "network.fewerLate" : "network.allLate", ["count": String(status.late.count)]))
                }
                .buttonStyle(.pressRow)
            }
        }
    }
}

/// The panel's wording, kept apart from the view so it can be read and tested on its own.
enum NetworkWording {
    /// "3 trains cancelled from 18:19 · a bus replaces all", or "… · a bus replaces 1", or "… · no bus given".
    static func cancelledLine(_ g: NetworkStatus.CancelledGroup, l10n: L10n, tz: String, clock: ClockFormat) -> String {
        let head = l10n.t("network.cancelledTrains", count: g.trains, ["count": String(g.trains), "time": Format.time(g.firstAt, tz: tz, clock: clock)])
        let bus = g.bus == 0 ? l10n.t("network.noBus") : g.bus == g.trains ? l10n.t("network.busAll") : l10n.t("network.busSome", ["count": String(g.bus)])
        return "\(head) · \(bus)"
    }

    /// A country's line is the late ink when one train in ten or more is late, otherwise plain.
    static func countryInk(_ c: NetworkStatus.Country) -> Color {
        c.trains > 0 && c.late * 10 >= c.trains ? Ink.lateInk : Ink.text2
    }

    /// "4 of 5 trains late · typically +18 min, up to +30"
    static func corridorLine(_ c: NetworkStatus.Corridor, l10n: L10n) -> String {
        l10n.t("network.corridorLine", ["late": String(c.late), "trains": String(c.trains), "median": String(c.medianDelay), "max": String(c.maxDelay)])
    }

    /// "Signal fault (3 trains) · Accident (1 train)", or that no feed says why.
    static func reasons(_ causes: [NetworkStatus.Cause], l10n: L10n, counted: Bool = true) -> String {
        let named = causes.compactMap { c -> String? in
            guard let text = DelayCauses.text(c.cause, translate: { l10n.t($0) }) else { return nil }
            return counted ? l10n.t("network.reasonCount", count: c.trains, ["reason": text, "count": String(c.trains)]) : text
        }
        guard !named.isEmpty else { return l10n.t("network.noReason") }
        return Array(NSOrderedSet(array: named)).compactMap { $0 as? String }.prefix(3).joined(separator: Format.separator)
    }

    /// "Between Växjö and Alvesta", or "Towards Alvesta" when the last stop isn't known.
    static func between(_ t: NetworkStatus.LateTrain, l10n: L10n) -> String? {
        switch (t.prev, t.next) {
        // Standing at a stop: the feed gives the same name twice ("between Hässleholm and Hässleholm").
        case let (a?, b?) where a == b: l10n.t("network.at", ["a": a])
        case let (a?, b?): l10n.t("network.between", ["a": a, "b": b])
        case let (nil, b?): l10n.t("network.towards", ["b": b])
        default: t.destination.map { l10n.t("network.towards", ["b": $0]) }
        }
    }
}
