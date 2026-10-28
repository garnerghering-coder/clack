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

    var body: some View {
        let text = l10n.t("change.line", ["station": station, "min": String(gapMin)])
        HStack(spacing: 4) {
            Text(text).foregroundStyle(Ink.text2)
            if let comfort {
                Text("·").foregroundStyle(Ink.text3)
                Text(l10n.t("comfort.\(comfort.rawValue)")).foregroundStyle(Self.color(comfort)).fontWeight(.semibold)
            }
        }
        .clack(.caption)
        .accessibilityElement(children: .combine)
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
                    ChangeLine(station: c.name, gapMin: c.gapMin, comfort: c.comfort)
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

/// A planned journey opened from the results: its route on the map, each train with its times, each change with its
/// comfort, and the two actions: Add to trips (primary) and Follow (secondary). Nothing is saved until asked.
struct PlannedJourneyStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let journey: PlannedJourney
    let onBack: () -> Void
    let onSaved: (LegDetail) -> Void
    @State private var routes: [MultiRoute] = []
    @State private var saving = false
    @State private var followed = false
    @State private var dupes: [Int] = []
    @State private var error: String?
    @State private var mapStation: MapStation?

    private struct MapStation: Identifiable { let id: String }

    var body: some View {
        let first = journey.legs[0], last = journey.legs[journey.legs.count - 1]
        Button(action: onBack) {
            HStack(spacing: 8) {
                LucideIcon(name: "arrow-left", size: 18)
                Text(l10n.t("add.back"))
            }
        }
        .buttonStyle(LinkButtonStyle())
        Text("\(first.from.name) → \(last.to.name)").clack(.headline).foregroundStyle(Ink.text)
        Text("\(Format.duration(Double(journey.durationMin)))\(Format.separator)\(journey.changes.isEmpty ? l10n.t("journey.direct") : journey.changes.count == 1 ? l10n.t("journey.oneChange") : l10n.t("journey.changes", ["n": String(journey.changes.count)]))")
            .clack(.caption).foregroundStyle(Ink.text2)
        MultiRouteMapView(routes: routes, stations: [], railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel"))
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(journey.legs.enumerated()), id: \.offset) { i, leg in
                legCard(leg)
                if i < journey.changes.count {
                    let c = journey.changes[i]
                    HStack(spacing: 8) {
                        ChangeLine(station: c.name, gapMin: c.gapMin, comfort: c.comfort)
                        Spacer(minLength: 0)
                        Button(l10n.t("journey.stationMap")) { mapStation = MapStation(id: c.stationId) }
                            .buttonStyle(LinkButtonStyle())
                    }
                }
            }
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
            .sheet(item: $mapStation) { s in
                NavigationStack { StationMapScreen(link: StationMapLink(stationId: s.id)) }
            }
    }

    private func legCard(_ leg: TripResult) -> some View {
        let op = leg.operatorId.flatMap { app.operatorsById[$0] }
        return VStack(alignment: .leading, spacing: 4) {
            ServiceHeader(op: op, number: leg.trainNumber, size: .medium, category: leg.product, name: op == nil ? leg.routeName : nil)
            (TimePair.text(.init(time: leg.from.time, tz: leg.from.tz), .init(time: leg.to.time, tz: leg.to.tz), clock: app.settings.clock)
                + Text(Format.separator + "\(leg.from.name) → \(leg.to.name)"))
                .clack(.body).foregroundStyle(Ink.text)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    /// Each train's ridden route (its stops and geometry), drawn in its operator's colour.
    private func loadRoutes() async {
        var out: [MultiRoute] = []
        for leg in journey.legs {
            async let geo = try? app.client.timetableTripGeometry(leg.key, date: leg.serviceDate)
            guard let trip = try? await app.client.timetableTrip(leg.key, date: leg.serviceDate) else { continue }
            let map = AddTrainLogic.mapRoute(stops: trip.stops, geometry: await geo, fromSeq: leg.from.seq, toSeq: leg.to.seq)
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
