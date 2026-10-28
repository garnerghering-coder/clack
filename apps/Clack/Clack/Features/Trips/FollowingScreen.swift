//
//  FollowingScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

extension SharedJourney.Operator: OperatorDisplay {}

/// A journey someone shared, as a follower sees it (owner, 2026-10-25): where it is in words, the map with the train, and
/// the trains and changes as one rail. A follower is watching, not travelling, so there is nothing to edit and none of the
/// traveller's own parts: no seat, no ticket, no station walk, no history.
struct FollowingScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let token: String
    @State private var journey: SharedJourney?
    @State private var gone = false

    var body: some View {
        Page {
            if gone {
                ended
            } else if let journey {
                content(journey)
            } else {
                Text(l10n.t("following.opening")).clack(.body).foregroundStyle(Ink.text2)
                Skeleton(height: 120)
            }
        }
        .plainBar()
        .countsScreen("following")
        .task(id: token) { await keepFresh() }
    }

    /// Opens the journey (following it if this is the first time), then asks for a fresh copy every 15 s while it shows.
    private func keepFresh() async {
        if let known = app.followed.journey(token) {
            journey = known
        } else {
            guard let first = await app.followed.follow(token: token, app: app) else { gone = true; return }
            journey = first
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(15))
            switch await app.followed.refresh(token: token, app: app) {
            case .fresh(let fresh): journey = fresh; gone = false
            case .gone: gone = true
            case .failed: break
            }
        }
    }

    private var ended: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("share.web.ended")).clack(.headline).foregroundStyle(Ink.text)
            Text(l10n.t("share.web.endedBody")).clack(.body).foregroundStyle(Ink.text2)
            Button(l10n.t("following.stop")) { Task { await stop() } }.buttonStyle(.clack(wide: true))
        }
    }

    private func stop() async {
        await app.followed.stop(token: token, app: app)
        dismiss()
    }

    @ViewBuilder
    private func content(_ j: SharedJourney) -> some View {
        let clock = app.settings.clock
        Text("\(j.summary.from) → \(j.summary.to)")
            .clack(.detailRoute).foregroundStyle(Ink.text)
            .fixedSize(horizontal: false, vertical: true)
        if let first = j.legs.first, let day = first.schedDep {
            Text(Format.longDate(day, tz: first.from.tz, language: app.settings.language)).clack(.body).foregroundStyle(Ink.text2)
        }
        FollowingStatus(journey: j)
        FollowingMap(journey: j)
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let made = JourneyRail.of(j, now: context.date.timeIntervalSince1970 * 1000, scheme: scheme)
            JourneyTimeline(rails: made.rails, waited: made.waited) { index in
                FollowingLeg(leg: j.legs[index], clock: clock)
            } change: { index in
                if let change = j.changes.first(where: { $0.index == index }) { FollowingChange(journey: j, change: change) }
            }
        }
        Button(l10n.t("following.stop")) { Task { await stop() } }
            .buttonStyle(.clack(wide: true))
            .padding(.top, 8)
    }
}

/// "Between Alvesta and Hässleholm C", with when it arrives and how late, in the delay band's ink.
struct FollowingStatus: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let journey: SharedJourney

    var body: some View {
        let clock = app.settings.clock
        Card {
            StatusLine(kind, SharedLogic.statusLine(journey, l10n: l10n, clock: clock))
                .clack(.headline)
            if journey.summary.phase != .cancelled {
                HStack(spacing: 8) {
                    if let line = SharedLogic.arrivalLine(journey, l10n: l10n, clock: clock) {
                        Text(line).clack(.body).foregroundStyle(Ink.text2)
                    }
                    if let word = SharedLogic.delayWord(journey.summary.arrivalDelayMin, l10n: l10n) {
                        Text(word).clack(.body).fontWeight(.semibold)
                            .foregroundStyle(DelayBand(delayMin: journey.summary.arrivalDelayMin).ink)
                    }
                }
            }
        }
    }

    private var kind: StatusLine.Kind {
        switch journey.summary.phase {
        case .underway, .atChange: .live
        case .upcoming: .upcoming
        case .arrived: .arrived
        case .cancelled: .band(.veryLate)
        }
    }
}

/// The journey on a map: every train's route in one line, the train where it is (only a position the data has), and
/// the part already travelled apart from the part ahead.
struct FollowingMap: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(L10n.self) private var l10n
    let journey: SharedJourney

    var body: some View {
        let legs = journey.legs
        let routes: [[LatLon]] = legs.map { $0.geometry.map(Polyline.decode) ?? [] }
        let route = routes.flatMap { $0 }
        let running = journey.summary.phase == .underway ? legs[safe: journey.summary.legIndex] : nil
        let train: MapTrain? = running?.live.flatMap { live in
            guard let lat = live.lat, let lon = live.lon else { return nil }
            return MapTrain(lat: lat, lon: lon, bearing: live.bearing, estimated: live.positionSource != "gps")
        }
        // Share of the whole line already travelled: the trains before the running one, and its own share of its line.
        let lengths = routes.map { Progress.cumulative($0).last ?? 0 }
        let total = lengths.reduce(0, +)
        let progress: Double? = {
            guard total > 0, let running, train != nil, let share = running.live?.progress else { return nil }
            let at = journey.summary.legIndex
            return (lengths.prefix(at).reduce(0, +) + lengths[at] * min(1, max(0, share))) / total
        }()
        var stops: [MapStop] = []
        for (index, leg) in legs.enumerated() {
            guard let line = routes[index].first, let end = routes[index].last else { continue }
            if index == 0 { stops.append(MapStop(lat: line.lat, lon: line.lon, name: leg.from.name, kind: .end)) }
            stops.append(MapStop(lat: end.lat, lon: end.lon, name: leg.to.name, kind: .end))
        }
        return RouteMapView(
            color: MapStyle.opColor(running?.operator?.brandColor ?? legs.first?.operator?.brandColor, dark: scheme == .dark),
            route: route, stops: stops, interactive: true, controls: false, railNetwork: true, train: train, progress: progress,
            label: l10n.t("share.web.mapLabel")
        )
    }
}

