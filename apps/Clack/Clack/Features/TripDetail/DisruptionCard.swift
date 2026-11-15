//
//  DisruptionCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Disruption help on a trip (owner, 2026-10-22): when a train is cancelled, skips your stop, runs late or breaks your
/// change, say what happened, what it does to the rest of the journey, what you can do now, and what you may be
/// entitled to. Calm and specific; the rules are in `Disruption`, the alternatives come from the timetable and each
/// one opens its live view. Nothing shows when all is well.
struct DisruptionCard: View {
    @Environment(AppModel.self) private var app
    let leg: LegDetail
    @State private var journey: [Leg]?

    var body: some View {
        let legs = journey ?? [leg.leg]
        let index = legs.firstIndex { $0.id == leg.id }
        let next: Leg? = index.flatMap { i in
            i + 1 < legs.count && legs[i + 1].origin?.id == leg.leg.destination?.id ? legs[i + 1] : nil
        }
        Group {
            if let next {
                DisruptionWithChange(leg: leg, next: next, journey: legs)
            } else {
                DisruptionBody(leg: leg, next: nil, connection: nil, journey: legs)
            }
        }
        .task(id: leg.leg.journeyId) {
            guard let id = leg.leg.journeyId else { return }
            journey = (try? await app.client.journey(id))?.legs.map(\.leg)
        }
    }
}

private struct DisruptionWithChange: View {
    @Environment(AppModel.self) private var app
    let leg: LegDetail
    let next: Leg
    let journey: [Leg]
    @State private var model = ConnectionModel()

    var body: some View {
        let result = model.result(leg.leg, next, profile: app.walkProfile)
        // A change the operators planned is theirs to judge: only a delay (or a cancellation) makes it a disruption
        // here, not our walking estimate on its own.
        let delayed = (leg.leg.arrDelayMin ?? 0) > 0 || (leg.leg.actualArr?.ms ?? 0) > (leg.leg.schedArr?.ms ?? .infinity)
            || (next.depDelayMin ?? 0) < 0 || next.canceled
        DisruptionBody(leg: leg, next: next, connection: delayed || result.status == .broken ? result.status.rawValue : nil, journey: journey)
            .task { await model.load(stationId: leg.leg.destination?.id, using: app.stations) }
    }
}

