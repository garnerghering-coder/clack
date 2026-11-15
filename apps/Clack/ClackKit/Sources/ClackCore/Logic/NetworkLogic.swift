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
        /// A disruption, a slow stretch or cancellations at one of its stations: which station, and what's there
        /// (so tapping the train can show it).
        case near(String, Trouble)
    }

    /// What touches a station: a disruption (by id), a slow stretch (by corridor id) or cancelled trains.
    public enum Trouble: Equatable, Sendable {
        case disruption(String)
        case corridor(String)
        case cancelled
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
        // The first trouble named at each station: disruptions first (they have a page of their own), then slow
        // stretches, then cancellations.
        var troubled: [String: Trouble] = [:]
        for d in status.disruptions ?? [] { for p in d.places where troubled[p] == nil { troubled[p] = .disruption(d.id) } }
        for c in status.corridors { for p in c.stations where troubled[p] == nil { troubled[p] = .corridor(c.id) } }
        for g in status.cancelled ?? [] { for p in g.stations where troubled[p] == nil { troubled[p] = .cancelled } }
        return legs.compactMap { leg in
            if leg.canceled { return Affected(leg: leg, why: .canceled) }
            let delay = max(leg.depDelayMin ?? 0, leg.arrDelayMin ?? 0, leg.live?.arrivalDelayMin ?? 0)
            if delay >= status.lateMin { return Affected(leg: leg, why: .late(delay)) }
            for name in [leg.origin?.name, leg.destination?.name].compactMap({ $0 }) {
                if let trouble = troubled[name] { return Affected(leg: leg, why: .near(name, trouble)) }
            }
            return nil
        }
    }

    /// The disruptions at stations you pass on this leg (where you get on, through, where you get off), by name.
    public static func onRoute(_ stops: [LegStop], status: NetworkStatus) -> [NetworkStatus.Disruption] {
        let names = Set(stops.filter { $0.role == .board || $0.role == .through || $0.role == .alight }.map(\.name))
        guard !names.isEmpty else { return [] }
        return (status.disruptions ?? []).filter { d in d.places.contains(where: names.contains) }
    }
}