/// One train of the journey: who runs it, where it goes, when, how late.
struct FollowingLeg: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: SharedJourney.Leg
    let clock: ClockFormat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                OperatorBadge(op: leg.operator, size: .large)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(leg.from.name) → \(leg.to.name)").clack(.rowTitle).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                    if !leg.service.isEmpty { Text(leg.service).clack(.caption).foregroundStyle(Ink.text2) }
                }
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                time(leg.expDep, leg.schedDep, tz: leg.from.tz)
                Text("→").clack(.body).foregroundStyle(Ink.text3)
                time(leg.expArr, leg.schedArr, tz: leg.to.tz)
                Spacer(minLength: 0)
                DelayText(delay: leg.arrDelayMin, canceled: leg.canceled)
            }
            if let platform = leg.depPlatform { Chip(text: l10n.t("trips.platform", ["platform": platform])) }
            if !leg.stops.isEmpty {
                DisclosureGroup(l10n.t("share.stops")) {
                    VStack(spacing: 4) {
                        ForEach(Array(leg.stops.enumerated()), id: \.offset) { _, stop in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(stop.name).strikethrough(stop.canceled)
                                    Spacer(minLength: 8)
                                    Text(Format.time(stop.dep ?? stop.arr, tz: stop.tz, clock: clock)).monospacedDigit()
                                    if let platform = stop.platform { Text(platform).foregroundStyle(Ink.accentInk) }
                                }
                                .clack(.stopName)
                                // Why it's late or changed here, under the station.
                                let causes = l10n.causeNotes(stop.causes ?? [])
                                if !causes.isEmpty {
                                    Text(Format.join(causes)).clack(.caption).foregroundStyle(Ink.text2)
                                }
                            }
                            .foregroundStyle(stop.passed ? Ink.text3 : Ink.text)
                        }
                    }
                    .padding(.top, 4)
                }
                .clack(.caption).tint(Ink.text2).foregroundStyle(Ink.text2)
            }
        }
        .padding(.vertical, 8)
    }

    private func time(_ expected: Double?, _ scheduled: Double?, tz: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(Format.time(expected, tz: tz, clock: clock)).clack(.rowTitle).monospacedDigit().foregroundStyle(Ink.text)
            if let expected, let scheduled, abs(expected - scheduled) >= 60_000 {
                Text(Format.time(scheduled, tz: tz, clock: clock)).clack(.caption).monospacedDigit().strikethrough().foregroundStyle(Ink.text3)
            }
        }
    }
}

/// The change between two trains, for someone watching: where, how long, the platforms and whether it will be made.
struct FollowingChange: View {
    @Environment(L10n.self) private var l10n
    let journey: SharedJourney
    let change: SharedJourney.Change

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(SharedLogic.changeTitle(change, in: journey, l10n: l10n)).clack(.banner).fontWeight(.semibold).foregroundStyle(Ink.text)
            if change.arrPlatform != nil || change.depPlatform != nil {
                Text(l10n.t("connection.tracks", ["from": change.arrPlatform ?? Format.unknown, "to": change.depPlatform ?? Format.unknown]))
                    .clack(.caption).foregroundStyle(Ink.text2)
            }
            switch change.status {
            case .missed: StatusLine(.band(.veryLate), l10n.t("journey.missed"))
            case .tight: StatusLine(.band(.slight), l10n.t("journey.tight"))
            case .ok: StatusLine(.band(.onTime), l10n.t("share.changeOk"))
            case .unknown: EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The journeys you follow, at the top of Trips: one line each, tapping opens the follower screen.
struct FollowedJourneysSection: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n

    var body: some View {
        let list = app.followed.journeys
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t("trips.following")).clack(.sectionHeader).foregroundStyle(Ink.text2).padding(.top, 2)
                ForEach(list) { journey in
                    NavigationLink(value: AppRoute.following(journey.token)) { FollowingCard(journey: journey) }
                        .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// A followed journey on Trips: the route, the status in words and when it arrives.
struct FollowingCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let journey: SharedJourney

    var body: some View {
        let clock = app.settings.clock
        let running = journey.legs[safe: journey.summary.legIndex]
        HStack(spacing: 12) {
            OperatorBadge(op: running?.operator ?? journey.legs.first?.operator, size: .large)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(journey.summary.from) → \(journey.summary.to)").clack(.rowTitle).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(SharedLogic.statusLine(journey, l10n: l10n, clock: clock)).clack(.caption).foregroundStyle(Ink.text2)
                if let word = SharedLogic.delayWord(journey.summary.arrivalDelayMin, l10n: l10n), journey.summary.phase != .cancelled {
                    Text(word).clack(.caption).fontWeight(.semibold).foregroundStyle(DelayBand(delayMin: journey.summary.arrivalDelayMin).ink)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .contentShape(Rectangle())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
