//
//  JourneyNow.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The live side of a journey: the detail and live state of the leg that is running now (else the next to leave),
/// loaded and kept current the way the trip page does it (TripDetailScreen `load()` and `listen()`).
@MainActor @Observable
final class JourneyNowModel {
    private(set) var legId: String?
    private(set) var detail: LegDetail?
    private(set) var live: LiveStateRow?

    /// Follow `id` (nil: no leg is in focus): fetch it, then refetch on each live tick for it.
    func follow(_ id: String?, app: AppModel) async {
        if id != legId { detail = nil; live = nil; legId = id }
        guard let id else { return }
        await load(id, app: app)
        for await update in app.live.updates() {
            guard update.legId == id else { continue }
            live = update.live
            await load(id, app: app)
        }
    }

    private func load(_ id: String, app: AppModel) async {
        guard let loaded = try? await app.client.leg(id) else { return }
        detail = loaded
        live = loaded.leg.live
    }
}

/// The "Now" section at the top of a journey: what the train is doing, where it is, and the change coming up.
struct JourneyNowSection: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let model: JourneyNowModel
    let legs: [Leg]
    let now: Double

    var body: some View {
        if let detail = model.detail {
            let shown = TripDetailLogic.shown(detail, live: model.live, now: now, offline: app.isOffline)
            let l = detail.leg
            VStack(alignment: .leading, spacing: 12) {
                Text(l10n.t("journey.now")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                ServiceHeader(op: l.operator, number: l.trainNumber, size: .large, category: l.category) {
                    if TripDetailLogic.isTracking(shown), let shown {
                        LiveStatus(live: shown, now: now)
                    }
                }
                card(detail, shown: shown, now: now)
                if let index = legs.firstIndex(where: { $0.id == l.id }), index + 1 < legs.count,
                   l.destination?.id == legs[index + 1].origin?.id {
                    ConnectionCard(a: l, b: legs[index + 1], compact: true)
                }
            }
        }
    }

    @ViewBuilder
    private func card(_ detail: LegDetail, shown: LiveStateRow?, now: Double) -> some View {
        let l = detail.leg
        if TripDetailLogic.isTracking(shown), let shown,
           TripDetailLogic.stage(l, live: shown, shown: shown, now: now) == .during {
            let dtz = l.destination?.tz ?? "Europe/Stockholm"
            StatusCard(
                kind: .live,
                text: l10n.t("live.arrives", ["time": Format.time(shown.arrivalEta?.ms ?? l.schedArr?.ms, tz: dtz, clock: app.settings.clock)])
            ) {
                if let delay = shown.arrivalDelayMin { DelayText(delay: delay) }
            }
            Card {
                LiveModule(leg: l, live: shown, stops: detail.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) }, now: now)
            }
        } else {
            let status = TripsLogic.countdownStatus(l10n, l, now: now)
            let platform = l.depPlatform.map { l10n.t("trips.platform", ["platform": $0]) } ?? l10n.t("detail.platformLater")
            StatusCard(kind: status.kind, text: status.text) {
                if !l.canceled {
                    Text(platform).clack(.body).foregroundStyle(Ink.text2)
                    if l.depDelayMin != nil { DelayText(delay: l.depDelayMin) }
                }
            }
            if let shown, TripDetailLogic.isTracking(shown) {
                Card {
                    LiveModule(leg: l, live: shown, stops: detail.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) }, now: now)
                }
            }
        }
    }
}

/// The map while the train is running: the leg's route with the train, how far it has gone, following it.
struct JourneyNowMap: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let detail: LegDetail
    let live: LiveStateRow?
    let now: Double

    var body: some View {
        let geo = RouteGeo(detail)
        let shown = TripDetailLogic.shown(detail, live: live, now: now, offline: app.isOffline)
        let train: MapTrain? = shown.flatMap { s in
            s.lat.flatMap { lat in s.lon.map { MapTrain(lat: lat, lon: $0, bearing: s.bearing, estimated: s.positionSource != .gps || s.localEstimate) } }
        }
        RouteMapView(
            color: MapStyle.opColor(detail.leg.operator?.brandColor, dark: scheme == .dark), route: geo.route, stops: geo.stops,
            animate: false, railNetwork: app.settings.showRailNetwork, train: train, fitTrain: shown?.status == .approaching,
            progress: shown?.progress,
            label: l10n.t("detail.mapLabel", ["from": detail.leg.origin?.name ?? "", "to": detail.leg.destination?.name ?? ""]),
            followTrain: true
        )
    }

    /// Does the running train deserve the map: tracked, and on the train (not before departure).
    static func isUnderway(_ detail: LegDetail?, live: LiveStateRow?, now: Double, offline: Bool) -> Bool {
        guard let detail else { return false }
        let shown = TripDetailLogic.shown(detail, live: live, now: now, offline: offline)
        return TripDetailLogic.stage(detail.leg, live: live, shown: shown, now: now) == .during
    }
}
