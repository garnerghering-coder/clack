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
