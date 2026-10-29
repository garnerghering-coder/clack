//
//  JourneyScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A multi-leg journey door to door: a summary, a combined map and the legs joined by connections (DESIGN §7).
struct JourneyScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let id: String
    @State private var journey: Journey?
    @State private var missing = false
    @State private var lastReload: Date = .distantPast
    @State private var sharing = JourneyShare()
    @Environment(\.colorScheme) private var scheme
    /// The leg in focus while the journey is under way or about to start, and its live experience.
    @State private var nowLegId: String?
    @State private var nowModel = JourneyNowModel()

    private var wholeMap: some View {
        MultiRouteMapView(
            routes: (journey?.legs ?? []).filter { $0.leg.ride != .notTaken }.map {
                MultiRoute(color: MapStyle.opColor($0.leg.operator?.brandColor, dark: scheme == .dark), geometry: $0.geometry, stops: [])
            },
            stations: [], railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel")
        )
        .frame(height: 240)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    /// Which leg the "Now" section is about, re-worked every 30 s and whenever the journey reloads.
    private func updateNowLeg() {
        let legs = TripsLogic.taken((journey?.legs ?? []).map(\.leg))
        let index = TripsLogic.nowLegIndex(legs, now: Date.now.timeIntervalSince1970 * 1000)
        let next = index.map { legs[$0].id }
        if next != nowLegId { nowLegId = next }
    }

    var body: some View {
        Page {
            if missing {
                Text(l10n.t("journey.notFound")).clack(.body).foregroundStyle(Ink.text2)
            } else if let legs = journey.map({ TripsLogic.taken($0.legs.map(\.leg)) }), let first = legs.first, let last = legs.last {
                let dep = first.actualDep?.ms ?? first.schedDep?.ms ?? 0
                let arr = last.actualArr?.ms ?? last.schedArr?.ms ?? 0
                let distance = legs.reduce(0) { $0 + ($1.distanceM ?? 0) }
                Text("\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
                    .clack(.detailRoute).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Format.longDate(dep, tz: first.origin?.tz ?? "Europe/Stockholm", language: app.settings.language))
                    .clack(.body).foregroundStyle(Ink.text2)
                HStack(spacing: 12) {
                    Tile(label: l10n.t("journey.doorToDoor"), value: Format.duration((arr - dep) / 60_000))
                    Tile(label: l10n.t("passport.trains"), value: String(legs.count))
                    Tile(label: l10n.t("detail.distance"), value: Format.distance(distance, unit: app.settings.distanceUnit, language: app.settings.language))
                }
                // "Now": the leg running (or next to leave) with its live card; its map replaces the whole-journey
                // one while the train is under way.
                Ticking(every: 30) { now in
                    if let detail = nowModel.detail, nowLegId != nil {
                        JourneyNowSection(model: nowModel, legs: legs, now: now)
                        if JourneyNowMap.isUnderway(detail, live: nowModel.live, now: now, offline: app.isOffline) {
                            JourneyNowMap(detail: detail, live: nowModel.live, now: now)
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                                .hairlineBorder(radius: Radius.card)
                        } else {
                            wholeMap
                        }
                    } else {
                        wholeMap
                    }
                }
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    JourneyTimeline(legs: legs, now: context.date.timeIntervalSince1970 * 1000, scheme: scheme) { leg in
                        LegRow(leg: leg, flat: true)
                    } change: { a, b in
                        if a.destination?.id == b.origin?.id {
                            ConnectionCard(a: a, b: b, compact: true)
                        } else {
                            TransferChip(prev: a, next: b, plain: true)
                        }
                    }
                }
            } else {
                Skeleton(height: 120)
            }
        }
        .plainBar()
        .countsScreen("journey")
        .journeyShareSheet(sharing, l10n: l10n)
        .task(id: id) { await sharing.refresh(app, journeyId: id, legId: id) }
        .toolbar {
            // Top right, where the back arrow's twin goes.
            if let legs = journey.map({ TripsLogic.taken($0.legs.map(\.leg)) }), let first = legs.first, let last = legs.last {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareControl(share: sharing, journeyId: id, legId: first.id, from: first.origin?.name ?? "", to: last.destination?.name ?? "")
                }
            }
        }
        .task(id: nowLegId) { await nowModel.follow(nowLegId, app: app) }
        .task(id: journey?.legs.map(\.id)) {
            while !Task.isCancelled {
                updateNowLeg()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .task(id: id) {
            do {
                journey = try await app.client.journey(id)
            } catch {
                missing = true
            }
        }
        .task(id: id) {
            // A live update for one of its trains (a delay, a platform): reload, at most every 20 s, so the connections
            // recompute.
            for await update in app.live.updates() {
                guard journey?.legs.contains(where: { $0.id == update.legId }) == true,
                      Date.now.timeIntervalSince(lastReload) >= 20 else { continue }
                lastReload = .now
                if let fresh = try? await app.client.journey(id) { journey = fresh }
            }
        }
    }
}
