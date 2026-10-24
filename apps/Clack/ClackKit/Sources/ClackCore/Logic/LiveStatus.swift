//
//  LiveStatus.swift
//  Clack
//

import Foundation

/// Live tracking helpers: freshness, the status shown on a trip, and "updated 12 s ago" (apps/web/src/live.ts).
/// Times are epoch milliseconds.
public nonisolated enum LiveRules {
    /// Live data older than this shows as stale (DESIGN §9.5).
    public static let staleMs: Double = 2 * 60_000
    /// Speeds come with GPS fixes about every 30 s; one older than this isn't shown.
    public static let speedFreshMs: Double = 60_000

    /// When the trip's data last came from the feeds (our server ticks on even when they don't answer).
    public static func dataAt(_ live: LiveStateRow) -> Double {
        live.reportedAt?.ms ?? live.updatedAt.ms
    }

    public static func isFresh(_ live: LiveStateRow?, now: Double) -> Bool {
        guard let live else { return false }
        return now - dataAt(live) < staleMs
    }

    /// Is this leg being followed live right now (tracked and not yet arrived)?
    public static func isLive(_ live: LiveStateRow?) -> Bool {
        guard let live else { return false }
        return live.status == .approaching || live.status == .boarding || live.status == .enRoute || live.status == .atStop
    }

    /// The status written on a trip (DESIGN §6): Upcoming, Boarding, Live, Arrived or Cancelled.
    public enum TripStatus: String, Sendable {
        case planned, approaching, boarding, live, completed, cancelled
    }

    /// When the trip leaves: the actual time, else the timetable plus the delay known so far (a train 20 minutes late
    /// into your stop leaves 20 minutes late).
    public static func expectedDeparture(_ leg: Leg) -> Double {
        if let actual = leg.actualDep?.ms { return actual }
        return (leg.schedDep?.ms ?? 0) + Double(max(0, leg.depDelayMin ?? 0)) * 60_000
    }

    public static func statusKey(_ leg: Leg, live: LiveStateRow?, now: Double) -> TripStatus {
        if leg.canceled || live?.status == .cancelled { return .cancelled }
        if let live, isFresh(live, now: now) {
            if live.status == .approaching { return .approaching }
            if live.status == .scheduled { return .planned }
            if live.status == .boarding { return .boarding }
            if live.status == .enRoute || live.status == .atStop { return .live }
            if live.status == .arrived { return .completed }
        }
        let dep = expectedDeparture(leg)
        let arr = leg.actualArr?.ms ?? leg.schedArr?.ms ?? 0
        if leg.status != .planned || now >= arr { return .completed }
        if now >= dep { return .live }
        if dep - now <= 30 * 60_000 { return .boarding }
        return .planned
    }

    /// "Just now", "12 s ago", "3 min ago".
    @MainActor
    public static func ago(_ l10n: L10n, then: Double, now: Double) -> String {
        let seconds = Int(max(0, ((now - then) / 1000).rounded()))
        if seconds < 5 { return l10n.t("live.justNow") }
        if seconds < 90 { return l10n.t("live.secondsAgo", ["n": String(seconds)]) }
        return l10n.t("live.minutesAgo", ["n": String(Int((Double(seconds) / 60).rounded()))])
    }
}
