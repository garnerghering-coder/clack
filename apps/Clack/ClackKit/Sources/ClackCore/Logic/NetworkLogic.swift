//
//  NetworkLogic.swift
//  Clack
//

import Foundation

/// Network now, about your own trains (designer, 2026-11-14: "Your trips today: affected / not affected").
public nonisolated enum NetworkLogic {
    public enum Why: Equatable, Sendable {
        case canceled
        case late(Int)
        /// A disruption, a slow stretch or cancellations at one of its stations.
        case near(String)
    }

    public struct Affected: Equatable, Sendable {
        public let leg: Leg
        public let why: Why
    }

    /// The trains you have today that haven't arrived yet (or arrived within the last hour), first first.
    public static func today(_ legs: [Leg], now: Double, tz: String = Format.defaultZone) -> [Leg] {
        let day = Format.localDate(now, tz: tz)
        return legs.filter { leg in
            guard let dep = leg.schedDep?.ms, leg.ride != .notTaken else { return false }
            let arr = TripsLogic.expected(leg).arr ?? leg.schedArr?.ms ?? dep
            return Format.localDate(dep, tz: tz) == day && arr > now - 3600_000
        }
        .sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
    }

    /// Which of today's trains the network touches, and how: cancelled, running late (`lateMin` or more), or with
    /// trouble at one of its stations (a disruption, a slow stretch, cancellations there).
    public static func affected(_ legs: [Leg], status: NetworkStatus) -> [Affected] {
        var troubled = Set<String>()
        for d in status.disruptions ?? [] { troubled.formUnion(d.places) }
        for c in status.corridors { troubled.formUnion(c.stations) }
        for g in status.cancelled ?? [] { troubled.formUnion(g.stations) }
        return legs.compactMap { leg in
            if leg.canceled { return Affected(leg: leg, why: .canceled) }
            let delay = max(leg.depDelayMin ?? 0, leg.arrDelayMin ?? 0, leg.live?.arrivalDelayMin ?? 0)
            if delay >= status.lateMin { return Affected(leg: leg, why: .late(delay)) }
            for name in [leg.origin?.name, leg.destination?.name].compactMap({ $0 }) where troubled.contains(name) {
                return Affected(leg: leg, why: .near(name))
            }
            return nil
        }
    }
}
