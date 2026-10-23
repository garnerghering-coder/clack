//
//  OfflineEstimate.swift
//  Clack
//

import Foundation

/// Where a trip is when the server isn't telling us (owner, 2026-10-24: the app should work offline, estimating progress from the
/// timetable and the last delays). The same rules as the server's live view (`Progress.liveView`), run on the phone.
nonisolated enum OfflineEstimate {
    /// How long before departure an estimate starts to say anything (boarding is 30 minutes before).
    static let leadMs: Double = 35 * 60_000
    /// How long after the arrival one is still shown.
    static let tailMs: Double = 10 * 60_000

    /// An estimate for a leg, or nil when there is nothing to estimate (finished, cancelled, too far off, or the server is giving
    /// fresh updates). `detail` is the cached trip (stops and geometry), when there is one; without it the estimate uses the leg's
    /// times alone, with no position. Called when the phone is offline, or when updates for a tracked trip have stopped.
    static func live(for leg: Leg, detail: LegDetail?, offline: Bool, now: Double) -> LiveStateRow? {
        guard !leg.canceled, leg.actualArr == nil else { return nil }
        let times = TripsLogic.expected(leg)
        guard let dep = times.dep, let arr = times.arr, now >= dep - leadMs, now <= arr + tailMs else { return nil }
        if let live = leg.live, now - live.updatedAt.ms <= Progress.localAfterMs { return nil }
        // Online and never tracked: the timetable says what it says, there is nothing to correct.
        guard offline || leg.live != nil else { return nil }
        let base = leg.live ?? blank(leg.id)
        if let detail, detail.stops.filter({ $0.role.isRidden }).count > 1 { return Progress.localLive(leg: detail, live: base, now: now) }
        return fromTimes(leg, base: base, dep: dep, arr: arr, now: now)
    }

    /// A row with nothing known, to start an estimate from.
    static func blank(_ legId: String) -> LiveStateRow {
        LiveStateRow(
            legId: legId, updatedAt: Instant(ms: 0), status: .scheduled, lat: nil, lon: nil, bearing: nil, speedKmh: nil,
            positionSource: nil, positionAt: nil, progress: nil, prevStopId: nil, nextStopId: nil, eta: nil, arrivalEta: nil,
            arrivalDelayMin: nil, reportedAt: nil
        )
    }

    /// Without stops: the status from the same rules, and the share of the ride gone by the clock.
    private static func fromTimes(_ leg: Leg, base: LiveStateRow, dep: Double, arr: Double, now: Double) -> LiveStateRow {
        let stops = [
            LiveStop(stationId: leg.originStationId, lat: 0, lon: 0, schedDep: leg.schedDep?.ms, actualDep: leg.actualDep?.ms, estimatedDep: dep),
            LiveStop(stationId: leg.destStationId, lat: 0, lon: 0, schedArr: leg.schedArr?.ms, estimatedArr: arr),
        ]
        let v = Progress.liveView(stops: stops, line: [], gps: nil, now: now)
        let running = v.status == .enRoute || v.status == .atStop
        let progress: Double? = v.status == .arrived ? 1 : running ? min(1, max(0, (now - dep) / max(arr - dep, 1))) : v.progress
        return LiveStateRow(
            legId: base.legId, updatedAt: base.updatedAt, status: v.status, lat: nil, lon: nil, bearing: nil, speedKmh: nil,
            positionSource: nil, positionAt: nil, progress: progress, prevStopId: nil, nextStopId: nil,
            eta: v.eta.map { Instant(ms: $0) }, arrivalEta: Instant(ms: arr), arrivalDelayMin: v.arrivalDelayMin,
            reportedAt: base.reportedAt, localEstimate: true
        )
    }
}
