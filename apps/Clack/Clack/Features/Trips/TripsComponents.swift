//
//  TripsComponents.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

extension TimePair {
    /// A trip's departure and arrival as expected now, against the timetable, each in its station's time zone.
    init(leg: Leg, clock: ClockFormat, flap: FlapTime.Style? = nil, intro: Bool = false) {
        let ends = TimePair.ends(leg)
        self.init(dep: ends.dep, arr: ends.arr, clock: clock, flap: flap, intro: intro)
    }

    /// A whole journey: the first train's departure and the last one's arrival (owner, 2026-11-01).
    init(journey legs: [Leg], clock: ClockFormat, flap: FlapTime.Style? = nil, intro: Bool = false) {
        guard let first = legs.first, let last = legs.last else {
            self.init(dep: End(time: nil, tz: "Europe/Stockholm"), arr: End(time: nil, tz: "Europe/Stockholm"), clock: clock, flap: flap, intro: intro)
            return
        }
        self.init(dep: TimePair.ends(first).dep, arr: TimePair.ends(last).arr, clock: clock, flap: flap, intro: intro)
    }

    static func ends(_ leg: Leg) -> (dep: End, arr: End) {
        let x = TripsLogic.expected(leg)
        return (
            End(time: x.dep, sched: leg.schedDep?.ms, tz: TripsLogic.tz(leg)),
            End(time: x.arr, sched: leg.schedArr?.ms, tz: leg.destination?.tz ?? TripsLogic.tz(leg))
        )
    }
}

/// "Departs in 2h 5m", "Boarding", "Live now", "Arrived", "Cancelled" (countdown() in TripsPage.tsx).
extension TripsLogic {
    @MainActor
    static func countdown(_ l10n: L10n, _ leg: Leg, now: Double) -> String {
        countdownStatus(l10n, leg, now: now).text
    }

    /// The countdown as a written status: its words and the kind of status they are (for the ink).
    @MainActor
    static func countdownStatus(_ l10n: L10n, _ leg: Leg, now: Double) -> (kind: StatusLine.Kind, text: String) {
        let dep = LiveRules.expectedDeparture(leg)
        if leg.canceled || leg.live?.status == .cancelled { return (.cancelled, l10n.t("status.cancelled")) }
        if now >= arrivalOf(leg) { return (.arrived, l10n.t("trips.arrived")) }
        // The live state knows where the train is: on its way to your stop, at it, or yet to be 30 minutes from leaving.
        let fresh = leg.live.map { LiveRules.isFresh($0, now: now) } ?? false
        if fresh, let status = leg.live?.status {
            if status == .approaching { return (.onItsWay, l10n.t("trips.approaching")) }
            if status == .boarding { return (.boarding, l10n.t("trips.boarding")) }
        }
        if now >= dep { return (.live, l10n.t("trips.liveNow")) }
        // With no live data (or none fresh) the timetable, moved by the delay known so far, decides.
        if !fresh, dep - now <= 30 * 60_000 { return (.boarding, l10n.t("trips.boarding")) }
        let mins = Int(((dep - now) / 60_000).rounded())
        let d = mins / 1440
        let h = (mins % 1440) / 60
        let m = mins % 60
        return (.upcoming, l10n.t("trips.departsIn", ["time": d > 0 ? "\(d)d \(h)h" : h > 0 ? "\(h)h \(m)m" : "\(m) min"]))
    }
}

/// A trip's countdown as one written status line ("Departs in 2h 5m", "Boarding", "Live now").
struct CountdownLine: View {
    @Environment(L10n.self) private var l10n
    let leg: Leg
    let now: Double

    var body: some View {
        let status = TripsLogic.countdownStatus(l10n, leg, now: now)
        StatusLine(status.kind, status.text)
    }
}

