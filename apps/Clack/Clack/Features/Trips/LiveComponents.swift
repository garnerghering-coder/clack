//
//  LiveComponents.swift
//  Clack
//

import ClackCore
import SwiftUI

/// Station information and map for the station a change happens at, loaded once per station (Connection.tsx
/// `useStationMap`), with the connection worked out from them.
@MainActor
@Observable
final class ConnectionModel {
    private(set) var map: StationMap?
    private(set) var info: StationInfo?
    private var loadedStation: String?

    func load(stationId: String?, using stations: StationDirectory) async {
        guard let stationId, loadedStation != stationId else { return }
        loadedStation = stationId
        info = await stations.info(stationId)
        map = await stations.map(stationId)
    }

    func result(_ a: Leg, _ b: Leg, profile: WalkProfile) -> ConnectionResult {
        TripsLogic.connection(a, b, map: map, info: info, profile: profile).result
    }
}

/// The LIVE chip: a blinking green dot and "Live" while the data is fresh, otherwise how long ago it was.
struct LiveChip: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let live: LiveStateRow
    let now: Double
    @State private var dim = false

    var body: some View {
        if live.localEstimate {
            Chip(text: l10n.t("offline.chip"), tint: Ink.text3)
        } else if LiveRules.isFresh(live, now: now) {
            HStack(spacing: 5) {
                Circle().fill(Ink.onTime).frame(width: 8, height: 8)
                    .opacity(dim ? 0.35 : 1)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: dim)
                Text(l10n.t("live.chip")).lineLimit(1)
            }
            .clack(.chip)
            .foregroundStyle(Ink.onTimeInk)
            .onAppear { dim = true }
        } else {
            Chip(text: l10n.t("live.stale", ["ago": LiveRules.ago(l10n, then: LiveRules.dataAt(live), now: now)]), tint: Ink.text3)
        }
    }
}

/// The train's speed from its GPS, only when it's fresh and passed the server's checks; otherwise nothing.
struct Speedometer: View {
    let kmh: Double?
    let at: Double?
    let now: Double

    var body: some View {
        if let kmh, let at, now - at <= LiveRules.speedFreshMs {
            HStack(spacing: 4) {
                LucideIcon(name: "gauge", size: 14)
                Text("\(Int(kmh.rounded())) km/h").monospacedDigit()
            }
            .foregroundStyle(Ink.text2)
        }
    }
}

/// Progress bar, where the train is, next stop and arrival, freshness and position source (DESIGN §9.5).
struct LiveModule: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let leg: Leg
    let live: LiveStateRow
    let stops: [StopName]
    let now: Double
    var compact = false

    private func name(_ id: String?) -> String { stops.first { $0.stationId == id }?.name ?? "" }
    private func tz(_ id: String?) -> String { stops.first { $0.stationId == id }?.tz ?? leg.origin?.tz ?? "Europe/Stockholm" }

    private var where_: String {
        switch live.status {
        case .approaching: return l10n.t("live.approachingTo", ["name": name(live.nextStopId)])
        case .boarding: return l10n.t("live.boardingAt", ["name": leg.origin?.name ?? ""])
        case .atStop: return l10n.t("live.atStop", ["name": name(live.prevStopId)])
        default:
            if live.prevStopId != nil, live.nextStopId != nil {
                return l10n.t("live.between", ["a": name(live.prevStopId), "b": name(live.nextStopId)])
            }
            return ""
        }
    }

    private var source: String {
        if live.localEstimate { return l10n.t("offline.estimated") }
        switch live.positionSource {
        case .gps: return l10n.t("live.livePosition")
        case .estimated: return l10n.t("live.estimatedPosition")
        default: return l10n.t("live.noPosition")
        }
    }

    var body: some View {
        let op = operatorColor(leg.operator?.brandColor, scheme: scheme)
        let progress = max(0, min(1, live.progress ?? 0))
        let hollow = live.positionSource == .estimated || live.localEstimate
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Ink.hairline)
                    Capsule().fill(op).frame(width: proxy.size.width * progress)
                    Circle()
                        .fill(hollow ? Ink.bg : op)
                        .overlay(Circle().strokeBorder(hollow ? op : .white, lineWidth: 2))
                        .frame(width: 14, height: 14)
                        .offset(x: proxy.size.width * progress - 7)
                        .animation(.linear(duration: 1), value: progress)
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 14)
            .padding(.top, 2)
            .padding(.bottom, 2)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(l10n.t("live.progressLabel", ["percent": String(Int((progress * 100).rounded())), "name": leg.destination?.name ?? ""]))
            .accessibilityValue("\(Int((progress * 100).rounded()))%")

            if !where_.isEmpty {
                HStack(spacing: 8) {
                    Text(where_).clack(.rowTitle).foregroundStyle(Ink.text)
                    if live.positionSource == .gps, !live.localEstimate {
                        Speedometer(kmh: live.speedKmh, at: live.positionAt?.ms, now: now).clack(.caption)
                    }
                }
            }
            if let nextId = live.nextStopId, live.status != .boarding {
                HStack(spacing: 6) {
                    Text(l10n.t("live.nextStopName", ["name": name(nextId)])).clack(.body).foregroundStyle(Ink.text)
                    FlapTime(time: live.eta?.ms, tz: tz(nextId), clock: app.settings.clock)
                        .clack(.body).foregroundStyle(Ink.text)
                }
            }
            if !compact {
                HStack(spacing: 8) {
                    Text(l10n.t("live.arrivesLabel")).clack(.body).foregroundStyle(Ink.text)
                    FlapTime(time: live.arrivalEta?.ms, tz: leg.destination?.tz ?? "Europe/Stockholm", clock: app.settings.clock)
                        .clack(.body).foregroundStyle(Ink.text)
                    DelayText(delay: live.arrivalDelayMin)
                }
            }
            Text("\(l10n.t("live.updated", ["ago": LiveRules.ago(l10n, then: LiveRules.dataAt(live), now: now)])) · \(source)")
                .clack(.caption).foregroundStyle(Ink.text2)
        }
        .padding(.top, compact ? 12 : 0)
        .accessibilityElement(children: .contain)
    }
}

