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
        VStack(alignment: .leading, spacing: 2) {
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

/// A planned journey in the results: when it leaves and arrives, how long, how many changes, each train, each change.
struct JourneyResultCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let journey: PlannedJourney
    var onPick: (() -> Void)?

    var body: some View {
        let first = journey.legs[0], last = journey.legs[journey.legs.count - 1]
        let plus = Format.dayOffset(from: first.from.time, fromTz: first.from.tz, to: last.to.time, toTz: last.to.tz)
        let card = VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(Format.time(first.from.time, tz: first.from.tz, clock: app.settings.clock)).clack(.bigTime).foregroundStyle(Ink.text)
                Text(Format.duration(Double(journey.durationMin))).clack(.caption).foregroundStyle(Ink.text2).frame(maxWidth: .infinity)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.time(last.to.time, tz: last.to.tz, clock: app.settings.clock)).clack(.bigTime).foregroundStyle(Ink.text)
                    if plus > 0 { TimePair.plusText(plus) }
                }
            }
            .monospacedDigit()
            HStack(spacing: 8) {
                Text(changesText).clack(.chip).foregroundStyle(Ink.text2)
                if journey.fastest == true { Text(l10n.t("journey.fastest")).clack(.chip).foregroundStyle(Ink.accentInk) }
            }
            ForEach(Array(journey.legs.enumerated()), id: \.offset) { i, leg in
                let op = leg.operatorId.flatMap { app.operatorsById[$0] }
                VStack(alignment: .leading, spacing: 2) {
                    ServiceHeader(op: op, number: leg.trainNumber, size: .small, name: op == nil ? leg.routeName : nil)
                    (TimePair.text(.init(time: leg.from.time, tz: leg.from.tz), .init(time: leg.to.time, tz: leg.to.tz), clock: app.settings.clock)
                        + Text(Format.separator + "\(leg.from.name) → \(leg.to.name)"))
                        .clack(.caption).foregroundStyle(Ink.text2).lineLimit(2)
                }
                if i < journey.changes.count {
                    let c = journey.changes[i]
                    ChangeLine(station: c.name, gapMin: c.gapMin, comfort: c.comfort, typicalLateMin: c.typicalLateMin)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        Group {
            if let onPick { Button(action: onPick) { card }.buttonStyle(.plain) } else { card }
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
    @State private var dupes: [Int] = []
    @State private var error: String?

    /// The trains as unsaved trips, with the planner's tier and country so the change cards agree with it.
    private var legs: [Leg] {
        journey.legs.enumerated().map { i, r in
            let op = r.operatorId.flatMap { app.operatorsById[$0] }.map {
                LegOperator(id: $0.id, name: $0.name, shortName: $0.shortName, company: $0.company, country: $0.country, brandColor: $0.brandColor, logoPath: $0.logoPath, logoUrl: $0.logoUrl)
            }
            return Leg.planned(
                r, operator: op, journeyId: journey.id,
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
            HStack(spacing: 8) {
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
        HStack(spacing: 12) {
            Tile(label: l10n.t("journey.doorToDoor"), value: Format.duration(Double(journey.durationMin)))
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
        if !dupes.isEmpty { Banner(kind: .warn) { Text(l10n.t("add.duplicate")) } }
        if let error { Banner(kind: .error) { Text(l10n.t("add.saveError", ["message": error])) } }
        Button(l10n.t("journey.addToTrips")) { Task { await save(force: !dupes.isEmpty) } }
            .buttonStyle(.clack(.primary, wide: true))
            .disabled(saving)
            .padding(.top, 8)
        Button(followed ? l10n.t("journey.following") : l10n.t("journey.follow")) { Task { await follow() } }
            .buttonStyle(.clack(wide: true))
            .disabled(followed)
            .task { await loadRoutes() }
    }

    /// Each train's ridden route (its stops and geometry), drawn in its operator's colour.
    private func loadRoutes() async {
        var out: [MultiRoute] = []
        for (i, leg) in journey.legs.enumerated() {
            async let geo = try? app.client.timetableTripGeometry(leg.key, date: leg.serviceDate)
            guard let trip = try? await app.client.timetableTrip(leg.key, date: leg.serviceDate) else { continue }
            let geometry = await geo
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
        let group = UUID().uuidString
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
            } else if let last {
                onSaved(last)
            }
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        saving = false
    }

    /// Follows every train of the journey as one journey (Following shows it with its trains inside).
    private func follow() async {
        let group = UUID().uuidString
        let first = journey.legs[0], last = journey.legs[journey.legs.count - 1]
        let name = "\(first.from.name) → \(last.to.name)"
        for leg in journey.legs {
            guard let number = leg.trainNumber else { continue }
            try? await app.client.follow(FollowBody(
                trainNumber: number, serviceDate: leg.serviceDate, operatorId: leg.operatorId,
                label: "\(leg.from.name) → \(leg.to.name)", journeyGroup: group, journeyLabel: name))
        }
        followed = true
    }
}