/// A trip as a gradient pill (the featured card's look, smaller and quieter): upcoming trips under the featured one,
/// past trips, the Passport log and journeys. Upcoming ones lead with the countdown.
struct LegRow: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let leg: Leg
    var upcoming = false
    /// Inside a journey card the legs sit flat; the card carries the colour.
    var flat = false
    /// Opens the trip's page; off for a planned train that isn't saved yet.
    var linked = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date.timeIntervalSince1970 * 1000
            if linked {
                NavigationLink(value: AppRoute.trip(leg.id)) { content(now: now).modifier(ZoomSource(id: "trip-\(leg.id)")) }
                    .buttonStyle(.press(radius: flat ? 0 : Radius.card, scales: !flat))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(TripsSpeech.leg(leg, l10n: l10n, settings: app.settings))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("trips.leg")
            } else {
                content(now: now)
            }
        }
    }

    private func content(now: Double) -> some View {
        let op = operatorColor(leg.operator?.brandColor, scheme: scheme)
        let service = [leg.operator?.name, leg.trainNumber].compactMap { $0 }.joined(separator: " ")
        let meta2 = [
            service.isEmpty ? nil : service,
            upcoming ? leg.depPlatform.map { l10n.t("trips.platform", ["platform": $0]) } : nil,
        ].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .center, spacing: Space.m) {
            OperatorBadge(op: leg.operator, size: .large)
            VStack(alignment: .leading, spacing: Space.xxs) {
                if upcoming { CountdownLine(leg: leg, now: now) }
                Text(verbatim: "\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                    .clack(.rowTitle).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                metaLine
                if !meta2.isEmpty { Text(meta2).clack(.caption).foregroundStyle(Ink.text2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            side
        }
        .padding(.vertical, flat ? Space.s : Space.m)
        .padding(.horizontal, flat ? 0 : Space.l)
        .background {
            if !flat { Surface.Pill(op: op) }
        }
        .clipShape(RoundedRectangle(cornerRadius: flat ? 0 : Radius.card, style: .continuous))
        .overlay {
            if !flat { RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Ink.hairline, lineWidth: 1) }
        }
        .opacity(leg.ride == .notTaken ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    /// "Fri 23 Oct · 07:14 – 10:30 · 5h 16m".
    private var metaLine: some View {
        let dep = leg.schedDep?.ms
        let ends = TimePair.ends(leg)
        var text = Text("")
        if let dep { text = Text(Format.day(dep, tz: TripsLogic.tz(leg), language: app.settings.language) + Format.separator) }
        text = text + TimePair.text(ends.dep, ends.arr, clock: app.settings.clock)
        if let dep, let arr = leg.schedArr?.ms { text = text + Text(Format.separator + Format.duration((arr - dep) / 60_000, language: l10n.language)) }
        return text.clack(.caption).foregroundStyle(Ink.text2).monospacedDigit()
    }

    private var side: some View {
        VStack(alignment: .trailing, spacing: Space.xs) {
            if leg.ride == .review { Chip(text: l10n.t("record.needsCheck"), tint: Ink.warnText) }
            if leg.ride == .notTaken { Chip(text: l10n.t("record.notTaken")) }
            if !linked {
                // A planned train not saved yet: no delay to show, only its distance.
                Text(distance).clack(.caption).foregroundStyle(Ink.text2)
            } else if upcoming {
                if leg.depDelayMin != nil { DelayText(delay: leg.depDelayMin, canceled: leg.canceled) }
            } else {
                // Legs inside a journey show the delay beside their times, not again here.
                if !flat { DelayText(delay: (leg.dataQuality == .scheduledOnly && leg.status == .planned) ? nil : leg.arrDelayMin, canceled: leg.canceled) }
                Text(distance).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }

    private var distance: String {
        let text = Format.distance(leg.distanceM, unit: app.settings.distanceUnit, language: app.settings.language)
        return leg.isEstimatedGeometry ? l10n.t("trips.approxDistance", ["distance": text]) : text
    }
}

/// A dashed vertical line, drawn as the web's `repeating-linear-gradient` (3 pt on, 3 or 4 off).
struct DashedLine: View {
    var width: CGFloat = 2
    var dash: CGFloat = 3
    var gap: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: width / 2, y: 0))
                path.addLine(to: CGPoint(x: width / 2, y: proxy.size.height))
            }
            .stroke(Ink.text3, style: StrokeStyle(lineWidth: width, lineCap: .butt, dash: [dash, gap]))
        }
        .frame(width: width)
    }
}