private struct DisruptionBody: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let leg: LegDetail
    let next: Leg?
    let connection: String?
    let journey: [Leg]
    /// What each search found, by its key; absent while it's looking.
    @State private var found: [String: Alternatives] = [:]
    @State private var showAlts = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            card(now: context.date.timeIntervalSince1970 * 1000)
        }
    }

    @ViewBuilder
    private func card(now: Double) -> some View {
        let l = leg.leg
        let board = leg.stops.first { $0.role == .board }
        let alight = leg.stops.first { $0.role == .alight }
        let ridden = leg.stops.filter { $0.role.isRidden }
        let deviations = ridden.flatMap(\.deviations).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let causes = ridden.flatMap(\.allCauses).reduce(into: [LegStop.Cause]()) { if !$0.contains($1) { $0.append($1) } }
        let schedDep = l.schedDep?.ms ?? 0
        let schedArr = l.schedArr?.ms ?? 0
        let arrived = l.actualArr != nil || (l.status != .planned && schedArr < now)
        // How much of your part the train runs, from its stops: a part-way train is not a cancelled one (build 86).
        let run = Disruption.cancellation(leg)
        let assessed = Disruption.assess(
            DisruptionInput(
                canceled: l.canceled, boardCanceled: board?.canceled ?? false, alightCanceled: alight?.canceled ?? false, partial: run,
                deviations: deviations, depDelayMin: l.depDelayMin, arrDelayMin: l.arrDelayMin, schedDep: schedDep,
                arrived: arrived, connection: connection
            ),
            now: now
        )
        if assessed.urgency != nil {
            let kinds = assessed.kinds
            let isSevere = kinds.contains(where: Disruption.severe.contains)
            let final = journey.last ?? l
            let op = l.operator.flatMap { app.operatorsById[$0.id] }
            let train = [op?.name ?? l.operator?.name, l.trainNumber].compactMap { $0 }.joined(separator: " ")
            let searches = searches(now: now, arrived: arrived, severe: isSevere, kinds: kinds, run: run, final: final, schedDep: schedDep, schedArr: schedArr)
            let tone: AlertTone = arrived ? .info : (isSevere || kinds.contains(.replacement) ? .severe : .warn)
            let reasons = DelayCauses.reasons(causes) { l10n.t($0) }
            let reasonSources = reasons.map(\.source).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            let tz = board?.tz ?? "Europe/Stockholm"
            AlertCard(
                tone: tone, icon: tone == .info ? "info" : "triangle-alert",
                title: l10n.t(arrived && kinds.first == .delayed ? "disruption.title.delayed_past" : "disruption.title.\(kinds.first?.rawValue ?? "delayed")"),
                dismissKey: "disruption:\(l.id):\(kinds.map(\.rawValue).joined(separator: ","))"
            ) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    ForEach(kinds, id: \.self) { kind in
                        Text(line(kind, train: train, run: run, board: board, alight: alight, next: next, arrived: arrived, tz: tz))
                            .clack(.body).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !reasons.isEmpty {
                    Text(l10n.t("disruption.why", ["reasons": reasons.map(\.text).joined(separator: l10n.t("disruption.and")), "source": reasonSources.joined(separator: ", ")]))
                        .clack(.body).fontWeight(.semibold).foregroundStyle(Ink.text)
                }
                if !searches.isEmpty {
                    alternatives(searches, final: final, now: now, schedDep: schedDep, tz: tz, op: op)
                }
                rights(journey: journey, kinds: kinds, final: final, op: op, run: run)
                if Disruption.fullyCanceled(l, partial: run) { Text(l10n.t("disruption.passportNote")).clack(.caption).foregroundStyle(Ink.text2) }
            }
            .task(id: searches.map(\.key).joined(separator: "&")) { await load(searches) }
        }
    }

    // MARK: the lines

    /// The stop of the leg with this station id.
    private func stop(_ id: String?) -> LegStop? {
        id.flatMap { id in leg.stops.first { $0.stationId == id && $0.role.isRidden } }
    }

    /// Best-known departure (or arrival) at a stop.
    private func departure(_ s: LegStop?) -> Double? { (s?.actualDep ?? s?.estimatedDep ?? s?.schedDep)?.ms }
    private func arrival(_ s: LegStop?) -> Double? { (s?.actualArr ?? s?.estimatedArr ?? s?.schedArr)?.ms }

    private func line(_ kind: DisruptionKind, train: String, run: PartialRun?, board: LegStop?, alight: LegStop?, next: Leg?, arrived: Bool, tz: String) -> String {
        let l = leg.leg
        let clock = app.settings.clock
        let from = stop(run?.runsFrom), to = stop(run?.runsTo)
        switch kind {
        case .canceled: return l10n.t("disruption.canceled", ["train": train])
        case .startsLater:
            return l10n.t("disruption.startsLater", ["train": train, "board": board?.name ?? "", "station": from?.name ?? run?.runsFromName ?? "", "time": Format.time(departure(from), tz: from?.tz ?? tz, clock: clock)])
        case .endsEarly:
            return l10n.t("disruption.endsEarly", ["train": train, "alight": alight?.name ?? "", "station": to?.name ?? run?.runsToName ?? "", "time": Format.time(arrival(to), tz: to?.tz ?? tz, clock: clock)])
        case .skipsBoard:
            guard let from else { return l10n.t("disruption.skipsBoard", ["train": train, "station": board?.name ?? ""]) }
            return l10n.t("disruption.skipsBoardNearest", ["train": train, "station": board?.name ?? "", "nearest": from.name, "time": Format.time(departure(from), tz: from.tz, clock: clock)])
        case .skipsAlight:
            guard let to else { return l10n.t("disruption.skipsAlight", ["train": train, "station": alight?.name ?? ""]) }
            return l10n.t("disruption.skipsAlightNearest", ["train": train, "station": alight?.name ?? "", "nearest": to.name, "time": Format.time(arrival(to), tz: to.tz, clock: clock)])
        case .gap:
            let gap = run?.gaps.first
            return l10n.t("disruption.gap", ["from": gap?.fromName ?? stop(gap?.from)?.name ?? "", "to": gap?.toName ?? stop(gap?.to)?.name ?? ""])
        case .replacement: return l10n.t("disruption.replacement")
        case .delayed:
            if arrived, let arr = l.arrDelayMin {
                return l10n.t("disruption.arrivedLate", ["min": String(arr), "station": alight?.name ?? ""])
            }
            return l10n.t("disruption.delayed", ["min": String(max(l.depDelayMin ?? 0, l.arrDelayMin ?? 0)), "station": alight?.name ?? ""])
        case .connectionMissed:
            return l10n.t("disruption.connectionMissed", [
                "station": next?.origin?.name ?? "",
                "next": [next?.operator?.name, next?.trainNumber].compactMap { $0 }.joined(separator: " "),
                "time": Format.time(next?.schedDep?.ms, tz: tz, clock: clock),
            ])
        case .connectionAtRisk: return l10n.t("disruption.connectionAtRisk", ["station": next?.origin?.name ?? ""])
        }
    }

    // MARK: alternatives

    /// One way to look for other trains, and what its suggestions do.
    private struct Search: Hashable {
        enum Use: Hashable {
            /// Another train for the whole of this one: "Use this instead" replaces it.
            case instead
            /// A train to add beside this one (the rest of the way from where it ends, or the way to where it starts).
            case add
        }

        /// The header over its suggestions (already in words), or nil for none.
        var title: String?
        var from: String?
        var to: String?
        var after: Double
        /// Only those arriving by then (to reach this train where it starts, or runs again).
        var before: Double?
        var exclude: String?
        var use: Use

        var key: String { "\(from ?? "")|\(to ?? "")|\(Int(after / 60_000))|\(before.map { String(Int($0 / 60_000)) } ?? "")|\(exclude ?? "")" }
    }

    /// Where to look, by what happened (build 86), the same for every train and country:
    /// - it runs only to X (or won't stop where you get off): this train to X, then the rest of the way from X; and,
    ///   before you've left, other trains from where you get on;
    /// - it starts later at Y (or won't stop where you get on): ways to Y in time for it, then other trains from your
    ///   station;
    /// - no train on a stretch: ways from where it stops to where it runs again in time for it, then on from there;
    /// - cancelled: other trains from your station; a missed change: from the change station.
    private func searches(now: Double, arrived: Bool, severe: Bool, kinds: [DisruptionKind], run: PartialRun?, final: Leg, schedDep: Double, schedArr: Double) -> [Search] {
        guard !arrived, severe else { return [] }
        let l = leg.leg
        let dest = final.destination?.id
        let started = l.actualDep != nil || now >= LiveRules.expectedDeparture(l)
        let others = Search(title: nil, from: l.origin?.id, to: dest, after: max(now, schedDep - 30 * 60_000), exclude: l.timetableTripKey, use: .instead)
        if kinds.contains(.connectionMissed), let next, !kinds.contains(.canceled), run == nil {
            let arrival = l.actualArr?.ms ?? (schedArr + Double(l.arrDelayMin ?? 0) * 60_000)
            return [Search(from: next.origin?.id, to: dest, after: arrival + 5 * 60_000, exclude: next.timetableTripKey, use: .instead)]
        }
        guard let run, run.kind == .partial else { return kinds.contains(.canceled) || kinds.contains(.skipsBoard) || kinds.contains(.skipsAlight) ? [others] : [] }
        var out: [Search] = []
        let clock = app.settings.clock
        if let to = stop(run.runsTo), let at = arrival(to) {
            out.append(Search(
                title: l10n.t("disruption.rideTo", ["station": to.name, "time": Format.time(at, tz: to.tz, clock: clock)]),
                from: to.stationId, to: dest, after: max(now, at + 2 * 60_000), exclude: l.timetableTripKey, use: .add
            ))
        }
        if let from = stop(run.runsFrom), let at = departure(from), !started {
            out.append(Search(
                title: l10n.t("disruption.getTo", ["station": from.name, "time": Format.time(at, tz: from.tz, clock: clock)]),
                from: l.origin?.id, to: from.stationId, after: max(now, at - 3 * 3_600_000), before: at - 2 * 60_000, exclude: l.timetableTripKey, use: .add
            ))
        }
        if let gap = run.gaps.first, let a = stop(gap.from), let b = stop(gap.to), let back = departure(b) {
            out.append(Search(
                title: l10n.t("disruption.bridgeGap", ["from": a.name, "to": b.name, "time": Format.time(back, tz: b.tz, clock: clock)]),
                from: a.stationId, to: b.stationId, after: max(now, (arrival(a) ?? now) + 2 * 60_000), before: back - 2 * 60_000, exclude: l.timetableTripKey, use: .add
            ))
        }
        // Other trains from your station, while you're still there.
        if !started { out.append(Search(title: out.isEmpty ? nil : l10n.t("disruption.otherTrains", ["station": l.origin?.name ?? ""]), from: others.from, to: others.to, after: others.after, exclude: others.exclude, use: .instead)) }
        return out
    }

    private func load(_ searches: [Search]) async {
        await withTaskGroup(of: (String, Alternatives?).self) { group in
            for s in searches {
                guard let from = s.from, let to = s.to, found[s.key] == nil else { continue }
                group.addTask { [client = app.client] in (s.key, try? await client.alternatives(from: from, to: to, after: s.after, exclude: s.exclude)) }
            }
            for await (key, alts) in group { found[key] = alts ?? Alternatives(direct: [], connections: []) }
        }
    }

    /// A search's suggestions, with `before` applied (the server's list is by departure, so the first ones are kept).
    private func results(_ s: Search) -> Alternatives? {
        guard let alts = found[s.key] else { return nil }
        guard let before = s.before else { return alts }
        return Alternatives(direct: alts.direct.filter { $0.to.time <= before }, connections: alts.connections.filter { $0.second.to.time <= before })
    }

    @ViewBuilder
    private func alternatives(_ searches: [Search], final: Leg, now: Double, schedDep: Double, tz: String, op: Operator?) -> some View {
        let lists = searches.map(results)
        let looking = lists.contains { $0 == nil }
        let count = lists.compactMap { $0 }.reduce(0) { $0 + $1.direct.count + $1.connections.count }
        VStack(alignment: .leading, spacing: Space.s) {
            if count > 0 {
                // A row like "About this train": the words, how many, and a chevron that turns (DESIGN §2.3, no box).
                Button {
                    withMotion(.layout, reduceMotion: reduceMotion) { showAlts.toggle() }
                } label: {
                    HStack(spacing: Space.s) {
                        Text(l10n.t(showAlts ? "disruption.hideSuggested" : "disruption.viewSuggested")).clack(.rowTitle).foregroundStyle(Ink.text)
                        Text(String(count)).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        Spacer(minLength: Space.s)
                        LucideIcon(name: "chevron-down", size: 16).foregroundStyle(Ink.text3)
                            .rotationEffect(.degrees(showAlts ? 180 : 0))
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.pressRow)
                .accessibilityValue(l10n.t(showAlts ? "common.less" : "common.more"))
            } else {
                Text(l10n.t(looking ? "disruption.looking" : "disruption.noAlternatives")).clack(.rowTitle).foregroundStyle(Ink.text2)
                    .frame(minHeight: 44)
                if !looking { Text(l10n.t("disruption.noneFound")).clack(.caption).foregroundStyle(Ink.text2) }
            }
            if showAlts, count > 0 {
                if final.id != leg.id {
                    Text(l10n.t("disruption.journeyContinues", ["station": final.destination?.name ?? ""])).clack(.caption).foregroundStyle(Ink.text2)
                }
                ForEach(Array(zip(searches, lists)), id: \.0) { search, alts in
                    if let alts, !(alts.direct.isEmpty && alts.connections.isEmpty) {
                        VStack(alignment: .leading, spacing: Space.s) {
                            if let title = search.title { Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true) }
                            ForEach(alts.direct) { r in directRow(r, use: search.use, now: now, schedDep: schedDep, tz: tz) }
                            ForEach(alts.connections) { c in connectionRow(c, now: now, schedDep: schedDep, tz: tz) }
                        }
                    }
                }
                InfoNote(l10n.t("disruption.altsNote"), more: l10n.t("disruption.altsNoteMore", ["operator": op?.name ?? l10n.t("disruption.theOperator")]))
            }
        }
    }

    private func otherDay(_ when: Double, zone: String, now: Double, schedDep: Double, tz: String) -> String? {
        Format.localDate(when, tz: zone) != Format.localDate(max(now, schedDep), tz: tz) ? Format.day(when, tz: zone, language: app.settings.language) : nil
    }

    /// "View train live": it goes to the train, so it reads as a link, not a button (DESIGN §2.3).
    private func liveLink(number: String?, date: String, key: String) -> some View {
        Button(l10n.t("disruption.viewLive")) { router.presentTrain(number: number ?? "", date: date, key: key) }
            .buttonStyle(LinkButtonStyle())
    }

    private func directRow(_ r: TripResult, use: Search.Use, now: Double, schedDep: Double, tz: String) -> some View {
        let op = r.operatorId.flatMap { app.operatorsById[$0] }
        let caption = [
            [op?.name ?? r.routeName, r.trainNumber].compactMap { $0 }.joined(separator: " "),
            otherDay(r.from.time, zone: r.from.tz, now: now, schedDep: schedDep, tz: tz),
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: Space.m) {
            OperatorBadge(op: op, size: .small)
            VStack(alignment: .leading, spacing: Space.xxs) {
                TimePair(dep: .init(time: r.from.time, tz: r.from.tz), arr: .init(time: r.to.time, tz: r.to.tz), clock: app.settings.clock)
                    .clack(.rowTitle).foregroundStyle(Ink.text)
                Text(caption).clack(.caption).foregroundStyle(Ink.text2)
                HStack(spacing: Space.l) {
                    // The one primary action of a suggestion: instead of this train, or beside it.
                    Button(l10n.t(use == .instead ? "disruption.useInstead" : "disruption.addThis")) {
                        router.openAdd(AddTrainLink(tripKey: r.key, date: r.serviceDate, fromSeq: r.from.seq, toSeq: r.to.seq, replaceLegId: use == .instead ? leg.id : nil, title: [op?.name ?? r.routeName, r.trainNumber].compactMap { $0 }.joined(separator: " ")))
                    }
                    .buttonStyle(.clack(.primary, small: true))
                    liveLink(number: r.trainNumber, date: r.serviceDate, key: r.key)
                }
                .padding(.top, Space.xs)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, Space.m)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    private func connectionRow(_ c: TimetableConnection, now: Double, schedDep: Double, tz: String) -> some View {
        let op = c.first.operatorId.flatMap { app.operatorsById[$0] }
        let caption = [
            l10n.t("add.changeAt", ["station": c.changeAt.name, "min": String(c.changeMin)]),
            otherDay(c.first.from.time, zone: c.first.from.tz, now: now, schedDep: schedDep, tz: tz),
        ].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: Space.m) {
            OperatorBadge(op: op, size: .small)
            VStack(alignment: .leading, spacing: Space.xxs) {
                TimePair(dep: .init(time: c.first.from.time, tz: c.first.from.tz), arr: .init(time: c.second.to.time, tz: c.second.to.tz), clock: app.settings.clock)
                    .clack(.rowTitle).foregroundStyle(Ink.text)
                Text(caption).clack(.caption).foregroundStyle(Ink.text2)
                liveLink(number: c.first.trainNumber, date: c.first.serviceDate, key: c.first.key)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, Space.m)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    // MARK: what you may be owed

    @ViewBuilder
    private func rights(journey: [Leg], kinds: [DisruptionKind], final: Leg, op: Operator?, run: PartialRun?) -> some View {
        let km = journey.reduce(0.0) { $0 + ($1.distanceM ?? 0) } / 1000
        let countries = journey.flatMap { [$0.origin?.country, $0.destination?.country].compactMap { $0 } }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let finalDelay = final.id == leg.id ? leg.leg.arrDelayMin : final.arrDelayMin
        // Your journey on this train is cancelled when it doesn't take you from where you get on or to where you get
        // off, wholly or for part of the way; a stop skipped in the middle, or a stretch by bus, isn't that.
        let cancelledForYou = Disruption.fullyCanceled(leg.leg, partial: run) || run?.runsFrom != nil || run?.runsTo != nil
        let rights = Disruption.passengerRights(
            countries: countries, journeyKm: km, arrDelayMin: kinds.contains(.connectionMissed) ? nil : finalDelay, canceled: cancelledForYou
        )
        let operatorName = op?.name ?? l10n.t("disruption.theOperator")
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(l10n.t("disruption.rightsTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            Text(rightsText(rights, operatorName: operatorName)).clack(.caption).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
            // Links, in accent ink (DESIGN §2.3): each opens a page outside the app.
            FlowLayout(spacing: Space.l, lineSpacing: 0) {
                if let url = rightsLink(rights) {
                    Button(l10n.t(rights == .seShort(priceReduction: true) || rights == .seShort(priceReduction: false) ? "disruption.linkSe" : "disruption.linkEu")) { openURL(url) }
                        .buttonStyle(LinkButtonStyle())
                }
                if let ticketUrl = op?.ticketUrl, let url = URL(string: ticketUrl) {
                    Button(l10n.t("disruption.linkOperator", ["operator": op?.name ?? ""])) { openURL(url) }
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
    }

    private func rightsText(_ rights: Disruption.Rights, operatorName: String) -> String {
        switch rights {
        case .operator: l10n.t("disruption.rightsOperator", ["operator": operatorName])
        case .seShort(let reduction): l10n.t(reduction ? "disruption.rightsSeShortClaim" : "disruption.rightsSeShort")
        case .eu(let claim): claim.map { l10n.t("disruption.rightsEu_\($0.rawValue)") } ?? l10n.t("disruption.rightsEu")
        }
    }

    private func rightsLink(_ rights: Disruption.Rights) -> URL? {
        switch rights {
        case .operator: nil
        case .seShort: URL(string: Disruption.rightsLinkSweden)
        case .eu: URL(string: Disruption.rightsLinkEU(app.settings.language))
        }
    }
}

/// Track work, a closed track or an incident at a station this train passes, from Network now (owner, 2026-11-15:
/// "shows me one of my trains will have trouble. Let me tap on it and figure that out"): one line each, opening it on
/// Explore's map with what's wrong. Only before and during the trip; nothing when there's none.
struct TrackWorkCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let leg: LegDetail
    let active: Bool
    @State private var found: [NetworkStatus.Disruption] = []

    var body: some View {
        Group {
            if !found.isEmpty {
                AlertCard(tone: .watch, icon: "construction", title: l10n.t("network.onYourRoute"), dismissKey: "trackwork|\(leg.id)|\(found.map(\.id).joined())") {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(found) { d in
                            Button { router.openDisruption(d.id) } label: {
                                HStack(spacing: Space.m) {
                                    VStack(alignment: .leading, spacing: Space.xxs) {
                                        Text(d.places.joined(separator: " – ")).clack(.rowTitle).foregroundStyle(Ink.text).multilineTextAlignment(.leading)
                                        Text(Format.join([l10n.t("network.kind.\(d.kind.rawValue)"), d.text(l10n.language).map { l10n.shownWhole($0).text }]))
                                            .clack(.caption).foregroundStyle(Ink.text2).lineLimit(2).multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                    LucideIcon(name: "chevron-right", size: 16).foregroundStyle(Ink.text3)
                                }
                                .frame(minHeight: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.pressRow)
                            .accessibilityHint(l10n.t("network.openProblem"))
                        }
                    }
                }
            }
        }
        .task(id: "\(leg.id)|\(active)") {
            guard active, let status = try? await app.client.networkStatus() else { found = []; return }
            found = NetworkLogic.onRoute(leg.stops, status: status)
        }
    }
}