/// The status of a change, written in the colour of its band (ConnectionChip).
struct ConnectionChip: View {
    @Environment(L10n.self) private var l10n
    let result: ConnectionResult

    private var band: DelayBand {
        switch result.status {
        case .easy: .onTime
        case .tight: .slight
        case .miss, .broken: .veryLate
        case .unknown, .margin: .unknown
        }
    }

    private var text: String {
        let spareMin = result.slackSeconds.map { Int(($0 / 60).rounded(.down)) }
        // A margin is just the number (brief §7); the others say what they are, then the minutes.
        if result.status == .margin, let spareMin { return l10n.t("connection.marginSpare", ["min": String(spareMin)]) }
        var out = l10n.t("connection.status.\(result.status.rawValue)")
        if let spareMin, spareMin >= 0, result.status != .broken { out += " · " + l10n.t("connection.spare", ["min": String(spareMin)]) }
        return out
    }

    var body: some View {
        Text(text)
            .clack(.delay)
            .fontWeight(band == .unknown ? .semibold : .bold)
            .foregroundStyle(band.ink)
            .lineLimit(1)
    }
}

/// The next event is a change (ADDITIONS_01 C3): "Change at Hässleholm · Track 2 → 5 · 6 min walk · Tight".
struct HeroConnection: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let a: Leg
    let b: Leg
    @State private var model = ConnectionModel()

    var body: some View {
        let result = model.result(a, b, profile: app.walkProfile)
        let walk = result.walkSeconds.map { l10n.t("connection.walk", ["min": String(max(1, Int(($0 / 60).rounded())))]) }
        let tracks = (a.arrPlatform != nil || b.depPlatform != nil)
            ? l10n.t("connection.tracks", ["from": a.arrPlatform ?? "?", "to": b.depPlatform ?? "?"]) : nil
        let line = [l10n.t("connection.changeAt", ["station": a.destination?.name ?? ""]), tracks, walk].compactMap { $0 }.joined(separator: " · ")
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                Text(line).clack(.banner).fontWeight(.semibold).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
                ConnectionChip(result: result)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(line).clack(.banner).fontWeight(.semibold).foregroundStyle(Ink.text)
                ConnectionChip(result: result)
            }
        }
        .task { await model.load(stationId: a.destination?.id, using: app.stations) }
    }
}

/// A change between two legs of a journey: platforms, walk time and a status chip, with the station map when there
/// is one (ConnectionCard).
struct ConnectionCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let a: Leg
    let b: Leg
    var compact = false
    @State private var model = ConnectionModel()

    var body: some View {
        let result = model.result(a, b, profile: app.walkProfile)
        let times = TripsLogic.connectionTimes(a, b)
        let walkMin = result.walkSeconds.map { max(1, Int(($0 / 60).rounded())) }
        let tracks = (a.arrPlatform != nil || b.depPlatform != nil)
            ? l10n.t("connection.tracks", ["from": a.arrPlatform ?? "?", "to": b.depPlatform ?? "?"]) : nil
        let caption = [
            tracks,
            walkMin.map { l10n.t("connection.walk", ["min": String($0)]) },
            result.layoverSeconds.map { l10n.t("connection.layover", ["min": String(Int((Double($0) / 60).rounded()))]) },
        ].compactMap { $0 }.joined(separator: " · ")
        let content = VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(l10n.t("connection.changeAt", ["station": a.destination?.name ?? ""])).clack(.rowTitle).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
                ConnectionChip(result: result)
            }
            Text(caption).clack(.caption).foregroundStyle(Ink.text2)
            if !times.live && result.status != .broken {
                Text(l10n.t("connection.timetableOnly")).clack(.caption).foregroundStyle(Ink.text2)
            }
            if result.status == .broken {
                Banner(kind: .error) { Text(l10n.t("connection.brokenBanner")) }
            }
            if model.map != nil, let stationId = a.destination?.id {
                NavigationLink(value: AppRoute.stationMap(TripsLogic.mapLink(stationId, a, b))) {
                    HStack(spacing: 6) {
                        LucideIcon(name: "map", size: 16)
                        Text(l10n.t("connection.openMap"))
                    }
                }
                .buttonStyle(.clack(small: true))
            }
        }
        Group {
            if compact {
                content
            } else {
                Card { content }.padding(.vertical, 8)
            }
        }
        .task { await model.load(stationId: a.destination?.id, using: app.stations) }
    }
}