/// Between two trips that meet at a station (brief §7): how long you have there, the arrival and departure (a delay
/// strikes the timetabled time), the tracks when known. With a station map it opens the Layover Guide.
struct Layover: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let a: Leg
    let b: Leg
    @State private var model = ConnectionModel()

    var body: some View {
        let times = TripsLogic.connectionTimes(a, b)
        if let arrival = times.arrival, let departure = times.departure {
            let linked = model.info?.hasMap == true
            let station = a.destination?.name ?? ""
            let min = Int(((departure - arrival) / 60_000).rounded())
            let schedA = a.schedArr?.ms
            let schedB = b.schedDep?.ms
            let schedMin = (schedA != nil && schedB != nil) ? Int(((schedB! - schedA!) / 60_000).rounded()) : nil
            let tracks = (a.arrPlatform != nil || b.depPlatform != nil)
                ? Format.changeTracks(l10n, arrival: a.arrPlatform, departure: b.depPlatform) : nil
            let tz = a.destination?.tz ?? "Europe/Stockholm"
            let atRisk = min < 0
            let body = HStack(spacing: Space.m) {
                DashedLine(dash: 3, gap: 4).frame(minHeight: 34)
                VStack(alignment: .leading, spacing: Space.xs) {
                    HStack(spacing: Space.s) {
                        LucideIcon(name: "clock", size: 14)
                        if atRisk {
                            Text(l10n.t("trips.layoverMissed", ["station": station]))
                        } else {
                            if let schedMin, schedMin != min {
                                Text(Format.duration(Double(schedMin), language: l10n.language)).strikethrough().foregroundStyle(Ink.text3).fontWeight(.medium)
                            }
                            Text(Format.duration(Double(min), language: l10n.language))
                                .foregroundStyle(schedMin != nil && schedMin != min ? Ink.accentInk : Ink.text2)
                            + Text(" " + l10n.t("trips.layoverAt", ["station": station]))
                        }
                    }
                    .clack(.banner).fontWeight(.semibold)
                    (TimePair.text(.init(time: arrival, sched: schedA, tz: tz), .init(time: departure, sched: schedB, tz: tz), clock: app.settings.clock)
                        + Text(tracks.map { Format.separator + $0 } ?? ""))
                        .clack(.caption)
                    if linked {
                        HStack(spacing: Space.xs) {
                            LucideIcon(name: "map", size: 14)
                            Text(l10n.t("trips.layoverMap") + " ›")
                        }
                        .clack(.caption).foregroundStyle(Ink.accentInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.xs)
            }
            .foregroundStyle(atRisk ? Ink.veryLateInk : Ink.text2)
            .padding(.leading, 28) // design-lint: allow lines up with the leg rail's text column
            .padding(.trailing, Space.m)
            .padding(.vertical, Space.xs)
            .background {
                if linked {
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous).fill(Ink.surface.opacity(0.6))
                }
            }
            .overlay {
                if linked {
                    RoundedRectangle(cornerRadius: Radius.input, style: .continuous)
                        .strokeBorder(Ink.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            Group {
                if linked, let id = a.destination?.id {
                    NavigationLink(value: AppRoute.stationMap(TripsLogic.mapLink(id, a, b))) { body }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l10n.t("trips.layoverOpen", ["station": station]))
                } else {
                    body
                }
            }
            .task { await model.load(stationId: a.destination?.id, using: app.stations) }
        }
    }
}

/// `TransferChip`: the planned transfer between two legs, in a caption beside a dashed line.
struct TransferChip: View {
    @Environment(L10n.self) private var l10n
    let prev: Leg
    let next: Leg
    /// Just the line, for a journey rail that draws the connection itself.
    var plain = false

    var body: some View {
        let t = TripsLogic.transfer(from: prev, to: next)
        var text = l10n.t("journey.transfer", ["min": String(t.planned), "station": t.station])
        if let actual = t.actual, actual != t.planned, !t.missed { text += " · " + l10n.t("journey.actually", ["min": String(actual)]) }
        if t.missed { text += " · " + l10n.t("journey.missed") } else if t.tight { text += " · " + l10n.t("journey.tight") }
        if plain {
            return AnyView(StatusLine(t.missed ? .band(.veryLate) : t.tight ? .band(.slight) : .arrived, text).frame(maxWidth: .infinity, alignment: .leading))
        }
        return AnyView(HStack(spacing: Space.m) {
            DashedLine(dash: 3, gap: 3).frame(height: 22)
            StatusLine(t.missed ? .band(.veryLate) : t.tight ? .band(.slight) : .arrived, text)
        }
        .padding(.vertical, Space.xxs)
        .padding(.leading, Space.l))
    }
}

/// A multi-leg journey in the Trips list. Legs in travel order; one card, with each train's operator colour glowing
/// beside its own row.
struct JourneyCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let legs: [Leg]

    /// One compact row per journey (designer, 2026-11-14: the list repeated the detail screen, a card per train inside
    /// a card per journey): the label, the route, the day as a slim strip with the times, the changes and the length.
    /// The whole row opens the journey; its trains are there.
    var body: some View {
        let first = legs[0]
        let last = legs[legs.count - 1]
        let route = first.journeyId.map { AppRoute.journey($0) } ?? .trip(first.id)
        NavigationLink(value: route) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(alignment: .leading, spacing: Space.s) {
                    HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                        Text(l10n.t("journey.label", count: legs.count)).clack(.captionUpper).foregroundStyle(Ink.text2)
                        Spacer(minLength: Space.s)
                        if let dep = first.schedDep?.ms {
                            Text(Format.day(dep, tz: TripsLogic.tz(first), language: app.settings.language)).clack(.caption).foregroundStyle(Ink.text2)
                        }
                    }
                    Text(verbatim: "\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
                        .clack(.rowTitle).foregroundStyle(Ink.text)
                        .fixedSize(horizontal: false, vertical: true)
                    JourneyBar(legs: legs, now: context.date.timeIntervalSince1970 * 1000)
                }
                .padding(Space.l)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    ZStack {
                        Ink.surface
                        ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                            CSSRadialGradient(
                                rx: 0.75, ry: 1.1 / Double(legs.count), cx: 1, cy: (Double(index) + 0.6) / Double(legs.count),
                                stops: [
                                    .init(color: operatorColor(leg.operator?.brandColor, scheme: scheme).opacity(0.18), location: 0),
                                    .init(color: operatorColor(leg.operator?.brandColor, scheme: scheme).opacity(0), location: 0.7),
                                ]
                            )
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .hairlineBorder(radius: Radius.card)
                .modifier(ZoomSource(id: first.journeyId.map { "journey-\($0)" } ?? "trip-\(first.id)"))
            }
        }
        .buttonStyle(.press)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TripsSpeech.journey(legs, l10n: l10n, settings: app.settings))
        .accessibilityAddTraits(.isButton)
    }
}

