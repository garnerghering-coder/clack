//
//  PlannedJourneyViews.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// One change, written out with its comfort (the change rule's verdict, the same in search, a journey's page and saved
/// trips): "Change at Nässjö C: 22 min · Relaxed". Written status, no pill (DESIGN: status is written, not boxed).
struct ChangeLine: View {
    @Environment(L10n.self) private var l10n
    let station: String
    let gapMin: Int
    let comfort: ChangeComfort?
    /// The incoming train's usual lateness, already in the verdict (shown as a note).
    var typicalLateMin: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            line
            if let typical = typicalLateMin, typical > 0 {
                Text(l10n.t("change.historyNote", ["min": String(typical)])).clack(.micro).foregroundStyle(Ink.text3)
            }
        }
    }

    private var line: some View {
        let text = l10n.t("change.line", ["station": station, "min": String(gapMin)])
        // One text, so a long station name wraps as a sentence does; VoiceOver reads it without the dot.
        let word = comfort.map { l10n.t("comfort.\($0.rawValue)") }
        let line = word.map { w in
            Text(text).foregroundStyle(Ink.text2) + Text(" · ").foregroundStyle(Ink.text3) + Text(w).foregroundStyle(Self.color(comfort!)).fontWeight(.semibold)
        } ?? Text(text).foregroundStyle(Ink.text2)
        return line
            .clack(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(word.map { "\(text), \($0)" } ?? text)
    }

    static func color(_ c: ChangeComfort) -> Color {
        switch c {
        case .risky: Ink.lateInk
        case .tight: Ink.warnText
        case .normal: Ink.text2
        case .relaxed: Ink.onTimeInk
        }
    }
}

/// Timetable trains as unsaved trips (`Leg.planned`), so a search result is drawn with the saved trip's card
/// (owner, build 87: "it should use that same ui styling as a saved trip, with that line layout").
@MainActor
enum PlannedLegs {
    static func op(_ id: String?, app: AppModel) -> LegOperator? {
        id.flatMap { app.operatorsById[$0] }.map {
            LegOperator(id: $0.id, name: $0.name, shortName: $0.shortName, company: $0.company, country: $0.country, brandColor: $0.brandColor, logoPath: $0.logoPath, logoUrl: $0.logoUrl)
        }
    }

    static func legs(_ trains: [TripResult], journeyId: String, app: AppModel) -> [Leg] {
        trains.map { Leg.planned($0, operator: op($0.operatorId, app: app), journeyId: journeyId) }
    }

    /// A single train's header: the operator and number, or the route's name when the operator isn't known (user
    /// test 2026-11-07: "427 427 ?"), or "Train".
    static func title(_ r: TripResult, app: AppModel, l10n: L10n) -> String {
        let op = r.operatorId.flatMap { app.operatorsById[$0] }
        let service = Format.service(AddTrainLogic.standInName(r, op: op) ?? op?.name, r.trainNumber)
        return service.isEmpty ? l10n.t("trips.train") : service
    }
}

/// A planned journey in the results (owner, 2026-11-17: what you compare is when it leaves, when it gets there and how
/// long it takes; the route is the one you searched): `SearchResultCard` with each change and its comfort.
struct JourneyResultCard: View {
    @Environment(L10n.self) private var l10n
    let journey: PlannedJourney
    /// The stations searched: a journey from or to another station in the town says so.
    var searchedFrom: String?
    var searchedTo: String?
    var onPick: (() -> Void)?

    var body: some View {
        SearchResultCard(
            trains: journey.legs, summary: changesText, fastest: journey.fastest == true,
            searchedFrom: searchedFrom, searchedTo: searchedTo,
            speech: journey.changes.map { l10n.t("change.line", ["station": $0.name, "min": String($0.gapMin)]) + ", " + l10n.t("comfort.\($0.comfort.rawValue)") },
            onPick: onPick
        ) {
            ForEach(Array(journey.changes.enumerated()), id: \.offset) { _, c in
                ChangeLine(station: c.name, gapMin: c.gapMin, comfort: c.comfort, typicalLateMin: c.typicalLateMin)
            }
        }
    }

    private var changesText: String {
        switch journey.changes.count {
        case 0: l10n.t("journey.direct")
        case 1: l10n.t("journey.oneChange")
        default: l10n.t("journey.changes", ["n": String(journey.changes.count)])
        }
    }
}

