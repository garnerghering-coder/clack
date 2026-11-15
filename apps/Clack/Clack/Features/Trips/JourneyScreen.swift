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
    @State private var failed = false
    @State private var lastReload: Date = .distantPast
    /// The train picked by hand; nil follows the journey (the train under way, else the first).
    @State private var picked: String?
    /// The train under way or next to leave, re-worked every 30 s and on every reload; nil before and after the trip.
    @State private var current: String?
    @State private var underWay = false

    private var legs: [Leg] { TripsLogic.taken((journey?.legs ?? []).map(\.leg)) }

    /// Fetches the journey; only the server saying it doesn't exist (404) means "not found".
    private func reload() async {
        failed = false
        do {
            journey = try await app.client.journey(id)
            updateCurrent()
        } catch let error as APIError where error.status == 404 {
            missing = true
        } catch {
            if journey == nil { failed = true }
        }
    }

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
                JourneyOverview(journey: journey, legs: legs, onRefresh: { await reload() })
            } else if failed {
                // Not reached is said as such, with a way to try again (it said "not found", polish pass 1).
                Page { ErrorStateView(message: l10n.t("journey.loadFailed"), kind: app.connectionKind, retry: { await reload() }) }
            } else {
                Page { Skeleton(height: 240, radius: Radius.card) }
            }
        }
        .countsScreen("journey")
        .task(id: id) { await reload() }
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

/// The whole journey before and after the trip (designer, 2026-11-14: one line of numbers, then one rail): every train
/// on one map in its operator's colour, a line with the day, the time door to door, the distance, the changes and how it
/// arrived, then the journey as one vertical timeline, each train opening its own page and each change between them.
private struct JourneyOverview: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let journey: Journey
    let legs: [Leg]
    var onRefresh: () async -> Void = {}
    /// The map's lines and dots, decoded once per journey (they were decoded on every redraw).
    @State private var routes: [MultiRoute] = []
    @State private var stations: [MultiStation] = []

    var body: some View {
        let first = legs[0]
        let last = legs[legs.count - 1]
        Page {
            if !routes.isEmpty {
                MultiRouteMapView(routes: routes, stations: stations, railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel"))
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .hairlineBorder(radius: Radius.card)
            }
            // Shown, not told (owner, 2026-11-15: "walls of text"): the day, the numbers as tiles, the day as a strip,
            // then each train as a card with its drawing and big times, and each change as a chip between them.
            if let summary = TripsLogic.journeySummary(legs) {
                Text(Format.longDate(summary.dep ?? first.schedDep?.ms ?? 0, tz: first.origin?.tz ?? TripsLogic.tz(first), language: app.settings.language))
                    .clack(.caption).foregroundStyle(Ink.text2)
                tiles(summary, last: last)
            }
            TimelineView(.periodic(from: .now, by: 60)) { context in
                let now = context.date.timeIntervalSince1970 * 1000
                VStack(alignment: .leading, spacing: Space.l) {
                    JourneyBar(legs: legs, now: now)
                    JourneyLegs(legs: legs, now: now, drawings: true)
                }
            }
        }
        .refreshable { await onRefresh() }
        .screenTitle("\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
        .task(id: journey.legs.map(\.leg.id)) { decodeMap() }
    }

    /// Door to door, how far, the changes and how it arrived, as four tiles; the arrival in its delay ink.
    private func tiles(_ summary: TripsLogic.JourneySummary, last: Leg) -> some View {
        let arrival: (text: String, ink: Color)? = {
            if last.canceled { return (l10n.t("delay.cancelled"), Ink.veryLateInk) }
            guard last.actualArr != nil || summary.arrivalDelayMin != nil else { return nil }
            let delay = summary.arrivalDelayMin ?? 0
            return delay > 0 ? (Format.delay(delay), DelayBand(delayMin: delay, canceled: false).ink) : (l10n.t("delay.on_time"), Ink.onTimeInk)
        }()
        let changes = summary.missedChanges > 0
            ? l10n.t("journey.missedChanges", ["n": String(summary.missedChanges)])
            : nil
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: Space.s), GridItem(.flexible(), spacing: Space.s)], spacing: Space.s) {
            Tile(label: l10n.t("journey.tileTime"), value: summary.minutes.map { Format.duration($0, language: l10n.language) } ?? Format.unknown)
            Tile(label: l10n.t("journey.tileDistance"), value: summary.distanceM.map { Format.distance($0, unit: app.settings.distanceUnit, language: app.settings.language) } ?? Format.unknown)
            Tile(label: l10n.t("journey.tileChanges"), value: String(summary.changes), sub: changes)
            // The arrival time, and how it went in its ink once known (a dash alone said nothing).
            Tile(label: l10n.t("journey.tileArrival")) {
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(summary.arr.map { Format.time($0, tz: last.destination?.tz ?? TripsLogic.tz(last), clock: app.settings.clock) } ?? Format.unknown)
                        .foregroundStyle(Ink.text)
                    if let arrival { Text(arrival.text).clack(.caption).foregroundStyle(arrival.ink).lineLimit(1).minimumScaleFactor(0.8) }
                }
            }
        }
    }

    private func decodeMap() {
        let geometries = Dictionary(uniqueKeysWithValues: journey.legs.compactMap { j in j.geometry.map { (j.leg.id, $0) } })
        let decoded = Dictionary(uniqueKeysWithValues: geometries.map { ($0.key, Polyline.decode($0.value)) })
        routes = legs.compactMap { leg in
            geometries[leg.id].map { MultiRoute(color: MapStyle.opColor(leg.operator?.brandColor, dark: scheme == .dark), geometry: $0, stops: []) }
        }
        // The ends and every change as a dot, from the ends of each train's line.
        var dots = legs.compactMap { leg -> MultiStation? in
            guard let end = decoded[leg.id]?.last else { return nil }
            return MultiStation(lat: end.lat, lon: end.lon, name: leg.destination?.name ?? "", count: 1)
        }
        if let first = legs.first, let start = decoded[first.id]?.first {
            dots.append(MultiStation(lat: start.lat, lon: start.lon, name: first.origin?.name ?? "", count: 1))
        }
        stations = dots
    }
}