/// What a trip or a journey in the list says to VoiceOver: one sentence, not its pieces (polish pass 1: "07:14
/// 07:20 right arrow" and, on the featured card, only "View journey").
@MainActor
enum TripsSpeech {
    static func leg(_ leg: Leg, l10n: L10n, settings: Settings) -> String {
        let tz = TripsLogic.tz(leg)
        let ends = TimePair.ends(leg)
        let delay = leg.canceled ? l10n.t("delay.cancelled") : (leg.arrDelayMin ?? leg.depDelayMin).flatMap { $0 > 0 ? l10n.t("passport.minutesLate", count: $0) : nil }
        return Format.join([
            Format.service(leg.operator?.name, leg.trainNumber),
            l10n.t("speech.fromTo", ["from": leg.origin?.name ?? "", "to": leg.destination?.name ?? ""]),
            leg.schedDep.map { Format.day($0.ms, tz: tz, language: settings.language) },
            l10n.t("speech.times", [
                "dep": Format.time(ends.dep.time, tz: ends.dep.tz, clock: settings.clock),
                "arr": Format.time(ends.arr.time, tz: ends.arr.tz, clock: settings.clock),
            ]),
            delay,
            leg.depPlatform.map { l10n.t("trips.platform", ["platform": $0]) },
        ], separator: ", ")
    }

    static func journey(_ legs: [Leg], l10n: L10n, settings: Settings) -> String {
        guard let first = legs.first, let last = legs.last else { return "" }
        let a = TimePair.ends(first), b = TimePair.ends(last)
        return Format.join([
            l10n.t("journey.label", count: legs.count),
            l10n.t("speech.fromTo", ["from": first.origin?.name ?? "", "to": last.destination?.name ?? ""]),
            first.schedDep.map { Format.day($0.ms, tz: TripsLogic.tz(first), language: settings.language) },
            l10n.t("speech.times", [
                "dep": Format.time(a.dep.time, tz: a.dep.tz, clock: settings.clock),
                "arr": Format.time(b.arr.time, tz: b.arr.tz, clock: settings.clock),
            ]),
        ], separator: ", ")
    }
}

/// The dotted line of the empty states (`.dotted-line`): a curve with a dashed stroke, optionally with an end dot.
struct DottedLine: View {
    var endDots = false