/// One search result, a train or a journey (owner, 2026-11-17, after SJ's results). Top to bottom:
/// - the times as the headline ("06:10 – 11:28") with the length on the right;
/// - the trains drawn side by side, each later one fading in (`TrainStrip`), then the strip to scale with the waits
///   (`JourneyBar`, without its labels: the headline has them);
/// - the operators' logos and names, then direct or the changes;
/// - `details`: each change, or a train's kind and stops.
/// No route line and no date: the list is the route and the day searched. A result from or to another station in the
/// town names it.
struct SearchResultCard<Details: View>: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let trains: [TripResult]
    /// "Direct", "2 changes".
    let summary: String
    var fastest = false
    var searchedFrom: String?
    var searchedTo: String?
    /// What VoiceOver adds after the summary (the changes).
    var speech: [String] = []
    var onPick: (() -> Void)?
    @ViewBuilder var details: Details

    var body: some View {
        let legs = PlannedLegs.legs(trains, journeyId: trains.map(\.id).joined(separator: "+"), app: app)
        let first = trains[0], last = trains[trains.count - 1]
        let dep = Format.time(first.from.time, tz: first.from.tz, clock: app.settings.clock)
        let arr = Format.time(last.to.time, tz: last.to.tz, clock: app.settings.clock)
        let duration = Format.duration((last.to.time - first.from.time) / 60_000, language: l10n.language)
        let nextDay = Format.localDate(last.to.time, tz: last.to.tz) != Format.localDate(first.from.time, tz: first.from.tz)
        let services = trains.count == 1
            ? PlannedLegs.title(first, app: app, l10n: l10n)
            : Self.operatorNames(trains, app: app)
        let elsewhere = [
            searchedFrom.flatMap { $0 == first.from.stationId ? nil : l10n.t("add.fromStation", ["station": first.from.name]) },
            searchedTo.flatMap { $0 == last.to.stationId ? nil : l10n.t("add.toStation", ["station": last.to.name]) },
        ].compactMap { $0 }
        let card = VStack(alignment: .leading, spacing: Space.s) {
            // The length beside the times, or under them when both don't fit on one line (the largest text sizes).
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    times(dep: dep, arr: arr, nextDay: nextDay)
                    Spacer(minLength: Space.s)
                    Text(duration).clack(.headline).monospacedDigit().foregroundStyle(Ink.text).lineLimit(1)
                }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    times(dep: dep, arr: arr, nextDay: nextDay)
                    Text(duration).clack(.headline).monospacedDigit().foregroundStyle(Ink.text)
                }
            }
            // Nothing searched by stations (a train number): where it runs, said once.
            if searchedFrom == nil && searchedTo == nil {
                Text(verbatim: "\(first.from.name) → \(last.to.name)").clack(.rowTitle).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !elsewhere.isEmpty {
                Text(elsewhere.joined(separator: Format.separator)).clack(.caption).foregroundStyle(Ink.text2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TrainStrip(trains: trains)
                // From the card's edge, as the trains run in from off the card.
                .padding(.leading, -Space.l)
            JourneyBar(legs: legs, now: 0, showsLabels: false)
            HStack(spacing: Space.s) {
                OperatorStack(operators: legs.map(\.operator))
                Text(services).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2)
            }
            HStack(spacing: Space.s) {
                Text(summary).clack(.caption).foregroundStyle(Ink.text2)
                if fastest { Text(l10n.t("journey.fastest")).clack(.caption).fontWeight(.semibold).foregroundStyle(Ink.accentInk) }
            }
            details
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
        Group {
            if let onPick { Button(action: onPick) { card }.buttonStyle(.press) } else { card }
        }
        // One sentence for VoiceOver, not a dozen pieces.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Format.join([
            searchedFrom == nil && searchedTo == nil ? "\(first.from.name) → \(last.to.name)" : nil,
            l10n.t("add.cardLabel", ["dep": dep, "arr": arr, "duration": duration]),
            services, summary, fastest ? l10n.t("journey.fastest") : nil,
        ] + elsewhere + speech, separator: ", "))
        .accessibilityAddTraits(onPick == nil ? [] : .isButton)
    }

    /// "06:10 – 11:28", "+1" when it arrives the next day (a night train).
    private func times(dep: String, arr: String, nextDay: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xxs) {
            Text(verbatim: "\(dep) – \(arr)").clack(.bigTime).monospacedDigit().foregroundStyle(Ink.text)
                .lineLimit(1).minimumScaleFactor(0.8)
            if nextDay { Text(verbatim: "+1").clack(.caption).fontWeight(.semibold).foregroundStyle(Ink.text2) }
        }
    }

    /// "SJ + Öresundståg": each operator once, in the order ridden.
    static func operatorNames(_ trains: [TripResult], app: AppModel) -> String {
        var seen = Set<String>()
        return trains.compactMap { t -> String? in
            let name = t.operatorId.flatMap { app.operatorsById[$0]?.name } ?? AddTrainLogic.standInName(t, op: nil)
            guard let name, seen.insert(name).inserted else { return nil }
            return name
        }.joined(separator: " + ")
    }
}

