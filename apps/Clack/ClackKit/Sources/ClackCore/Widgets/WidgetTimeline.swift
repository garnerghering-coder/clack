//
//  WidgetTimeline.swift
//  Clack
//
//  When the widgets redraw and what each redraw shows, from one `WidgetSnapshot` and the clock. Plain functions, so the
//  rules are tested without WidgetKit. Times are epoch milliseconds.
//

import Foundation

public nonisolated enum WidgetTimeline {
    static let minute: Double = 60_000
    static let hour: Double = 3_600_000

    /// How far ahead a Next journey timeline is planned.
    public static let horizonMs: Double = 3 * hour
    /// Entries every minute from this long before the first departure...
    public static let denseBeforeMs: Double = 30 * minute
    /// ...until this long after the last arrival; then the widget moves on.
    public static let afterArrivalMs: Double = 2 * minute
    /// A journey that has ended stays on the widget, as arrived, this long when nothing else is coming
    /// (`TripsLogic.recentArrivalMs`, the Trips tab's rule).
    public static let arrivedShownMs: Double = TripsLogic.recentArrivalMs
    /// The longest a Next journey timeline runs before it is fetched again.
    public static let maxReloadMs: Double = 30 * minute
    /// Older than this, a widget says when it was updated.
    public static let staleMs: Double = 30 * minute

    // MARK: which journey

    /// What the Next journey widget shows at a moment.
    public struct Shown: Equatable, Sendable {
        public var legs: [WidgetSnapshot.Leg]
        public var moment: JourneyMoment
        /// The leg the widget talks about: the one ahead or under way, else (arrived) the last.
        public var leg: WidgetSnapshot.Leg? { moment.legIndex.map { legs[$0] } ?? legs.last }
    }

    /// The end of a journey for the widget: its last arrival plus two minutes.
    public static func end(_ legs: [WidgetSnapshot.Leg]) -> Double? { legs.last.map { $0.arrAt + afterArrivalMs } }

    /// The featured journey until it ends; then the next one; with nothing next, the one that ended (as arrived) for 6
    /// hours; then nothing.
    public static func shown(_ snapshot: WidgetSnapshot, at now: Double) -> Shown? {
        let journeys = [snapshot.journey, snapshot.nextJourney].filter { !$0.isEmpty }
        if let running = journeys.first(where: { (end($0) ?? 0) > now }) {
            return Shown(legs: running, moment: JourneyMoment.at(now, legs: running))
        }
        if let ended = journeys.last, let last = ended.last, now - last.arrAt < arrivedShownMs {
            return Shown(legs: ended, moment: .finished)
        }
        return nil
    }

    // MARK: the countdown

    /// "Departs in ..." as the widget words it: to the minute within 30 minutes, by the quarter hour within 6 hours, by the
    /// hour within a day, by the day beyond. Always rounded down, so it never says there is more time than there is.
    public enum Countdown: Equatable, Sendable {
        case minutes(Int)
        case hours(Int)
        case days(Int)
    }

    /// Whole minutes left, counted up: 90 s is "2" (as `JourneyMoment` counts spare minutes); 0 once it has left.
    static func minutesLeft(until dep: Double, now: Double) -> Int { max(0, Int(((dep - now) / minute).rounded(.up))) }

    static func countdown(minutesLeft m: Int) -> Countdown {
        switch m {
        case ...30: .minutes(m)
        case ...360: .minutes(m / 15 * 15)
        case ...1440: .hours(m / 60)
        default: .days(m / 1440)
        }
    }

    public static func countdown(to dep: Double, now: Double) -> Countdown { countdown(minutesLeft: minutesLeft(until: dep, now: now)) }

    /// `45 min`, `2h 15m`, `7h`, `2d` (the Trips tab's short forms).
    public static func text(_ c: Countdown) -> String {
        switch c {
        case .minutes(let m) where m >= 60: m % 60 == 0 ? "\(m / 60)h" : "\(m / 60)h \(m % 60)m"
        case .minutes(let m): "\(m) min"
        case .hours(let h): "\(h)h"
        case .days(let d): "\(d)d"
        }
    }

    /// The moments after `now` and up to `until` when the countdown to `dep` changes its wording.
    static func countdownChanges(to dep: Double, after now: Double, until: Double) -> [Double] {
        // The minutes left are n from dep - n min (inclusive) to dep - (n - 1) min.
        var out: [Double] = []
        var n = minutesLeft(until: dep, now: now) - 1
        while n >= 0 {
            let at = dep - Double(n) * minute
            if at > until { break }
            if at > now, countdown(minutesLeft: n) != countdown(minutesLeft: n + 1) { out.append(at) }
            n -= 1
        }
        return out
    }

    // MARK: Next journey

    /// The moments the journey's state changes: a departure, an arrival, the start of the minute-by-minute part, its end
    /// and the end of the arrived state.
    static func phaseChanges(_ legs: [WidgetSnapshot.Leg]) -> [Double] {
        guard let first = legs.first, let last = legs.last else { return [] }
        return [first.depAt - denseBeforeMs, last.arrAt + afterArrivalMs, last.arrAt + arrivedShownMs]
            + legs.flatMap { [$0.depAt, $0.arrAt] }
    }

    /// When the Next journey widget redraws, from `now` (always the first) up to 3 hours ahead: every minute from 30 minutes
    /// before a departure to 2 minutes after the arrival, and otherwise only when the countdown's wording or the journey's
    /// state changes.
    public static func journeyEntries(_ snapshot: WidgetSnapshot, now: Double) -> [Double] {
        let until = now + horizonMs
        var dates = Set<Double>()
        for legs in [snapshot.journey, snapshot.nextJourney] where !legs.isEmpty {
            guard let first = legs.first, let end = end(legs) else { continue }
            for at in phaseChanges(legs) where at > now && at <= until { dates.insert(at) }
            // Minute by minute, on the minute.
            var t = (now / minute).rounded(.down) * minute + minute
            let denseStart = first.depAt - denseBeforeMs
            while t <= min(end, until) {
                if t >= denseStart { dates.insert(t) }
                t += minute
            }
            if first.depAt > now {
                for at in countdownChanges(to: first.depAt, after: now, until: min(until, denseStart)) { dates.insert(at) }
            }
        }
        return [now] + dates.sorted()
    }

    /// When to fetch again: at the next change of state (a departure, an arrival, the start of the last 30 minutes), and at
    /// least every 30 minutes; never sooner than a minute.
    public static func journeyReload(_ snapshot: WidgetSnapshot, now: Double) -> Double {
        let next = (phaseChanges(snapshot.journey) + phaseChanges(snapshot.nextJourney)).filter { $0 > now }.min()
        return max(now + minute, min(next ?? .infinity, now + maxReloadMs))
    }

    /// How much the system should put this widget forward in a Smart Stack: most while a trip runs or is about to, a little
    /// on the day, nothing with no journey.
    public static func relevance(_ snapshot: WidgetSnapshot, at now: Double) -> Float {
        guard let shown = shown(snapshot, at: now), let first = shown.legs.first else { return 0 }
        switch shown.moment {
        case .onTrain, .changing: return 1
        case .before: return first.depAt - now <= denseBeforeMs ? 1 : first.depAt - now <= horizonMs ? 0.5 : 0.1
        case .finished: return now - (shown.legs.last?.arrAt ?? 0) <= afterArrivalMs ? 0.8 : 0.1
        }
    }

    // MARK: Departures

    /// A redraw every minute for 30 minutes, so departed trains drop off; it is fetched again after 15.
    public static func departureEntries(now: Double) -> [Double] {
        let first = (now / minute).rounded(.down) * minute + minute
        return [now] + (0..<30).map { first + Double($0) * minute }
    }

    public static let departuresReloadMs: Double = 15 * minute

    /// The rows still to leave at `now`, soonest first: a train is shown through the minute it leaves.
    public static func departures(_ rows: [WidgetSnapshot.Departure], at now: Double, limit: Int) -> [WidgetSnapshot.Departure] {
        Array(rows.filter { $0.leaves + minute > now }.sorted { $0.time < $1.time }.prefix(limit))
    }

    // MARK: all

    /// Passport, Stats and Year in rail are fetched again after 6 hours (and when the app says a trip has arrived).
    public static let passportReloadMs: Double = 6 * hour

    /// True when the data is old enough that the widget should say when it was updated.
    public static func isStale(_ updatedAt: Double, now: Double) -> Bool { updatedAt > 0 && now - updatedAt > staleMs }
}
