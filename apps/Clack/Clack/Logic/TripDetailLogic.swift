//
//  TripDetailLogic.swift
//  Clack
//

import Foundation

/// What the trip detail screen derives from a leg and its live state (apps/web/src/pages/TripDetailPage.tsx;
/// docs/swift-port/SCREENS.md §2.3). Times are epoch milliseconds.
nonisolated enum TripDetailLogic {
    enum Stage: Sendable { case before, during, after }

    /// Is the leg being followed live right now?
    static func isTracking(_ live: LiveStateRow?) -> Bool { LiveRules.isLive(live) }

    /// The live state to show. No live update for a while (no connection, or the server is restarting): the phone moves
    /// the train itself.
    static func shown(_ leg: LegDetail, live: LiveStateRow?, now: Double) -> LiveStateRow? {
        guard let live, isTracking(live) else { return live }
        if now - live.updatedAt.ms > Progress.localAfterMs { return Progress.localLive(leg: leg, live: live, now: now) }
        return live
    }

    static func stage(_ leg: Leg, live: LiveStateRow?, shown: LiveStateRow?, now: Double) -> Stage {
        let tracking = isTracking(live)
        let arrivedBy = leg.actualArr?.ms ?? (tracking ? live?.arrivalEta?.ms : nil) ?? leg.schedArr?.ms ?? 0
        if shown?.status == .enRoute || shown?.status == .atStop { return .during }
        if shown?.status == .arrived || leg.actualArr != nil || now > arrivedBy { return .after }
        return .before
    }

    /// Ridden stops nobody reports live (Denmark, SJ in Norway), by country.
    static func beyondCountries(_ stops: [LegStop]) -> [String] {
        var seen = Set<String>()
        return stops.filter { $0.role.isRidden && $0.reportSource == nil }.map(\.country).filter { seen.insert($0).inserted }
    }

    /// The station the estimates beyond live data follow, from where the border was seen.
    static func borderStation(_ leg: LegDetail) -> String? {
        guard let id = leg.leg.borderEvidence?.alight?.stationId ?? leg.leg.borderEvidence?.board?.stationId else { return nil }
        return leg.stops.first { $0.stationId == id }?.name
    }

    /// The text under the delay tile when you tap it.
    enum Explanation: Equatable, Sendable {
        case unknown, late(Int), early(Int), onTime
    }

    static func explanation(arrDelayMin: Int?) -> Explanation {
        guard let arrDelayMin else { return .unknown }
        if arrDelayMin > 0 { return .late(arrDelayMin) }
        if arrDelayMin < 0 { return .early(-arrDelayMin) }
        return .onTime
    }

    /// The stops shown: the ridden ones, or the whole trip when the full route is asked for.
    static func visibleStops(_ stops: [LegStop], fullRoute: Bool) -> [LegStop] {
        fullRoute ? stops : stops.filter { $0.role != .before && $0.role != .after }
    }

    /// The time shown for a stop and the real one: the board stop uses its departure, the others their arrival.
    struct StopTimes: Equatable, Sendable {
        var sched: Double?
        /// The reported time (actual).
        var real: Double?
        /// While the train runs, Trafikverket's estimate stands in (shown in italics) until the real time is known.
        var estimate: Double?
        var actual: Double? { real ?? estimate }
        var delay: Int? { Delay.minutes(advertised: sched, actual: actual) }
    }

    static func stopTimes(_ s: LegStop) -> StopTimes {
        if s.role == .board {
            return StopTimes(sched: s.schedDep?.ms ?? s.schedArr?.ms, real: s.actualDep?.ms, estimate: s.estimatedDep?.ms)
        }
        return StopTimes(sched: s.schedArr?.ms ?? s.schedDep?.ms, real: s.actualArr?.ms ?? s.actualDep?.ms, estimate: s.estimatedArr?.ms ?? s.estimatedDep?.ms)
    }
}

extension TripDetailLogic {
    /// One line for an event: "Departed Stockholm C", "Arrived 4 min late at Göteborg C", ...
    @MainActor
    static func eventText(_ l10n: L10n, _ event: LegEvent, leg: Leg, stops: [StopName]) -> String {
        let p = event.payload
        switch event.type {
        case .departed:
            return l10n.t("activity.departed", ["station": leg.origin?.name ?? ""])
        case .arrived:
            if let delay = p.delayMin, delay > 0 {
                return l10n.t("activity.arrivedLate", ["station": leg.destination?.name ?? "", "delay": String(delay)])
            }
            return l10n.t("activity.arrived", ["station": leg.destination?.name ?? ""])
        case .delayed:
            if let delay = p.delayMin, delay <= 0 { return l10n.t("activity.delayedOnTime", ["station": leg.destination?.name ?? ""]) }
            return l10n.t("activity.delayed", ["delay": Format.delay(p.delayMin), "station": leg.destination?.name ?? ""])
        case .platformSet:
            return l10n.t(p.which == "departure" ? "activity.platformSetDeparture" : "activity.platformSetArrival", ["to": p.to ?? ""])
        case .platformChanged:
            return l10n.t(p.which == "departure" ? "activity.platformDeparture" : "activity.platformArrival", ["from": p.from ?? "", "to": p.to ?? ""])
        case .cancelled:
            return l10n.t("activity.cancelled")
        case .shortTurned:
            let names = (p.stationIds ?? []).map { id in stops.first { $0.stationId == id }?.name ?? id }
            return l10n.t("activity.shortTurned", ["stations": names.joined(separator: ", ")])
        case .unknown:
            return ""
        }
    }
}

