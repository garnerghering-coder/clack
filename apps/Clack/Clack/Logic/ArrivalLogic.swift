//
//  ArrivalLogic.swift
//  Clack
//

import Foundation

/// When the arrival celebration is due, and what it totals up (owner, 2026-10-23). A journey is the legs that share
/// a `journeyId`; the celebration is for its last leg arriving, once. Times are epoch milliseconds.
nonisolated enum ArrivalLogic {
    /// How long after arriving the celebration can still appear.
    static let windowMs: Double = 2 * 3_600_000
    /// A train with no live arrival counts as arrived this long after its expected arrival.
    static let graceMs: Double = 2 * 60_000

    /// The last leg of each journey (a leg with no journey stands alone), by departure.
    static func finalLegs(_ legs: [Leg]) -> [Leg] {
        var groups: [String: [Leg]] = [:]
        for leg in legs { groups[leg.journeyId ?? leg.id, default: []].append(leg) }
        return groups.values.compactMap { $0.max { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) } }
    }

    /// When the leg arrived, or nil if it hasn't yet.
    static func arrivedAt(_ leg: Leg, now: Double) -> Double? {
        if let actual = leg.actualArr?.ms { return actual }
        if leg.live?.status == .arrived, let eta = leg.live?.arrivalEta?.ms ?? leg.schedArr?.ms { return min(eta, now) }
        guard let expected = TripsLogic.expected(leg).arr, now >= expected + graceMs else { return nil }
        return expected + graceMs
    }

    /// Final legs whose arrival is still ahead: the ones to watch, so a trip logged after it ended never celebrates.
    static func toWatch(_ legs: [Leg], now: Double) -> [String] {
        finalLegs(legs).filter { !$0.canceled && arrivedAt($0, now: now) == nil }.map(\.id)
    }

    /// The final leg that is due a celebration: watched, arrived within the window, ridden, and not shown before.
    static func due(_ legs: [Leg], now: Double, watched: Set<String>, shown: Set<String>) -> Leg? {
        finalLegs(legs)
            .filter { leg in
                guard !leg.canceled, leg.ride != .notTaken, watched.contains(leg.id), !shown.contains(leg.id),
                      let arrived = arrivedAt(leg, now: now) else { return false }
                return now - arrived <= windowMs
            }
            .min { (arrivedAt($0, now: now) ?? 0) < (arrivedAt($1, now: now) ?? 0) }
    }

    struct Summary: Equatable, Sendable {
        let minutesOnBoard: Double
        /// Nil unless every leg has a distance.
        let distanceM: Double?
        let trains: Int
        let arrDelayMin: Int?
    }

    static func summary(_ legs: [Leg]) -> Summary {
        let minutes = legs.reduce(0.0) { sum, leg in
            let times = TripsLogic.expected(leg)
            guard let dep = times.dep, let arr = times.arr, arr > dep else { return sum }
            return sum + (arr - dep) / 60_000
        }
        let distances = legs.compactMap(\.distanceM)
        let last = legs.max { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
        return Summary(
            minutesOnBoard: minutes,
            distanceM: !legs.isEmpty && distances.count == legs.count ? distances.reduce(0, +) : nil,
            trains: legs.count,
            arrDelayMin: last?.arrDelayMin
        )
    }

    /// One trip's worth of progress for the whole journey: medals unioned, each family moved from the smallest
    /// "before" to the largest "after", firsts without repeats.
    static func merge(_ parts: [TripProgress]) -> TripProgress {
        var unlocked: [Milestone] = []
        for milestone in parts.flatMap(\.unlocked) where !unlocked.contains(where: { $0.family == milestone.family && $0.target == milestone.target }) {
            unlocked.append(milestone)
        }
        var order: [MilestoneFamily] = []
        var moved: [MilestoneFamily: TripProgress.Moved] = [:]
        for m in parts.flatMap(\.moved) {
            if let have = moved[m.family] {
                moved[m.family] = .init(family: m.family, before: min(have.before, m.before), after: max(have.after, m.after), target: m.target)
            } else {
                moved[m.family] = m
                order.append(m.family)
            }
        }
        let reached = Set(unlocked.map(\.family))
        let stations = Array(NSOrderedSet(array: parts.compactMap(\.firsts).flatMap(\.stations))) as? [String] ?? []
        let countries = Array(NSOrderedSet(array: parts.compactMap(\.firsts).flatMap(\.countries))) as? [String] ?? []
        let op = parts.compactMap(\.firsts).compactMap(\.operator).first
        return TripProgress(
            counted: parts.contains { $0.counted },
            unlocked: unlocked,
            moved: order.compactMap { reached.contains($0) ? nil : moved[$0] },
            firsts: .init(stations: stations, operator: op, countries: countries)
        )
    }
}