/// The trains of a result drawn side by side, as on SJ's results (owner, 2026-11-17): at one scale on one rail line,
/// each in its share of the row (`TrainStripLayout`), whole when it fits and cut from the back when it doesn't. The
/// first, the one you board, is in front; each later one slides a little under the one before it, with a thin gap cut
/// out along that train's outline (as the stacked logos have), so every nose stands out on any background. The train
/// that usually runs the line, as `TrainPicture` draws it: unpainted where the type isn't known, nothing guessed.
///
/// The Trips list draws its trips the same way (owner, build 90), with each saved trip's own train type.
struct TrainStrip: View {
    @Environment(AppModel.self) private var app
    /// Each train's type and operator, the one you board first.
    private let trains: [(typeId: String?, operatorId: String?)]

    init(trains: [TripResult]) {
        self.trains = trains.map { ($0.trainType, $0.operatorId) }
    }

    init(legs: [Leg]) {
        self.trains = legs.map { ($0.trainType, $0.operatorId ?? $0.operator?.id) }
    }
    static var height: CGFloat { CGFloat(TrainStripLayout.height) }
    /// The gap around the train in front, in points.
    static let gap: CGFloat = 1.5

    private struct Drawn {
        let type: TrainType?
        let operatorId: String?
        /// At `TrainStripLayout.scale`: the drawing's own size (its canvas, in drawing units) × the scale.
        let size: CGSize
    }

    var body: some View {
        let scale = CGFloat(TrainStripLayout.scale)
        let drawn = trains.map { train -> Drawn in
            let type = train.typeId.flatMap { id in app.trainTypes.first { $0.id == id } }
            let picture = TrainArt.picture(typeId: type?.id, art: type?.art, uncertain: type?.uncertain ?? false, operatorId: train.operatorId)
            let canvas = UIImage(named: picture.asset)?.size ?? CGSize(width: 900, height: 176)
            return Drawn(type: type, operatorId: train.operatorId, size: CGSize(width: canvas.width * scale, height: canvas.height * scale))
        }
        GeometryReader { g in
            let slots = TrainStripLayout.slots(naturals: drawn.map { Double($0.size.width) }, width: Double(g.size.width))
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(drawn.indices, id: \.self) { i in
                    let slot = slots[i]
                    piece(drawn[i], width: CGFloat(slot.width))
                        .mask {
                            if i > 0 {
                                // The train in front, as it sits over this one (its nose `overlap` in from this one's
                                // rear), blurred a little so the cut reaches just past its outline.
                                let front = drawn[i - 1]
                                let frontWidth = CGFloat(slots[i - 1].width)
                                Rectangle()
                                    .overlay(alignment: .bottomLeading) {
                                        ZStack {
                                            piece(front, width: frontWidth)
                                            piece(front, width: frontWidth)
                                        }
                                        .blur(radius: Self.gap)
                                        .offset(x: CGFloat(slot.overlap) - frontWidth)
                                        .blendMode(.destinationOut)
                                    }
                                    .compositingGroup()
                            } else {
                                Rectangle()
                            }
                        }
                        // Each later train fades in from its rear, from under the nose in front to full strength about
                        // halfway along what shows of it, as on SJ's (owner, 2026-11-17: "more drastic"). It sits
                        // behind, so the noses in front stay crisp.
                        .mask {
                            if i > 0 {
                                LinearGradient(stops: [
                                    .init(color: .clear, location: 0),
                                    .init(color: .black.opacity(0.15), location: Self.fadeStart(slot)), // design-lint: allow a mask's opacity, not a colour shown
                                    .init(color: .black, location: Self.fadeEnd), // design-lint: allow a mask's opacity, not a colour shown
                                ], startPoint: .leading, endPoint: .trailing) // design-lint: allow a mask's opacity, not a colour shown
                            } else {
                                Rectangle()
                            }
                        }
                        .padding(.leading, -CGFloat(slot.overlap))
                        .zIndex(Double(drawn.count - i))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: Self.height)
        .accessibilityHidden(true)
    }

    /// Where a later train's fade is at full strength, as a share of its width.
    static let fadeEnd: Double = 0.55

    /// Where the train in front's nose ends over this one: the fade is still faint there.
    static func fadeStart(_ slot: TrainStripLayout.Slot) -> Double {
        min(fadeEnd - 0.05, slot.overlap / max(1, slot.width))
    }

    /// One train at the strip's scale, cut from the back to `width` (its nose kept).
    private func piece(_ d: Drawn, width: CGFloat) -> some View {
        TrainPicture(type: d.type, operatorId: d.operatorId, height: d.size.height)
            .frame(width: d.size.width, height: d.size.height)
            .frame(width: width, height: d.size.height, alignment: .trailing)
            .clipped()
    }
}

/// A planned journey opened from the results, laid out exactly as a saved journey is in Trips (JourneyScreen): the
/// summary, the map, the trains on the rail with the change cards between them, then Add to trips (primary) and Follow
/// (owner, 2026-10-28). The trains are shown as unsaved trips (`Leg.planned`); nothing is saved until asked.
struct PlannedJourneyStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let journey: PlannedJourney
    let onBack: () -> Void
    let onSaved: (LegDetail) -> Void
    @State private var routes: [MultiRoute] = []
    /// Metres each train rides, from its geometry, once loaded.
    @State private var distances: [Int: Double] = [:]
    @State private var saving = false
    @State private var followed = false
    /// One journey group for every save of this journey, retries included.
    @State private var group = UUID().uuidString
    @Environment(Toaster.self) private var toaster
    @State private var dupes: [Int] = []
    /// The trains saved by the first try when some were already there, for "Keep what I have".
    @State private var savedSoFar: LegDetail?
    @State private var error: String?
    /// Why saving failed (the phone offline, or the server), for the banner's words.
    @State private var failure: APIError.Kind?

