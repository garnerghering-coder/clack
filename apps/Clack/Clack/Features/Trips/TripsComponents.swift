//
//  TripsComponents.swift
//  Clack
//

import SwiftUI

/// The text of a trip's times, "07:14 – 10:30 +1", as one run so it wraps with the line around it. A time that
/// differs from the timetable by a minute or more shows the timetabled one struck through, and the new one in the
/// accent colour (SplitFlap.tsx `FlapTime`, text form).
enum TimesText {
    static func attributed(_ leg: Leg, clock: ClockFormat) -> AttributedString {
        let x = TripsLogic.expected(leg)
        let destTz = leg.destination?.tz ?? TripsLogic.tz(leg)
        var out = part(x.dep, sched: leg.schedDep?.ms, tz: TripsLogic.tz(leg), clock: clock)
        var dash = AttributedString(" – ")
        dash.foregroundColor = Ink.text3
        out += dash
        out += part(x.arr, sched: leg.schedArr?.ms, tz: destTz, clock: clock)
        if let dep = leg.schedDep?.ms, let arr = leg.schedArr?.ms {
            let plus = Format.dayOffset(from: dep, fromTz: TripsLogic.tz(leg), to: arr, toTz: destTz)
            if plus > 0 {
                var sup = AttributedString("+\(plus)")
                sup.baselineOffset = 5
                sup.font = ClackFont.inter(9, .semibold)
                sup.foregroundColor = Ink.text2
                out += sup
            }
        }
        return out
    }

    private static func part(_ time: Double?, sched: Double?, tz: String, clock: ClockFormat) -> AttributedString {
        guard let time else {
            var dash = AttributedString("—")
            dash.foregroundColor = Ink.text2
            return dash
        }
        let changed = sched.map { floor($0 / 60_000) != floor(time / 60_000) } ?? false
        var out = AttributedString()
        if changed, let sched {
            var old = AttributedString(Format.time(sched, tz: tz, clock: clock) + " ")
            old.strikethroughStyle = .single
            old.foregroundColor = Ink.text3
            out += old
        }
        var new = AttributedString(Format.time(time, tz: tz, clock: clock))
        if changed {
            new.foregroundColor = Ink.accentInk
            new.font = ClackFont.inter(13, .bold)
        }
        out += new
        return out
    }
}

/// Departure and arrival on flip cards: the featured trip's times (`Times size="lg" intro`).
struct FlapTimes: View {
    @Environment(AppModel.self) private var app
    let leg: Leg
    var style: FlapTime.Style = .lg
    var intro = false

    var body: some View {
        let x = TripsLogic.expected(leg)
        let dep = leg.schedDep?.ms
        let arr = leg.schedArr?.ms
        let plus = (dep != nil && arr != nil && leg.destination != nil)
            ? Format.dayOffset(from: dep!, fromTz: TripsLogic.tz(leg), to: arr!, toTz: leg.destination!.tz) : 0
        // Wraps onto a second line when both struck and new times don't fit, as the web's inline times do.
        FlowLayout(spacing: 6, lineSpacing: 2) {
            FlapTime(time: x.dep, sched: dep, tz: TripsLogic.tz(leg), clock: app.settings.clock, style: style, intro: intro)
            Text("–").foregroundStyle(Ink.text3)
            FlapTime(
                time: x.arr, sched: arr, tz: leg.destination?.tz ?? TripsLogic.tz(leg), clock: app.settings.clock, style: style, intro: intro
            )
            if plus > 0 {
                Text("+\(plus)").clack(.captionUpper).foregroundStyle(Ink.text2).baselineOffset(10)
            }
        }
        .clack(.heroTimes)
    }
}