    var body: some View {
        Canvas { context, size in
            let sx = size.width / 300
            let sy = size.height / 60
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y * sy) }
            var path = Path()
            path.move(to: p(10, 45))
            path.addCurve(to: p(290, 15), control1: p(80, 5), control2: p(200, 70))
            context.stroke(path, with: .color(Ink.accentLine.opacity(0.85)), style: StrokeStyle(lineWidth: 3 * sx, lineCap: .round, dash: [2 * sx, 9 * sx]))
            if endDots {
                for point in [p(10, 45), p(290, 15)] {
                    context.fill(Path(ellipseIn: CGRect(x: point.x - 5 * sx, y: point.y - 5 * sx, width: 10 * sx, height: 10 * sx)), with: .color(Ink.accentLine))
                }
            }
        }
        .frame(width: 220, height: 44)
        .accessibilityHidden(true)
    }
}

/// Nothing featured: say so, and offer the two ways on (NothingAhead).
struct NothingAhead: View {
    @Environment(Router.self) private var router
    @Environment(L10n.self) private var l10n

    var body: some View {
        VStack(spacing: Space.m) {
            DottedLine(endDots: true)
            Text(l10n.t("trips.whereNext")).clack(.headline).foregroundStyle(Ink.text)
            Text(l10n.t("trips.whereNextBody")).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
            EmptyActions()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.xl)
        .padding(.horizontal, Space.l)
        .background(Surface.Hero())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }
}

/// "Find a train" and "Explore trains": the two ways on from an empty Trips screen.
struct EmptyActions: View {
    @Environment(Router.self) private var router
    @Environment(L10n.self) private var l10n

    var body: some View {
        // Stacked and the same width, the main one first, as in the system's empty states.
        VStack(spacing: Space.m) {
            Button {
                router.openAdd()
            } label: {
                HStack(spacing: Space.s) {
                    LucideIcon(name: "plus", size: 18)
                    Text(l10n.t("trips.findTrain"))
                }
            }
            .buttonStyle(.clack(.primary, wide: true))
            Button {
                router.tab = .explore
            } label: {
                HStack(spacing: Space.s) {
                    LucideIcon(name: "compass", size: 18)
                    Text(l10n.t("trips.exploreTrains"))
                }
            }
            .buttonStyle(.clack(wide: true))
        }
        .frame(maxWidth: 320)
        .padding(.top, Space.xs)
    }
}

/// Trains you follow on Explore: watched, not travelled, so they sit apart from your trips and never count.
struct FollowingSection: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var scheme
    let follows: [Follow]

    var body: some View {
        if !follows.isEmpty {
            VStack(alignment: .leading, spacing: Space.s) {
                Text(l10n.t("trips.following")).clack(.sectionHeader).foregroundStyle(Ink.text2).padding(.top, Space.xxs)
                ForEach(Self.grouped(follows), id: \.id) { item in
                    if item.follows.count > 1 || item.label != nil {
                        // Followed together from a planned journey: one journey, its trains inside (as on Trips).
                        VStack(alignment: .leading, spacing: Space.s) {
                            HStack(spacing: Space.s) {
                                LucideIcon(name: "route", size: 16)
                                Text(item.label ?? "").clack(.rowTitle).foregroundStyle(Ink.text)
                                Spacer(minLength: 0)
                                Text(l10n.t("journey.trains", ["n": String(item.follows.count)])).clack(.caption).foregroundStyle(Ink.text2)
                            }
                            ForEach(item.follows, id: \.self) { follow in trainButton(follow) }
                        }
                        .padding(Space.m)
                        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                        .hairlineBorder(radius: Radius.card)
                    } else if let follow = item.follows.first {
                        trainButton(follow)
                    }
                }
                InfoNote(l10n.t("trips.followingNote"), more: l10n.t("trips.followingNoteMore"))
            }
            .padding(.top, Space.xxs)
        }
    }

    private func trainButton(_ follow: Follow) -> some View {
        let op = follow.operatorId.flatMap { app.operatorsById[$0] }
        return Button {
            router.presentTrain(number: follow.trainNumber, date: follow.serviceDate)
        } label: {
            row(follow, op: op)
        }
        .buttonStyle(.plain)
    }

    struct Item {
        let id: String
        let label: String?
        var follows: [Follow]
    }

    /// Follows in order, those of one planned journey together under its name.
    static func grouped(_ follows: [Follow]) -> [Item] {
        var out: [Item] = []
        var at: [String: Int] = [:]
        for f in follows {
            if let g = f.journeyGroup {
                if let i = at[g] { out[i].follows.append(f) } else { at[g] = out.count; out.append(Item(id: g, label: f.journeyLabel, follows: [f])) }
            } else {
                out.append(Item(id: "\(f.trainNumber)|\(f.serviceDate)", label: nil, follows: [f]))
            }
        }
        return out
    }

    private func row(_ follow: Follow, op: Operator?) -> some View {
        let color = operatorColor(op?.brandColor, scheme: scheme)
        let nextLine = follow.train?.next.map {
            l10n.t("live.nextStop", ["name": $0, "time": Format.time(follow.train?.nextEta?.ms, tz: Format.zone(country: op?.country), clock: app.settings.clock)])
        } ?? l10n.t("trips.notRunning")
        return HStack(spacing: Space.m) {
            OperatorBadge(op: op, size: .medium)
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(follow.label ?? l10n.t("liveMap.train", ["number": follow.trainNumber]))
                    .clack(.rowTitle).foregroundStyle(Ink.text)
                Text([op?.name, follow.trainNumber].compactMap { $0 }.joined(separator: " ")).clack(.caption).foregroundStyle(Ink.text2)
                Text(nextLine).clack(.caption).foregroundStyle(Ink.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: Space.xs) {
                HStack(spacing: Space.xs) {
                    LucideIcon(name: "eye", size: 12)
                    Text(l10n.t("trips.followingChip"))
                }
                .clack(.micro).fontWeight(.semibold).foregroundStyle(Ink.text2)
                if let train = follow.train { DelayText(delay: train.delayMin) }
            }
        }
        .padding(.vertical, Space.m)
        .padding(.horizontal, Space.l)
        .background(Surface.Pill(op: color))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }
}

