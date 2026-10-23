//
//  Landing.swift
//  Clack
//

import Foundation

enum PrimaryTab: String, CaseIterable, Sendable {
    case trips, explore, passport
}

/// Where the app opens (product brief §4): deterministic rules, applied once per app start and never while you're
/// using the app. A port of `apps/web/src/landing.ts`. Times are epoch milliseconds.
nonisolated enum Landing {
    /// A departure this close (or a train running now) makes the app open on Trips.
    static let attentionWindowMs: Double = 3 * 3_600_000
    /// A late train still counts as running until this long after its expected arrival when nothing better is known.
    static let arrivalGraceMs: Double = 10 * 60_000

    /// The parts of a leg the rules look at.
    struct LegTimes: Sendable {
        var schedDep: Double?
        var schedArr: Double?
        var actualDep: Double?
        var actualArr: Double?
        var depDelayMin: Int?
        var canceled: Bool
        var liveStatus: LiveStatus?
        var liveArrivalEta: Double?

        init(
            schedDep: Double? = nil, schedArr: Double? = nil, actualDep: Double? = nil, actualArr: Double? = nil,
            depDelayMin: Int? = nil, canceled: Bool = false, liveStatus: LiveStatus? = nil, liveArrivalEta: Double? = nil
        ) {
            self.schedDep = schedDep
            self.schedArr = schedArr
            self.actualDep = actualDep
            self.actualArr = actualArr
            self.depDelayMin = depDelayMin
            self.canceled = canceled
            self.liveStatus = liveStatus
            self.liveArrivalEta = liveArrivalEta
        }

        init(_ leg: Leg) {
            self.init(
                schedDep: leg.schedDep?.ms, schedArr: leg.schedArr?.ms, actualDep: leg.actualDep?.ms,
                actualArr: leg.actualArr?.ms, depDelayMin: leg.depDelayMin, canceled: leg.canceled,
                liveStatus: leg.live?.status, liveArrivalEta: leg.live?.arrivalEta?.ms
            )
        }
    }

    /// Best-known departure and arrival: actual, else live estimate, else timetable shifted by the known delay.
    private static func times(_ leg: LegTimes) -> (dep: Double?, arr: Double?) {
        let dep = leg.actualDep ?? leg.schedDep.map { $0 + Double(leg.depDelayMin ?? 0) * 60_000 }
        let arr = leg.actualArr ?? leg.liveArrivalEta ?? leg.schedArr
        return (dep, arr)
    }

    /// On the train now: the tracker says so, or the clock is between departure and (expected) arrival.
    static func isActive(_ leg: LegTimes, now: Double) -> Bool {
        if leg.canceled || leg.liveStatus == .cancelled { return false }
        if leg.liveStatus == .enRoute || leg.liveStatus == .atStop { return true }
        if leg.liveStatus == .arrived || leg.actualArr != nil { return false }
        let (dep, arr) = times(leg)
        guard let dep, let arr else { return false }
        return now >= dep && now <= arr + arrivalGraceMs
    }

    /// Departing within the attention window (cancelled ones too: that's news you need). Legs without times never count.
    static func isImminent(_ leg: LegTimes, now: Double, windowMs: Double = attentionWindowMs) -> Bool {
        guard let dep = times(leg).dep else { return false }
        return dep > now && dep - now <= windowMs
    }

    static func resolve(legs: [LegTimes], now: Double, lastTab: PrimaryTab?, windowMs: Double = attentionWindowMs) -> PrimaryTab {
        if legs.contains(where: { isActive($0, now: now) }) { return .trips }
        if legs.contains(where: { isImminent($0, now: now, windowMs: windowMs) }) { return .trips }
        return lastTab ?? .explore
    }

    private static let lastTabKey = "clack.lastTab"

    static func readLastTab(_ defaults: UserDefaults = .standard) -> PrimaryTab? {
        defaults.string(forKey: lastTabKey).flatMap(PrimaryTab.init(rawValue:))
    }

    static func saveLastTab(_ tab: PrimaryTab, _ defaults: UserDefaults = .standard) {
        defaults.set(tab.rawValue, forKey: lastTabKey)
    }
}