// MARK: where you got on and off, and how far along the line the train is

extension TripDetailLogic {
    enum StopTense: Equatable, Sendable { case past, present, future }

    /// "You got on here", "You're getting on here" or "You'll get on here": by where the train is now.
    static func tense(of stop: LegStop, shown: LiveStateRow?, stage: Stage) -> StopTense {
        switch stage {
        case .after: return .past
        case .before:
            return (shown?.status == .boarding && stop.role == .board) ? .present : .future
        case .during:
            let hereNow = shown?.status == .atStop && (shown?.prevStopId == stop.stationId || shown?.nextStopId == stop.stationId)
            if hereNow { return .present }
            return stop.role == .board ? .past : .future
        }
    }

    /// One half of the rail beside a stop: whether this stretch is ridden, how much of it the train has covered (0 to 1,
    /// from its top) and where the train is on it, when it's on this half.
    struct RailHalf: Equatable, Sendable {
        var ridden = false
        var fill = 0.0
        var train: Double?
    }

    /// For each stop but the last: the share (0 to 1) of the stretch to the next stop the train has covered. A trip that
    /// has arrived is covered all the way; one that hasn't started, not at all; one under way is placed by the train's
    /// position along the route line (else by the times).
    static func segmentFills(stops: [LegStop], route: [LatLon], shown: LiveStateRow?, stage: Stage, now: Double) -> [Double] {
        guard stops.count > 1 else { return [] }
        let pairs = (0..<(stops.count - 1)).map { stops[$0].role.isRidden && stops[$0 + 1].role.isRidden }
        switch stage {
        case .after: return pairs.map { $0 ? 1 : 0 }
        case .before: return pairs.map { _ in 0 }
        case .during: break
        }
        if route.count > 1 {
            let cum = Progress.cumulative(route)
            var from = 0.0
            let metres: [Double] = stops.map { stop in
                let m = Progress.locate(route, cum, lat: stop.lat, lon: stop.lon, from: from)
                from = max(from, m)
                return m
            }
            let total = cum.last ?? 0
            var train: Double?
            if let lat = shown?.lat, let lon = shown?.lon { train = Progress.locate(route, cum, lat: lat, lon: lon) }
            else if let progress = shown?.progress { train = progress * total }
            if let train {
                return (0..<(stops.count - 1)).map { i in
                    guard pairs[i], metres[i + 1] > metres[i] else { return 0 }
                    return min(1, max(0, (train - metres[i]) / (metres[i + 1] - metres[i])))
                }
            }
        }
        return (0..<(stops.count - 1)).map { i in
            guard pairs[i] else { return 0 }
            let a = stops[i], b = stops[i + 1]
            guard let dep = (a.actualDep ?? a.estimatedDep ?? a.schedDep)?.ms, let arr = (b.actualArr ?? b.estimatedArr ?? b.schedArr)?.ms, arr > dep else { return 0 }
            return min(1, max(0, (now - dep) / (arr - dep)))
        }
    }

    /// The two halves of each stop's rail, from the fills: a stretch between two stops is drawn half in the row above
    /// and half in the row below, so the train can be shown between stops.
    static func railHalves(stops: [LegStop], fills: [Double], showTrain: Bool) -> [(above: RailHalf, below: RailHalf)] {
        stops.indices.map { i in
            var above = RailHalf(), below = RailHalf()
            if i > 0, i - 1 < fills.count {
                let f = fills[i - 1]
                above.ridden = stops[i - 1].role.isRidden && stops[i].role.isRidden
                above.fill = min(1, max(0, 2 * f - 1))
                if showTrain, f > 0.5, f < 1 { above.train = 2 * f - 1 }
            }
            if i < fills.count {
                let f = fills[i]
                below.ridden = stops[i].role.isRidden && stops[i + 1].role.isRidden
                below.fill = min(1, max(0, 2 * f))
                if showTrain, f > 0, f <= 0.5 { below.train = 2 * f }
            }
            return (above, below)
        }
    }
}