    /// The trains as unsaved trips, with the planner's tier and country so the change cards agree with it.
    private var legs: [Leg] {
        journey.legs.enumerated().map { i, r in
            Leg.planned(
                r, operator: PlannedLegs.op(r.operatorId, app: app), journeyId: journey.id,
                originTier: i > 0 ? (journey.changes.indices.contains(i - 1) ? journey.changes[i - 1].tier : nil) : nil,
                country: journey.legCountries.flatMap { $0.indices.contains(i) ? $0[i] : nil },
                distanceM: distances[i]
            )
        }
    }

    var body: some View {
        let legs = legs
        let first = legs[0], last = legs[legs.count - 1]
        Button(action: onBack) {
            HStack(spacing: Space.s) {
                LucideIcon(name: "arrow-left", size: 18)
                Text(l10n.t("add.back"))
            }
        }
        .buttonStyle(LinkButtonStyle())
        Text("\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
            .clack(.detailRoute).foregroundStyle(Ink.text)
            .fixedSize(horizontal: false, vertical: true)
        Text(Format.longDate(journey.dep, tz: first.origin?.tz ?? "Europe/Stockholm", language: app.settings.language))
            .clack(.body).foregroundStyle(Ink.text2)
        HStack(spacing: Space.m) {
            Tile(label: l10n.t("journey.doorToDoor"), value: Format.duration(Double(journey.durationMin), language: l10n.language))
            Tile(label: l10n.t("passport.trains"), value: String(legs.count))
            Tile(label: l10n.t("detail.distance"), value: distances.count == legs.count
                 ? Format.distance(distances.values.reduce(0, +), unit: app.settings.distanceUnit, language: app.settings.language) : Format.unknown)
        }
        MultiRouteMapView(routes: routes, stations: [], railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel"))
            .frame(height: 240)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        JourneyTimeline(legs: legs, now: 0, scheme: scheme) { leg in
            LegRow(leg: leg, flat: true, linked: false)
        } change: { a, b in
            ConnectionCard(a: a, b: b, compact: true)
        }
        // Already there: the choice is made here, as on the one-train step, not by tapping the same button again (run
        // 2: it stayed yellow after the notice and a second tap quietly added a copy).
        if !dupes.isEmpty {
            Banner(kind: .warn) {
                Text(l10n.t("add.duplicate"))
                HStack(spacing: Space.s) {
                    Button(l10n.t("add.addAnyway")) { Task { await save(force: true) } }.buttonStyle(.clack(.primary, small: true)).disabled(saving)
                    Button(l10n.t("add.cancel")) {
                        if let savedSoFar { onSaved(savedSoFar) } else { dupes = [] }
                    }
                    .buttonStyle(.clack(small: true))
                }
            }
        }
        if error != nil { Banner(kind: .error) { Text(FailureText.line(l10n.t("add.saveFailed"), failure, app: app, l10n: l10n)) } }
        let ahead = journey.arr > Date.now.timeIntervalSince1970 * 1000
        Color.clear.frame(height: 0)
            .sheetAction(l10n.t("journey.addToTrips"), enabled: !saving && dupes.isEmpty) { Task { await save(force: false) } }
        // Following is for a train still to run; and the two are told apart in a line (user test 2026-11-07: six
        // testers asked what the difference was, and Follow was offered on a train from 2023).
        if ahead {
            Button(followed ? l10n.t("journey.following") : l10n.t("journey.follow")) { Task { await follow() } }
                .buttonStyle(.clack(wide: true))
                .disabled(followed)
        }
        Text(l10n.t(ahead ? "journey.addOrFollowNote" : "journey.addNote")).clack(.caption).foregroundStyle(Ink.text2)
            .fixedSize(horizontal: false, vertical: true)
            .task { await loadRoutes() }
    }

    /// Each train's ridden route (its stops and geometry), drawn in its operator's colour. The trains are fetched
    /// together, not one after another (polish pass 1).
    private func loadRoutes() async {
        let client = app.client
        let fetched = await withTaskGroup(of: (Int, TimetableTrip?, TripGeometry?).self) { group in
            for (i, leg) in journey.legs.enumerated() {
                group.addTask {
                    async let geo = try? client.timetableTripGeometry(leg.key, date: leg.serviceDate)
                    let trip = try? await client.timetableTrip(leg.key, date: leg.serviceDate)
                    return (i, trip, await geo)
                }
            }
            var all: [(Int, TimetableTrip?, TripGeometry?)] = []
            for await item in group { all.append(item) }
            return all.sorted { $0.0 < $1.0 }
        }
        var out: [MultiRoute] = []
        for (i, trip, geometry) in fetched {
            guard let trip else { continue }
            let leg = journey.legs[i]
            if let segments = geometry?.segments {
                distances[i] = segments.filter { $0.fromSeq >= leg.from.seq && $0.toSeq <= leg.to.seq }.reduce(0) { $0 + $1.lengthM }
            }
            let map = AddTrainLogic.mapRoute(stops: trip.stops, geometry: geometry, fromSeq: leg.from.seq, toSeq: leg.to.seq)
            let color = MapStyle.opColor(leg.operatorId.flatMap { app.operatorsById[$0] }?.brandColor, dark: scheme == .dark)
            out.append(MultiRoute(color: color, geometry: nil, stops: map.route))
        }
        routes = out
    }

    /// All the journey's trains, as one journey (a shared group), so a long change can't split it.
    private func save(force: Bool) async {
        saving = true
        error = nil
        // The same group on every try, so "Add anyway" puts the forced train in the journey with the others
        // (polish pass 1: a new id each time split it off).
        let group = self.group
        var already: [Int] = []
        var last: LegDetail?
        do {
            for (i, leg) in journey.legs.enumerated() {
                if force && !dupes.isEmpty && !dupes.contains(i) { continue }
                do {
                    last = try await app.client.createLeg(CreateLegBody(tripKey: leg.key, serviceDate: leg.serviceDate, fromSeq: leg.from.seq, toSeq: leg.to.seq, force: force ? true : nil, group: group))
                } catch let apiError as APIError where apiError.status == 409 {
                    already.append(i)
                }
            }
            if !already.isEmpty && !force {
                dupes = already
                savedSoFar = last
            } else if let last {
                onSaved(last)
            }
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
            self.failure = FailureText.kind(error)
        }
        saving = false
    }

    /// Follows every train of the journey as one journey (Following shows it with its trains inside). The button
    /// says Following at once; if the server refuses, it goes back and says so (polish pass 1: it said Following even
    /// when nothing was saved).
    private func follow() async {
        let group = UUID().uuidString
        let first = journey.legs[0], last = journey.legs[journey.legs.count - 1]
        let name = "\(first.from.name) → \(last.to.name)"
        followed = true
        do {
            for leg in journey.legs {
                guard let number = leg.trainNumber else { continue }
                try await app.client.follow(FollowBody(
                    trainNumber: number, serviceDate: leg.serviceDate, operatorId: leg.operatorId,
                    label: "\(leg.from.name) → \(leg.to.name)", journeyGroup: group, journeyLabel: name))
            }
        } catch {
            followed = false
            toaster.show(l10n.t("journey.followFailed"), isError: true)
        }
    }
}