/// "Departs in 2h 5m", "Boarding", "Live now", "Arrived", "Cancelled" (countdown() in TripsPage.tsx).
extension TripsLogic {
    @MainActor
    static func countdown(_ l10n: L10n, _ leg: Leg, now: Double) -> String {
        let dep = LiveRules.expectedDeparture(leg)
        if leg.canceled || leg.live?.status == .cancelled { return l10n.t("status.cancelled") }
        if now >= arrivalOf(leg) { return l10n.t("trips.arrived") }
        // The live state knows where the train is: on its way to your stop, at it, or yet to be 30 minutes from leaving.
        let fresh = leg.live.map { LiveRules.isFresh($0, now: now) } ?? false
        if fresh, let status = leg.live?.status {
            if status == .approaching { return l10n.t("trips.approaching") }
            if status == .boarding { return l10n.t("trips.boarding") }
        }
        if now >= dep { return l10n.t("trips.liveNow") }
        // With no live data (or none fresh) the timetable, moved by the delay known so far, decides.
        if !fresh, dep - now <= 30 * 60_000 { return l10n.t("trips.boarding") }
        let mins = Int(((dep - now) / 60_000).rounded())
        let d = mins / 1440
        let h = (mins % 1440) / 60
        let m = mins % 60
        return l10n.t("trips.departsIn", ["time": d > 0 ? "\(d)d \(h)h" : h > 0 ? "\(h)h \(m)m" : "\(m) min"])
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

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date.timeIntervalSince1970 * 1000
            NavigationLink(value: AppRoute.trip(leg.id)) { content(now: now) }
                .buttonStyle(.plain)
        }
    }

    private func content(now: Double) -> some View {
        let op = operatorColor(leg.operator?.brandColor, scheme: scheme)
        let service = [leg.operator?.name, leg.trainNumber].compactMap { $0 }.joined(separator: " ")
        let meta2 = [
            service.isEmpty ? nil : service,
            upcoming ? leg.depPlatform.map { l10n.t("trips.platform", ["platform": $0]) } : nil,
        ].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .center, spacing: 12) {
            OperatorBadge(op: leg.operator, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                if upcoming {
                    Text(TripsLogic.countdown(l10n, leg, now: now))
                        .font(ClackFont.inter(12, .bold)).tracking(0.24).foregroundStyle(Ink.accentInk)
                }
                Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                    .clack(.rowTitle).fontWeight(.bold).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                metaLine
                if !meta2.isEmpty { Text(meta2).clack(.caption).foregroundStyle(Ink.text2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            side
        }
        .padding(.vertical, flat ? 8 : 12)
        .padding(.horizontal, flat ? 0 : 14)
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
        var text = AttributedString()
        if let dep { text += AttributedString(Format.day(dep, tz: TripsLogic.tz(leg), language: app.settings.language) + " · ") }
        text += TimesText.attributed(leg, clock: app.settings.clock)
        if let dep, let arr = leg.schedArr?.ms { text += AttributedString(" · " + Format.duration((arr - dep) / 60_000)) }
        return Text(text).clack(.caption).foregroundStyle(Ink.text2).monospacedDigit()
    }

    private var side: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if leg.ride == .review { Chip(text: l10n.t("record.needsCheck"), tint: Ink.warnText) }
            if leg.ride == .notTaken { Chip(text: l10n.t("record.notTaken")) }
            if upcoming {
                if leg.depDelayMin != nil { DelayText(delay: leg.depDelayMin, canceled: leg.canceled) }
            } else {
                DelayText(delay: (leg.dataQuality == .scheduledOnly && leg.status == .planned) ? nil : leg.arrDelayMin, canceled: leg.canceled)
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
                ? l10n.t("connection.tracks", ["from": a.arrPlatform ?? "?", "to": b.depPlatform ?? "?"]) : nil
            let tz = a.destination?.tz ?? "Europe/Stockholm"
            let atRisk = min < 0
            let body = HStack(spacing: 12) {
                DashedLine(dash: 3, gap: 4).frame(minHeight: 34)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        LucideIcon(name: "clock", size: 14)
                        if atRisk {
                            Text(l10n.t("trips.layoverMissed", ["station": station]))
                        } else {
                            if let schedMin, schedMin != min {
                                Text(Format.duration(Double(schedMin))).strikethrough().foregroundStyle(Ink.text3).fontWeight(.medium)
                            }
                            Text(Format.duration(Double(min)))
                                .foregroundStyle(schedMin != nil && schedMin != min ? Ink.accentInk : Ink.text2)
                            + Text(" " + l10n.t("trips.layoverAt", ["station": station]))
                        }
                    }
                    .clack(.banner).fontWeight(.semibold)
                    HStack(spacing: 6) {
                        FlapTime(time: arrival, sched: schedA, tz: tz, clock: app.settings.clock)
                        Text("→")
                        FlapTime(time: departure, sched: schedB, tz: tz, clock: app.settings.clock)
                        if let tracks { Text("· \(tracks)") }
                    }
                    .clack(.caption)
                    if linked {
                        HStack(spacing: 4) {
                            LucideIcon(name: "map", size: 14)
                            Text(l10n.t("trips.layoverMap") + " ›")
                        }
                        .clack(.caption).foregroundStyle(Ink.accentInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .foregroundStyle(atRisk ? Ink.veryLate : Ink.text2)
            .padding(.leading, 28)
            .padding(.trailing, 12)
            .padding(.vertical, 4)
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

    var body: some View {
        let t = TripsLogic.transfer(from: prev, to: next)
        var text = l10n.t("journey.transfer", ["min": String(t.planned), "station": t.station])
        if let actual = t.actual, actual != t.planned, !t.missed { text += " · " + l10n.t("journey.actually", ["min": String(actual)]) }
        if t.missed { text += " · " + l10n.t("journey.missed") } else if t.tight { text += " · " + l10n.t("journey.tight") }
        return HStack(spacing: 10) {
            DashedLine(dash: 3, gap: 3).frame(height: 22)
            Text(text).clack(.caption).foregroundStyle(t.missed ? Ink.veryLate : (t.tight ? Ink.slight : Ink.text2))
        }
        .padding(.vertical, 2)
        .padding(.leading, 17)
    }
}

/// A multi-leg journey in the Trips list. Legs in travel order; one card, with each train's operator colour glowing
/// beside its own row.
struct JourneyCard: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let legs: [Leg]

    var body: some View {
        let first = legs[0]
        let last = legs[legs.count - 1]
        VStack(alignment: .leading, spacing: 0) {
            if let id = first.journeyId {
                NavigationLink(value: AppRoute.journey(id)) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("journey.label", count: legs.count)).clack(.captionUpper).foregroundStyle(Ink.text2)
                        Text("\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
                            .clack(.rowTitle).foregroundStyle(Ink.text)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
            }
            ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                if index > 0 { TransferChip(prev: legs[index - 1], next: leg) }
                LegRow(leg: leg, flat: true)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
        .padding(.horizontal, 14)
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
        .padding(.bottom, 10)
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
        VStack(spacing: 10) {
            DottedLine(endDots: true)
            Text(l10n.t("trips.whereNext")).clack(.headline).foregroundStyle(Ink.text)
            Text(l10n.t("trips.whereNextBody")).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
            EmptyActions()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 18)
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
        HStack(spacing: 10) {
            Button {
                router.openAdd()
            } label: {
                HStack(spacing: 8) {
                    LucideIcon(name: "plus", size: 18)
                    Text(l10n.t("trips.findTrain"))
                }
            }
            .buttonStyle(.clack(.primary))
            Button {
                router.tab = .explore
            } label: {
                HStack(spacing: 8) {
                    LucideIcon(name: "compass", size: 18)
                    Text(l10n.t("trips.exploreTrains"))
                }
            }
            .buttonStyle(.clack())
        }
        .padding(.top, 4)
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
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t("trips.following")).clack(.monthHeader).foregroundStyle(Ink.text2).padding(.top, 2)
                ForEach(follows, id: \.self) { follow in
                    let op = follow.operatorId.flatMap { app.operatorsById[$0] }
                    Button {
                        router.openTrain(number: follow.trainNumber, date: follow.serviceDate)
                    } label: {
                        row(follow, op: op)
                    }
                    .buttonStyle(.plain)
                }
                Text(l10n.t("trips.followingNote")).clack(.caption).foregroundStyle(Ink.text2)
            }
            .padding(.top, 2)
        }
    }

    private func row(_ follow: Follow, op: Operator?) -> some View {
        let color = operatorColor(op?.brandColor, scheme: scheme)
        let nextLine = follow.train?.next.map {
            l10n.t("live.nextStop", ["name": $0, "time": Format.time(follow.train?.nextEta?.ms, tz: "Europe/Stockholm", clock: app.settings.clock)])
        } ?? l10n.t("trips.notRunning")
        return HStack(spacing: 12) {
            OperatorBadge(op: op, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(follow.label ?? l10n.t("liveMap.train", ["number": follow.trainNumber]))
                    .clack(.rowTitle).fontWeight(.bold).foregroundStyle(Ink.text)
                Text([op?.name, follow.trainNumber].compactMap { $0 }.joined(separator: " ")).clack(.caption).foregroundStyle(Ink.text2)
                Text(nextLine).clack(.caption).foregroundStyle(Ink.text2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 4) {
                    LucideIcon(name: "eye", size: 12)
                    Text(l10n.t("trips.followingChip"))
                }
                .font(ClackFont.inter(11, .semibold)).foregroundStyle(Ink.text2)
                if let train = follow.train { DelayText(delay: train.delayMin) }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
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
        VStack(alignment: .leading, spacing: 10) {
            Text(l10n.t("record.question")).clack(.captionUpper).foregroundStyle(Ink.text2)
            NavigationLink(value: AppRoute.trip(leg.id)) {
                Text("\([leg.operator?.name, leg.trainNumber].compactMap { $0 }.joined(separator: " ")) · \(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                    .clack(.rowTitle).foregroundStyle(Ink.text)
            }
            .buttonStyle(.plain)
            Text("\(dep.map { Format.day($0, tz: TripsLogic.tz(leg), language: app.settings.language) } ?? "") · \(l10n.t("record.why.\(leg.rideReason ?? "no_reports")"))")
                .clack(.caption).foregroundStyle(Ink.text2)
            HStack(spacing: 8) {
                Button(l10n.t("record.yes")) { answer(.yes) }.buttonStyle(.clack(.primary, small: true))
                Button(l10n.t("record.no")) { answer(.no) }.buttonStyle(.clack(small: true))
            }
            .disabled(busy)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Surface.Lit())
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card, color: Ink.accentLine)
        .padding(.vertical, 4)
    }

    private func answer(_ answer: RideAnswer) {
        busy = true
        Task {
            await onAnswer(answer)
            busy = false
        }
    }
}
