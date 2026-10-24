//
//  FeaturedCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The map strip of a trip card, until the real map arrives in step 8: the map's background with its tag.
struct MapPlaceholder: View {
    var height: CGFloat

    var body: some View {
        Ink.mapBg.frame(height: height)
    }
}

/// The featured journey (brief §5.2): one tappable card, route map on top, the journey under it.
struct FeaturedCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let leg: Leg
    let state: TripsLogic.HeroState
    /// The leg you change to next, if this one is part of a journey with a change ahead.
    let next: Leg?
    @State private var detail: LegDetail?
    /// The route strip's geometry, decoded once when the detail arrives (not every second with the clock).
    @State private var strip: FeaturedMapStrip.Route?

    var body: some View {
        TimelineView(.periodic(from: .now, by: state == .active ? 1 : 30)) { context in
            let now = context.date.timeIntervalSince1970 * 1000
            NavigationLink(value: AppRoute.trip(leg.id)) { card(now: now) }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("trips.viewJourney", ["from": leg.origin?.name ?? "", "to": leg.destination?.name ?? ""]))
        }
        .task(id: leg.id) {
            if let cached = app.legDetails[leg.id] {
                set(cached)
            } else if let fetched = try? await app.client.leg(leg.id) {
                app.legDetails[leg.id] = fetched
                set(fetched)
            }
        }
    }

    private func set(_ detail: LegDetail) {
        self.detail = detail
        let geo = detail.mapRoute(endsOnly: true)
        strip = FeaturedMapStrip.Route(route: geo.route, stops: geo.stops)
    }

    private func card(now: Double) -> some View {
        let op = operatorColor(leg.operator?.brandColor, scheme: scheme)
        let live = leg.live
        // Only a fresh position draws the train, and only then is the route split into travelled and ahead.
        let grounded = state == .active && live != nil && LiveRules.isFresh(live, now: now)
            && live?.lat != nil && live?.lon != nil && live?.positionSource != nil

        let tag: String = {
            switch state {
            case .upcoming: return l10n.t("trips.routePreview")
            case .arrived: return l10n.t("trips.routeSummary")
            case .active:
                guard grounded else { return l10n.t("trips.noPositionShort") }
                return live?.positionSource == .estimated ? l10n.t("live.estimatedPosition") : l10n.t("live.livePosition")
            }
        }()
        return VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                featuredMap(grounded: grounded)
                Text(tag)
                    .clack(.micro).foregroundStyle(Ink.text2)
                    .padding(.vertical, 2).padding(.horizontal, 8)
                    .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .padding(.leading, 12).padding(.top, 8)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                ServiceHeader(op: leg.operator, number: leg.trainNumber, size: .medium, seat: state == .arrived ? nil : Seat.label(l10n, coach: leg.coach, seat: leg.seat)) {
                    switch state {
                    case .upcoming: StatusLine(.upcoming, l10n.t("trips.planned"))
                    case .arrived: StatusLine(.arrived, l10n.t("trips.arrived"))
                    case .active: if let live { LiveStatus(live: live, now: now) }
                    }
                }
                Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                    .clack(.headline).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                TimePair(leg: leg, clock: app.settings.clock, flap: .lg, intro: true).clack(.heroTimes)
                bottom(now: now, live: live)
            }
            .padding(.top, 16).padding(.bottom, 16).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Surface.Hero(op: op))
        }
        .background(Surface.Hero(op: op))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    /// The route strip, outside the clock's reach: it is redrawn only when its own inputs change.
    private func featuredMap(grounded: Bool) -> some View {
        let live = leg.live
        return FeaturedMapStrip(
            color: MapStyle.opColor(leg.operator?.brandColor, dark: scheme == .dark), geo: strip,
            train: grounded ? live.flatMap { l in l.lat.flatMap { lat in l.lon.map { MapTrain(lat: lat, lon: $0, bearing: l.bearing, estimated: l.positionSource == .estimated) } } } : nil,
            progress: grounded ? live?.progress : nil
        )
        .equatable()
    }

    @ViewBuilder
    private func bottom(now: Double, live: LiveStateRow?) -> some View {
        switch state {
        case .active:
            if let live {
                DelayText(delay: live.arrivalDelayMin, canceled: leg.canceled)
                if let next {
                    HeroConnection(a: leg, b: next)
                } else {
                    LiveModule(
                        leg: leg, live: live,
                        stops: (detail?.stops ?? []).map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) },
                        now: now, compact: true
                    )
                }
            }
        case .arrived:
            HStack(spacing: 8) {
                Text(leg.actualArr != nil
                    ? l10n.t("trips.arrivedAt", ["time": Format.time(leg.actualArr?.ms, tz: leg.destination?.tz ?? TripsLogic.tz(leg), clock: app.settings.clock)])
                    : l10n.t("trips.scheduledTimes"))
                    .clack(.caption).foregroundStyle(Ink.text2)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    LucideIcon(name: "stamp", size: 14)
                    Text(l10n.t("trips.inPassport"))
                }
                .clack(.caption).fontWeight(.semibold).foregroundStyle(Ink.accentInk)
            }
        case .upcoming:
            HStack(spacing: 8) {
                CountdownLine(leg: leg, now: now)
                if let platform = leg.depPlatform { Chip(text: l10n.t("trips.platform", ["platform": platform])) }
                if leg.depDelayMin != nil { DelayText(delay: leg.depDelayMin, canceled: leg.canceled) }
            }
        }
    }
}

/// The route strip of the featured card: not interactive, without controls. The train and the travelled/ahead split
/// only when the position is fresh; fewer than two points is an empty map. `Equatable`, so the card's one-second clock
/// doesn't make the map re-evaluate.
struct FeaturedMapStrip: View, Equatable {
    struct Route: Equatable {
        var route: [LatLon]
        var stops: [MapStop]
    }

    let color: String
    let geo: Route?
    let train: MapTrain?
    let progress: Double?

    var body: some View {
        Group {
            if let geo, geo.route.count > 1 {
                RouteMapView(
                    color: color, route: geo.route, stops: geo.stops, interactive: false, controls: false,
                    train: train, progress: progress
                )
            } else {
                Ink.mapBg
            }
        }
        .frame(height: 140)
    }
}