/// "Did you take this train?" (brief §8.3): trips whose reports don't settle it, with a one-tap answer.
struct ReviewCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: Leg
    let onAnswer: (RideAnswer) async -> Void
    @State private var busy = false

    var body: some View {
        let dep = leg.schedDep?.ms
        VStack(alignment: .leading, spacing: Space.m) {
            Text(l10n.t("record.question")).clack(.captionUpper).foregroundStyle(Ink.text2)
            NavigationLink(value: AppRoute.trip(leg.id)) {
                Text("\([leg.operator?.name, leg.trainNumber].compactMap { $0 }.joined(separator: " ")) · \(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                    .clack(.rowTitle).foregroundStyle(Ink.text)
            }
            .buttonStyle(.plain)
            Text("\(dep.map { Format.day($0, tz: TripsLogic.tz(leg), language: app.settings.language) } ?? "") · \(l10n.t("record.why.\(leg.rideReason ?? "no_reports")"))")
                .clack(.caption).foregroundStyle(Ink.text2)
            HStack(spacing: Space.s) {
                Button(l10n.t("record.yes")) { answer(.yes) }.buttonStyle(.clack(.primary, small: true))
                Button(l10n.t("record.no")) { answer(.no) }.buttonStyle(.clack(small: true))
            }
            .disabled(busy)
        }
        .padding(.vertical, Space.l)
        .padding(.horizontal, Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card, color: Ink.accentLine)
        .padding(.vertical, Space.xs)
    }

    private func answer(_ answer: RideAnswer) {
        busy = true
        Task {
            await onAnswer(answer)
            busy = false
        }
    }
}

/// The trip just added settles into its place in the list: in from a little smaller and lower, with the one spring
/// that has a bounce (signature moment 3, polish pass 1). Only once, only for that trip; with Reduce Motion it fades in.
struct LandsWhenAdded: ViewModifier {
    let ids: [String]
    @Environment(AppModel.self) private var app
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = true

    func body(content: Content) -> some View {
        content
            .scaleEffect(landed || reduceMotion ? 1 : 0.92, anchor: .top)
            .offset(y: landed || reduceMotion ? 0 : -Space.xl)
            .opacity(landed ? 1 : 0)
            .onAppear {
                guard let id = app.justAdded, ids.contains(id) else { return }
                landed = false
                Task {
                    try? await Task.sleep(for: .milliseconds(250))
                    withMotion(.signature, reduceMotion: reduceMotion) { landed = true }
                    app.justAdded = nil
                }
            }
    }
}
