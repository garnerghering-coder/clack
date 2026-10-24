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
    let leg: LegDetail
    let next: Leg?
    let connection: String?
    let journey: [Leg]
    @State private var alts: Alternatives?
    @State private var showAlts = false

    private static let severe: Set<DisruptionKind> = [.canceled, .skipsBoard, .skipsAlight, .connectionMissed]

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
        let schedDep = l.schedDep?.ms ?? 0
        let schedArr = l.schedArr?.ms ?? 0
        let arrived = l.actualArr != nil || (l.status != .planned && schedArr < now)
        let assessed = Disruption.assess(
            DisruptionInput(
                canceled: l.canceled, boardCanceled: board?.canceled ?? false, alightCanceled: alight?.canceled ?? false,
                deviations: deviations, depDelayMin: l.depDelayMin, arrDelayMin: l.arrDelayMin, schedDep: schedDep,
                arrived: arrived, connection: connection
            ),
            now: now
        )
        if let urgency = assessed.urgency {
            let kinds = assessed.kinds
            let isSevere = kinds.contains(where: Self.severe.contains)
            let final = journey.last ?? l
            let op = l.operator.flatMap { app.operatorsById[$0.id] }
            let train = [op?.name ?? l.operator?.name, l.trainNumber].compactMap { $0 }.joined(separator: " ")
            let search = searchParams(now: now, arrived: arrived, severe: isSevere, kinds: kinds, final: final, schedDep: schedDep, schedArr: schedArr)
            let tone: AlertTone = arrived ? .info : (isSevere || kinds.contains(.replacement) ? .severe : .warn)
            let reasons = Disruption.reasons(deviations, language: app.settings.language)
            let altCount = alts.map { $0.direct.count + $0.connections.count }
            let tz = board?.tz ?? "Europe/Stockholm"
            let _ = urgency
            AlertCard(
                tone: tone, icon: tone == .info ? "info" : "triangle-alert",
                title: l10n.t(arrived && kinds.first == .delayed ? "disruption.title.delayed_past" : "disruption.title.\(kinds.first?.rawValue ?? "delayed")"),
                dismissKey: "disruption:\(l.id):\(kinds.map(\.rawValue).joined(separator: ","))"
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(kinds, id: \.self) { kind in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("•")
                            Text(line(kind, train: train, board: board, alight: alight, next: next, arrived: arrived, tz: tz))
                        }
                        .clack(.body).foregroundStyle(Ink.text)
                    }
                }
                if !reasons.isEmpty {
                    Text(l10n.t("disruption.why", ["reasons": reasons.joined(separator: l10n.t("disruption.and"))]))
                        .clack(.body).fontWeight(.semibold).foregroundStyle(Ink.text)
                }
                if search != nil {
                    alternatives(search: search, altCount: altCount, final: final, now: now, schedDep: schedDep, tz: tz, op: op, tone: tone)
                }
                rights(journey: journey, kinds: kinds, final: final, op: op)
                if l.canceled { Text(l10n.t("disruption.passportNote")).clack(.caption).foregroundStyle(Ink.text2) }
            }
            .task(id: searchKey(search)) { await loadAlternatives(search) }
        }
    }

    // MARK: the lines

    private func line(_ kind: DisruptionKind, train: String, board: LegStop?, alight: LegStop?, next: Leg?, arrived: Bool, tz: String) -> String {
        let l = leg.leg
        switch kind {
        case .canceled: return l10n.t("disruption.canceled", ["train": train])
        case .skipsBoard: return l10n.t("disruption.skipsBoard", ["train": train, "station": board?.name ?? ""])
        case .skipsAlight: return l10n.t("disruption.skipsAlight", ["train": train, "station": alight?.name ?? ""])
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
                "time": Format.time(next?.schedDep?.ms, tz: tz, clock: app.settings.clock),
            ])
        case .connectionAtRisk: return l10n.t("disruption.connectionAtRisk", ["station": next?.origin?.name ?? ""])
        }
    }

    // MARK: alternatives

    private struct Search: Hashable {
        var from: String?
        var to: String?
        var after: Double
        var exclude: String?
    }

    /// Other ways: from where you are (your station, or the change you'll miss) to the journey's end.
    private func searchParams(now: Double, arrived: Bool, severe: Bool, kinds: [DisruptionKind], final: Leg, schedDep: Double, schedArr: Double) -> Search? {
        guard !arrived, severe else { return nil }
        let l = leg.leg
        if kinds.contains(.connectionMissed), let next, !kinds.contains(.canceled) {
            let arrival = l.actualArr?.ms ?? (schedArr + Double(l.arrDelayMin ?? 0) * 60_000)
            return Search(from: next.origin?.id, to: final.destination?.id, after: arrival + 5 * 60_000, exclude: next.timetableTripKey)
        }
        return Search(from: l.origin?.id, to: final.destination?.id, after: max(now, schedDep - 30 * 60_000), exclude: l.timetableTripKey)
    }

    private func searchKey(_ search: Search?) -> String {
        search.map { "\($0.from ?? "")|\($0.to ?? "")|\(Int($0.after / 60_000))|\($0.exclude ?? "")" } ?? ""
    }

    private func loadAlternatives(_ search: Search?) async {
        guard let search, let from = search.from, let to = search.to else {
            alts = nil
            return
        }
        alts = try? await app.client.alternatives(from: from, to: to, after: search.after, exclude: search.exclude)
    }

    @ViewBuilder
    private func alternatives(search: Search?, altCount: Int?, final: Leg, now: Double, schedDep: Double, tz: String, op: Operator?, tone: AlertTone) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showAlts.toggle()
            } label: {
                HStack(spacing: 8) {
                    Text(altCount == nil ? l10n.t("disruption.looking")
                        : altCount == 0 ? l10n.t("disruption.noAlternatives")
                        : showAlts ? l10n.t("disruption.hideSuggested") : l10n.t("disruption.viewSuggested"))
                        .clack(.button).fontWeight(.bold).foregroundStyle(Ink.text)
                    Spacer(minLength: 0)
                    if let altCount, altCount > 0 { LucideIcon(name: showAlts ? "chevron-up" : "chevron-down", size: 18).foregroundStyle(Ink.text) }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .hairlineBorder(radius: Radius.input, color: tone.color.opacity(0.4))
                .opacity(altCount == 0 || altCount == nil ? 0.7 : 1)
            }
            .buttonStyle(.plain)
            .disabled((altCount ?? 0) == 0)
            if altCount == 0 { Text(l10n.t("disruption.noneFound")).clack(.caption).foregroundStyle(Ink.text2) }
            if showAlts, let alts, (altCount ?? 0) > 0 {
                if final.id != leg.id {
                    Text(l10n.t("disruption.journeyContinues", ["station": final.destination?.name ?? ""])).clack(.caption).foregroundStyle(Ink.text2)
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(alts.direct) { r in directRow(r, now: now, schedDep: schedDep, tz: tz) }
                    ForEach(alts.connections) { c in connectionRow(c, now: now, schedDep: schedDep, tz: tz) }
                }
                Text(l10n.t("disruption.altsNote", ["operator": op?.name ?? l10n.t("disruption.theOperator")])).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }

    private func otherDay(_ when: Double, zone: String, now: Double, schedDep: Double, tz: String) -> String? {
        Format.localDate(when, tz: zone) != Format.localDate(max(now, schedDep), tz: tz) ? Format.day(when, tz: zone, language: app.settings.language) : nil
    }

    private func directRow(_ r: TripResult, now: Double, schedDep: Double, tz: String) -> some View {
        let op = r.operatorId.flatMap { app.operatorsById[$0] }
        let caption = [
            [op?.name ?? r.routeName, r.trainNumber].compactMap { $0 }.joined(separator: " "),
            otherDay(r.from.time, zone: r.from.tz, now: now, schedDep: schedDep, tz: tz),
        ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 10) {
            OperatorBadge(op: op, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Format.time(r.from.time, tz: r.from.tz, clock: app.settings.clock)) → \(Format.time(r.to.time, tz: r.to.tz, clock: app.settings.clock))")
                    .clack(.rowTitle).monospacedDigit().foregroundStyle(Ink.text)
                Text(caption).clack(.caption).foregroundStyle(Ink.text2)
                HStack(spacing: 8) {
                    Button(l10n.t("disruption.live")) { router.openTrain(number: r.trainNumber ?? "", date: r.serviceDate, key: r.key) }
                        .buttonStyle(.clack(small: true))
                    Button(l10n.t("disruption.useInstead")) {
                        router.openAdd(AddTrainLink(tripKey: r.key, date: r.serviceDate, fromSeq: r.from.seq, toSeq: r.to.seq, replaceLegId: leg.id))
                    }
                    .buttonStyle(.clack(.primary, small: true))
                }
                .padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    private func connectionRow(_ c: TimetableConnection, now: Double, schedDep: Double, tz: String) -> some View {
        let op = c.first.operatorId.flatMap { app.operatorsById[$0] }
        let caption = [
            l10n.t("add.changeAt", ["station": c.changeAt.name, "min": String(c.changeMin)]),
            otherDay(c.first.from.time, zone: c.first.from.tz, now: now, schedDep: schedDep, tz: tz),
        ].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .top, spacing: 10) {
            OperatorBadge(op: op, size: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Format.time(c.first.from.time, tz: c.first.from.tz, clock: app.settings.clock)) → \(Format.time(c.second.to.time, tz: c.second.to.tz, clock: app.settings.clock))")
                    .clack(.rowTitle).monospacedDigit().foregroundStyle(Ink.text)
                Text(caption).clack(.caption).foregroundStyle(Ink.text2)
                Button(l10n.t("disruption.live")) { router.openTrain(number: c.first.trainNumber ?? "", date: c.first.serviceDate, key: c.first.key) }
                    .buttonStyle(.clack(small: true)).padding(.top, 4)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: what you may be owed

    @ViewBuilder
    private func rights(journey: [Leg], kinds: [DisruptionKind], final: Leg, op: Operator?) -> some View {
        let km = journey.reduce(0.0) { $0 + ($1.distanceM ?? 0) } / 1000
        let countries = journey.flatMap { [$0.origin?.country, $0.destination?.country].compactMap { $0 } }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let finalDelay = final.id == leg.id ? leg.leg.arrDelayMin : final.arrDelayMin
        let rights = Disruption.passengerRights(
            countries: countries, journeyKm: km, arrDelayMin: kinds.contains(.connectionMissed) ? nil : finalDelay, canceled: leg.leg.canceled
        )
        let operatorName = op?.name ?? l10n.t("disruption.theOperator")
        VStack(alignment: .leading, spacing: 6) {
            Text(l10n.t("disruption.rightsTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            Text(rightsText(rights, operatorName: operatorName)).clack(.caption).foregroundStyle(Ink.text2)
            HStack(spacing: 12) {
                if let url = rightsLink(rights) {
                    Link(l10n.t(rights == .seShort(priceReduction: true) || rights == .seShort(priceReduction: false) ? "disruption.linkSe" : "disruption.linkEu"), destination: url)
                }
                if let ticketUrl = op?.ticketUrl, let url = URL(string: ticketUrl) {
                    Link(l10n.t("disruption.linkOperator", ["operator": op?.name ?? ""]), destination: url)
                }
            }
            .clack(.caption).fontWeight(.semibold).tint(Ink.accentInk)
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
        case .eu: Disruption.rightsLinkEU[app.settings.language == .sv ? .sv : .en].flatMap(URL.init(string:))
        }
    }
}
