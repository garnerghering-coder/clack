//
//  JourneyScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A multi-leg journey. Under way (owner, 2026-11-01): the same screen as a single train (map, live status, stops,
/// platform, seat) for the train in focus, with the whole journey's bar on top and every train and change below; the
/// train in focus is the one you're on (or next to board) and follows you at each change, and tapping another train's
/// card puts that one in focus until you leave the screen. Before and after the trip (owner, 2026-11-07: "it just shows
/// the first leg"): the whole journey, every train on one map, the journey's numbers, then each train as a card that
/// opens that train's page.
struct JourneyScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let id: String
    @State private var journey: Journey?
    @State private var missing = false
    @State private var lastReload: Date = .distantPast
    /// The train picked by hand; nil follows the journey (the train under way, else the first).
    @State private var picked: String?
    /// The train under way or next to leave, re-worked every 30 s and on every reload; nil before and after the trip.
    @State private var current: String?
    @State private var underWay = false

    private var legs: [Leg] { TripsLogic.taken((journey?.legs ?? []).map(\.leg)) }

    private func updateCurrent() {
        let legs = legs
        let index = TripsLogic.nowLegIndex(legs, now: Date.now.timeIntervalSince1970 * 1000)
        let next = index.map { legs[$0].id } ?? legs.first?.id
        if next != current { current = next }
        let now = index != nil
        if now != underWay { underWay = now }
    }

    var body: some View {
        Group {
            if missing {
                Page {
                    BackLink(label: router.backLabel(l10n))
                    Text(l10n.t("journey.notFound")).clack(.body).foregroundStyle(Ink.text2)
                }
            } else if underWay, let focus = picked ?? current, !legs.isEmpty {
                TripDetailScreen(id: focus, journey: JourneyContext(id: id, legs: legs, select: { picked = $0 }))
                    // A new train in focus is a fresh screen (its map, its live stream, its sections).
                    .id(focus)
            } else if let journey, !legs.isEmpty {
                JourneyOverview(journey: journey, legs: legs)
            } else {
                Page { Skeleton(height: 120) }
            }
        }
        .countsScreen("journey")
        .task(id: id) {
            do {
                journey = try await app.client.journey(id)
                updateCurrent()
            } catch {
                missing = true
            }
        }
        .task(id: journey?.legs.map(\.id)) {
            while !Task.isCancelled {
                updateCurrent()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .task(id: id) {
            // A live update for one of its trains (a delay, a platform): reload, at most every 20 s, so the cards and
            // the changes recompute and the focus moves on at a change.
            for await update in app.live.updates() {
                guard journey?.legs.contains(where: { $0.id == update.legId }) == true,
                      Date.now.timeIntervalSince(lastReload) >= 20 else { continue }
                lastReload = .now
                if let fresh = try? await app.client.journey(id) {
                    journey = fresh
                    updateCurrent()
                }
            }
        }
    }
}

/// The whole journey before and after the trip: every train on one map in its operator's colour, the journey's numbers
/// (door to door, distance, the delay at the final arrival, changes and missed changes), the day as a bar, then each
/// train as a card that opens its own page, with the change rule's verdict between them.
private struct JourneyOverview: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let journey: Journey
    let legs: [Leg]

    private var geometries: [String: String] {
        Dictionary(uniqueKeysWithValues: journey.legs.compactMap { j in j.geometry.map { (j.leg.id, $0) } })
    }

    var body: some View {
        let first = legs[0], last = legs[legs.count - 1]
        let summary = TripsLogic.journeySummary(legs)
        let tz = first.origin?.tz ?? TripsLogic.tz(first)
        let geometries = geometries
        Page {
            if legs.contains(where: { geometries[$0.id] != nil }) {
                MultiRouteMapView(
                    routes: legs.compactMap { leg in
                        geometries[leg.id].map { MultiRoute(color: MapStyle.opColor(leg.operator?.brandColor, dark: scheme == .dark), geometry: $0, stops: []) }
                    },
                    // The ends and every change as a dot, from the ends of each train's line.
                    stations: legs.compactMap { leg -> MultiStation? in
                        guard let g = geometries[leg.id], let end = Polyline.decode(g).last else { return nil }
                        return MultiStation(lat: end.lat, lon: end.lon, name: leg.destination?.name ?? "", count: 1)
                    } + (geometries[first.id].flatMap { Polyline.decode($0).first }.map { [MultiStation(lat: $0.lat, lon: $0.lon, name: first.origin?.name ?? "", count: 1)] } ?? []),
                    railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel")
                )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .hairlineBorder(radius: Radius.card)
            }
            if let summary {
                Card {
                    Text(Format.longDate(summary.dep ?? first.schedDep?.ms ?? 0, tz: tz, language: app.settings.language))
                        .clack(.captionUpper).foregroundStyle(Ink.text2)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 16) {
                        Tile(label: l10n.t("journey.doorToDoor")) { Text(summary.minutes.map(Format.duration) ?? Format.unknown) }
                        Tile(label: l10n.t("journey.distance")) { Text(Format.distance(summary.distanceM, unit: app.settings.distanceUnit, language: app.settings.language)) }
                        Tile(label: l10n.t("journey.finalArrival"), sub: summary.arr.map { Format.time($0, tz: last.destination?.tz ?? tz, clock: app.settings.clock) }) {
                            if last.canceled {
                                DelayText(delay: nil, canceled: true)
                            } else if last.actualArr != nil || summary.arrivalDelayMin != nil {
                                DelayText(delay: summary.arrivalDelayMin ?? 0)
                            } else {
                                Text(last.destination?.name ?? Format.unknown)
                            }
                        }
                        Tile(
                            label: l10n.t("journey.label", count: legs.count),
                            sub: summary.missedChanges > 0 ? l10n.t("journey.missedChanges", ["n": String(summary.missedChanges)]) : nil
                        ) {
                            Text(summary.changes == 1 ? l10n.t("journey.oneChange") : l10n.t("journey.changes", ["n": String(summary.changes)]))
                        }
                    }
                }
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let now = context.date.timeIntervalSince1970 * 1000
                VStack(alignment: .leading, spacing: 12) {
                    JourneyBar(legs: legs, now: now)
                    JourneyLegs(legs: legs, now: now)
                }
            }
        }
        .screenTitle("\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
    }
}
