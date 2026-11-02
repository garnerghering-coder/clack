//
//  JourneyLegs.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A journey's trains and changes, weighted the way the owner picked (2026-11-01, style D of the demos): a thin bar of
/// the whole day on top, trains and changes to scale, then a full card per train with each change a small chip between
/// them. The trains are what you ride, so they carry the weight; a change is the joint between two of them.

/// The whole journey as one thin bar, each train a segment in its operator's colour as long as its run (filled as far
/// as it has gone), each change a gap as long as the wait; the first departure and last arrival under it.
struct JourneyBar: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let legs: [Leg]
    let now: Double
    /// The train in focus, drawn a little taller.
    var selected: String?

    private struct Piece: Identifiable {
        let id: String
        let train: Leg?
        let minutes: Double
    }

    private var pieces: [Piece] {
        var out: [Piece] = []
        for (i, leg) in legs.enumerated() {
            if i > 0 {
                let t = TripsLogic.connectionTimes(legs[i - 1], leg)
                let wait = (t.arrival.flatMap { a in t.departure.map { ($0 - a) / 60_000 } }) ?? 0
                out.append(Piece(id: "change-\(i)", train: nil, minutes: max(0, wait)))
            }
            let x = TripsLogic.expected(leg)
            let run = (x.dep.flatMap { d in x.arr.map { ($0 - d) / 60_000 } }) ?? 30
            out.append(Piece(id: leg.id, train: leg, minutes: max(1, run)))
        }
        return out
    }

    var body: some View {
        let parts = pieces
        let total = max(1, parts.reduce(0) { $0 + $1.minutes })
        let first = legs.first, last = legs.last
        let dep = first.flatMap { TripsLogic.expected($0).dep }
        let arr = last.flatMap { TripsLogic.expected($0).arr }
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { g in
                // The changes get at least a few points, so a short one still shows as a gap.
                let gaps = Double(parts.filter { $0.train == nil }.count) * 6
                let scale = max(0, g.size.width - gaps) / total
                HStack(spacing: 0) {
                    ForEach(parts) { piece in
                        if let leg = piece.train {
                            segment(leg, width: piece.minutes * scale)
                        } else {
                            Path { p in
                                p.move(to: CGPoint(x: 2, y: 5))
                                p.addLine(to: CGPoint(x: max(2, piece.minutes * scale + 4), y: 5))
                            }
                            .stroke(Ink.text3, style: StrokeStyle(lineWidth: 2, dash: [2, 2]))
                            .frame(width: piece.minutes * scale + 6, height: 10)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 10)
            HStack(spacing: 8) {
                Text("\(Format.time(dep, tz: first.map(TripsLogic.tz) ?? "Europe/Stockholm", clock: app.settings.clock)) \(first?.origin?.name ?? "")")
                Spacer(minLength: 4)
                Text(summary(dep: dep, arr: arr)).multilineTextAlignment(.center)
                Spacer(minLength: 4)
                Text("\(Format.time(arr, tz: last?.destination?.tz ?? "Europe/Stockholm", clock: app.settings.clock)) \(last?.destination?.name ?? "")")
                    .multilineTextAlignment(.trailing)
            }
            .clack(.micro).foregroundStyle(Ink.text2)
            .lineLimit(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([
            "\(first?.origin?.name ?? "") → \(last?.destination?.name ?? "")",
            summary(dep: dep, arr: arr),
        ].joined(separator: ", "))
    }

    private func summary(dep: Double?, arr: Double?) -> String {
        let changes = legs.count - 1
        let changeText = changes == 1 ? l10n.t("journey.oneChange") : l10n.t("journey.changes", ["n": String(changes)])
        guard let dep, let arr, arr > dep else { return changeText }
        return changeText + Format.separator + Format.duration((arr - dep) / 60_000)
    }

    private func segment(_ leg: Leg, width: Double) -> some View {
        let tint = operatorColor(leg.operator?.brandColor, scheme: scheme)
        let x = TripsLogic.expected(leg)
        let travelled: Double = {
            guard let d = x.dep, let a = x.arr, a > d else { return 0 }
            return min(1, max(0, (now - d) / (a - d)))
        }()
        let tall = selected == leg.id
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: Radius.bar).fill(tint.opacity(0.35))
            RoundedRectangle(cornerRadius: Radius.bar).fill(tint).frame(width: max(0, width * travelled))
        }
        .frame(width: max(2, width), height: tall ? 10 : 6)
    }
}

/// One train of a journey as a card: operator, number and live status, its run time, big departure and arrival times
/// with the stations and platforms, and how far it has gone.
struct JourneyTrainCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let leg: Leg
    let now: Double
    var selected = false

    var body: some View {
        let tint = operatorColor(leg.operator?.brandColor, scheme: scheme)
        let x = TripsLogic.expected(leg)
        let travelled: Double = {
            guard let d = x.dep, let a = x.arr, a > d else { return 0 }
            return min(1, max(0, (now - d) / (a - d)))
        }()
        let ends = TimePair.ends(leg)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ServiceHeader(op: leg.operator, number: leg.trainNumber, size: .medium, category: leg.category) {
                    if let live = leg.live, LiveRules.isFresh(live, now: now), !TripsLogic.reached(leg, now: now).arrived {
                        LiveStatus(live: live, now: now)
                    } else {
                        let s = TripsLogic.countdownStatus(l10n, leg, now: now)
                        StatusLine(s.kind, s.text)
                    }
                }
                Spacer(minLength: 8)
                // A ticket is kept with this train (open it from the train's page).
                if TicketStore.shared.entry(for: leg.id) != nil {
                    LucideIcon(name: "ticket", size: 16).foregroundStyle(Ink.text2)
                        .accessibilityLabel(l10n.t("ticket.kept"))
                }
                if let d = x.dep, let a = x.arr, a > d {
                    Text(Format.duration((a - d) / 60_000)).clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            HStack(alignment: .top, spacing: 12) {
                end(ends.dep, station: leg.origin?.name, platform: leg.depPlatform, alignment: .leading)
                Spacer(minLength: 0)
                end(ends.arr, station: leg.destination?.name, platform: leg.arrPlatform, alignment: .trailing)
            }
            ProgressBar(value: travelled, color: tint)
        }
        .padding(16)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .strokeBorder(selected ? tint : Ink.hairline, lineWidth: selected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func end(_ e: TimePair.End, station: String?, platform: String?, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            FlapTime(time: e.time ?? e.sched, sched: e.sched, tz: e.tz, clock: app.settings.clock).clack(.bigTime).foregroundStyle(Ink.text)
            Text(station ?? "").clack(.stopName).foregroundStyle(Ink.text)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            if let platform { Text(l10n.t("trips.platform", ["platform": platform])).clack(.caption).foregroundStyle(Ink.text2) }
        }
    }
}

/// The change between two trains as a small chip: how long, where, the platforms and the walk, tinted when it is tight
/// or at risk. Opens the station map when there is one. Two different stations (a walk between them) say so instead.
struct JourneyChangeChip: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let a: Leg
    let b: Leg
    @State private var model = ConnectionModel()

    var body: some View {
        Group {
            if a.destination?.id == b.origin?.id {
                let result = model.result(a, b, profile: app.walkProfile)
                let wait = result.gapMin ?? result.layoverSeconds.map { Int((Double($0) / 60).rounded()) }
                let walk = result.walkSeconds.map { max(1, Int(($0 / 60).rounded())) }
                let text = [
                    wait.map { l10n.t("journey.changeChip", ["min": String($0), "station": a.destination?.name ?? ""]) }
                        ?? l10n.t("connection.changeAt", ["station": a.destination?.name ?? ""]),
                    (a.arrPlatform != nil || b.depPlatform != nil)
                        ? l10n.t("connection.tracks", ["from": a.arrPlatform ?? Format.unknown, "to": b.depPlatform ?? Format.unknown]) : nil,
                    walk.map { l10n.t("connection.walk", ["min": String($0)]) },
                ].compactMap { $0 }.joined(separator: Format.separator)
                let ink: Color = switch result.comfort {
                case .tight?: Ink.slightInk
                case .risky?: Ink.veryLateInk
                default: switch result.status { case .tight: Ink.slightInk; case .miss, .broken: Ink.veryLateInk; default: Ink.text2 }
                }
                // Every change chip the same width, centred between the train cards (owner, 2026-11-02).
                let chip = HStack(spacing: 8) {
                    LucideIcon(name: "arrow-down", size: 13)
                    Text(text).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    if model.map != nil { LucideIcon(name: "map", size: 13) }
                }
                .clack(.chip).foregroundStyle(ink)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Ink.fillSoft, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                if model.map != nil, let stationId = a.destination?.id {
                    NavigationLink(value: AppRoute.stationMap(TripsLogic.mapLink(stationId, a, b))) { chip }
                        .buttonStyle(.plain)
                        .accessibilityLabel(text)
                        .accessibilityHint(l10n.t("trips.layoverOpen", ["station": a.destination?.name ?? ""]))
                } else {
                    chip.accessibilityElement(children: .combine)
                }
            } else {
                TransferChip(prev: a, next: b, plain: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .task { await model.load(stationId: a.destination?.id, using: app.stations) }
    }
}

/// Every train of a journey as a card, the changes as chips between them. A card opens its train (`open`), or, inside
/// the journey screen, puts it in focus (`select`).
struct JourneyLegs: View {
    let legs: [Leg]
    let now: Double
    var selected: String?
    var select: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(legs.enumerated()), id: \.element.id) { i, leg in
                if i > 0 { JourneyChangeChip(a: legs[i - 1], b: leg) }
                if let select {
                    Button { select(leg.id) } label: { JourneyTrainCard(leg: leg, now: now, selected: selected == leg.id) }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == leg.id ? .isSelected : [])
                } else {
                    NavigationLink(value: AppRoute.trip(leg.id)) { JourneyTrainCard(leg: leg, now: now, selected: selected == leg.id) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}
