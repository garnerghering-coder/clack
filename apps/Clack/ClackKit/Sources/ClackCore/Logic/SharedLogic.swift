//
//  SharedLogic.swift
//  Clack
//

import Foundation

/// What a follower of a shared journey reads, in words: where it is, when it arrives, whether it is late. The same
/// sentences are on the web page (`apps/server/public/share/share.js`), from the same strings (`share.*`).
@MainActor
public enum SharedLogic {
    /// "Between Katrineholm and Skövde", "Changing trains at Hässleholm C", "Arrived in Göteborg C at 18:47"…
    public static func statusLine(_ j: SharedJourney, l10n: L10n, clock: ClockFormat) -> String {
        let s = j.summary
        guard let first = j.legs.first, let last = j.legs.last else { return "" }
        switch s.phase {
        case .upcoming:
            let time = Format.time(s.departureAt, tz: first.from.tz, clock: clock)
            if let platform = first.depPlatform {
                return l10n.t("share.status.upcomingPlatform", ["time": time, "station": first.from.name, "platform": platform])
            }
            return l10n.t("share.status.upcoming", ["time": time, "station": first.from.name])
        case .underway:
            if let between = s.between { return l10n.t("share.status.underwayBetween", ["from": between.from, "to": between.to]) }
            return l10n.t("share.status.underway")
        case .atChange:
            let station = j.legs.indices.contains(s.legIndex - 1) ? j.legs[s.legIndex - 1].to.name : s.from
            return l10n.t("share.status.atChange", ["station": station])
        case .arrived:
            return l10n.t("share.status.arrived", ["station": s.to, "time": Format.time(s.arrivalAt, tz: last.to.tz, clock: clock)])
        case .cancelled:
            return l10n.t("share.status.cancelled")
        }
    }

    /// "Arrives Göteborg C 18:47, platform 4": nothing once it has arrived or is cancelled.
    public static func arrivalLine(_ j: SharedJourney, l10n: L10n, clock: ClockFormat) -> String? {
        let s = j.summary
        guard s.phase != .arrived, s.phase != .cancelled, let last = j.legs.last else { return nil }
        var values = ["station": s.to, "time": Format.time(s.arrivalAt, tz: last.to.tz, clock: clock)]
        if let platform = s.arrivalPlatform {
            values["platform"] = platform
            return l10n.t("share.arrivesPlatform", values)
        }
        return l10n.t("share.arrives", values)
    }

    /// "On time" or "8 min late"; nil when it isn't known.
    public static func delayWord(_ minutes: Int?, l10n: L10n) -> String? {
        guard let minutes else { return nil }
        return minutes <= 0 ? l10n.t("share.onTime") : l10n.t("share.late", ["min": String(minutes)])
    }

    /// The line over a change: "Change at Hässleholm C · 12 min", or the walk between two stations.
    public static func changeTitle(_ c: SharedJourney.Change, in j: SharedJourney, l10n: L10n) -> String {
        let minutes = c.spareMin.map(String.init) ?? "–"
        guard c.sameStation, j.legs.indices.contains(c.index), j.legs.indices.contains(c.index + 1) else {
            if j.legs.indices.contains(c.index + 1) {
                return l10n.t("share.changeWalk", ["from": j.legs[c.index].to.name, "to": j.legs[c.index + 1].from.name, "min": minutes])
            }
            return c.station
        }
        return l10n.t("share.change", ["station": c.station, "min": minutes])
    }

    /// The trains of the journey a follower follows: each with its number and operating day, from this copy alone.
    public nonisolated static func followBodies(_ j: SharedJourney) -> [FollowBody] {
        j.legs.compactMap { leg in
            guard let number = leg.trainNumber, let date = leg.serviceDate else { return nil }
            return FollowBody(trainNumber: number, serviceDate: date, operatorId: leg.operator?.id, label: "\(leg.from.name) → \(leg.to.name)")
        }
    }

    /// Whether a link for this journey has gone (expired) at this time.
    public nonisolated static func hasExpired(_ j: SharedJourney, now: Double) -> Bool { j.expiresAt <= now }
}
