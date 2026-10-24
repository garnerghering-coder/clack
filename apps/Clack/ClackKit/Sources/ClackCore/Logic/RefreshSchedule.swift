//
//  RefreshSchedule.swift
//  Clack
//
//  When the app asks iOS to wake it for a background refresh (`BGAppRefreshTask`), the fallback for when the server's
//  silent pushes don't come: 45 minutes before the next departure, so the trip card, the widgets and the kept copies are
//  fresh as you leave, and otherwise once each morning. iOS treats the time as "not before" and decides itself when (and
//  whether) to run it.
//

import Foundation

public nonisolated enum RefreshSchedule {
    /// The task's identifier (also in the app's Info.plist `BGTaskSchedulerPermittedIdentifiers`).
    public static let identifier = "com.garnerghering.Clack.refresh"
    /// How long before a departure the refresh is asked for.
    public static let leadMs: Double = 45 * 60_000
    /// The soonest a refresh is asked for: iOS doesn't run them more often than this anyway.
    public static let minGapMs: Double = 15 * 60_000
    /// The morning refresh, in the phone's own time zone.
    public static let morningHour = 6

    /// The earliest time (ms since 1970) for the next background refresh: 45 minutes before the next departure, at least
    /// `minGapMs` from now and still before the train leaves; otherwise (or if it comes first) the next morning at 06:00.
    /// Cancelled legs and legs that have left don't count.
    public static func next(_ legs: [Leg], now: Double, timeZone: TimeZone) -> Double {
        let morning = nextMorning(after: now, timeZone: timeZone)
        let beforeDeparture = legs.compactMap { leg -> Double? in
            guard !leg.canceled, leg.actualDep == nil, let dep = TripsLogic.expected(leg).dep, dep > now else { return nil }
            let at = max(dep - leadMs, now + minGapMs)
            return at < dep ? at : nil
        }.min()
        return min(beforeDeparture ?? morning, morning)
    }

    /// The next 06:00 after `now` in `timeZone` (tomorrow's when it is already past six).
    public static func nextMorning(after now: Double, timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let date = Date(timeIntervalSince1970: now / 1000)
        let next = calendar.nextDate(
            after: date, matching: DateComponents(hour: morningHour, minute: 0, second: 0), matchingPolicy: .nextTime
        ) ?? date.addingTimeInterval(24 * 3600)
        return next.timeIntervalSince1970 * 1000
    }
}
