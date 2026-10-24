//
//  Progress.swift
//  Clack
//

import Foundation

/// A stop of the ridden part of a leg, with every time in epoch milliseconds.
public nonisolated struct LiveStop: Hashable, Sendable {
    public var stationId: String
    public var name: String
    public var lat: Double
    public var lon: Double
    public var schedArr: Double?
    public var schedDep: Double?
    public var actualArr: Double?
    public var actualDep: Double?
    public var estimatedArr: Double?
    public var estimatedDep: Double?
    public var platform: String?
    public var canceled: Bool

    public init(
        stationId: String, name: String? = nil, lat: Double, lon: Double,
        schedArr: Double? = nil, schedDep: Double? = nil, actualArr: Double? = nil, actualDep: Double? = nil,
        estimatedArr: Double? = nil, estimatedDep: Double? = nil, platform: String? = nil, canceled: Bool = false
    ) {
        self.stationId = stationId
        self.name = name ?? stationId
        self.lat = lat
        self.lon = lon
        self.schedArr = schedArr
        self.schedDep = schedDep
        self.actualArr = actualArr
        self.actualDep = actualDep
        self.estimatedArr = estimatedArr
        self.estimatedDep = estimatedDep
        self.platform = platform
        self.canceled = canceled
    }
}

public nonisolated struct GpsFix: Hashable, Sendable {
    public var lat: Double
    public var lon: Double
    public var at: Double
    public var bearing: Double?
    public var speedKmh: Double?
    /// When the speed was read, if earlier than the fix (a fix that came without one keeps the last reading).
    public var speedAt: Double?

    public init(lat: Double, lon: Double, at: Double, bearing: Double? = nil, speedKmh: Double? = nil, speedAt: Double? = nil) {
        self.lat = lat
        self.lon = lon
        self.at = at
        self.bearing = bearing
        self.speedKmh = speedKmh
        self.speedAt = speedAt
    }
}

public nonisolated struct LiveView: Hashable, Sendable {
    public var status: LiveStatus
    public var prevStopId: String?
    public var nextStopId: String?
    /// Expected time at the next stop.
    public var eta: Double?
    public var arrivalEta: Double?
    public var arrivalDelayMin: Int?
    public var progress: Double?
    public var lat: Double?
    public var lon: Double?
    public var bearing: Double?
    public var speedKmh: Double?
    public var positionSource: PositionSource?
    public var positionAt: Double?

    public init(status: LiveStatus, prevStopId: String? = nil, nextStopId: String? = nil, eta: Double? = nil, arrivalEta: Double? = nil, arrivalDelayMin: Int? = nil, progress: Double? = nil, lat: Double? = nil, lon: Double? = nil, bearing: Double? = nil, speedKmh: Double? = nil, positionSource: PositionSource? = nil, positionAt: Double? = nil) {
        self.status = status
        self.prevStopId = prevStopId
        self.nextStopId = nextStopId
        self.eta = eta
        self.arrivalEta = arrivalEta
        self.arrivalDelayMin = arrivalDelayMin
        self.progress = progress
        self.lat = lat
        self.lon = lon
        self.bearing = bearing
        self.speedKmh = speedKmh
        self.positionSource = positionSource
        self.positionAt = positionAt
    }
}

/// Where a tracked train is (DESIGN §9). The same pure functions the server's live tracker runs
/// (`packages/shared/src/progress.ts`); the app uses them to keep the train moving by itself when the connection
/// drops. Times are epoch milliseconds, distances metres.
public nonisolated enum Progress {
    /// A speed is shown only from a fix this fresh (fixes come every ~30 s).
    public static let speedFreshMs: Double = 60_000
    /// Boarding starts this long before departure (DESIGN §9.3).
    public static let boardingMs: Double = 30 * 60_000
    /// A train this far from the stop you board at, and no further along your ride than its start, hasn't reached you.
    public static let approachM: Double = 2000
    /// Boarding starts a little before the train's expected arrival at your stop.
    public static let reachedSlackMs: Double = 2 * 60_000
    /// A GPS fix older than this isn't shown as live.
    public static let gpsFreshMs: Double = 2 * 60_000
    /// After the GPS goes quiet the train is carried on from its last fix at its last speed for this long, never past
    /// the next stop; after that the timetable estimate takes over again.
    public static let deadReckoningMs: Double = 5 * 60_000
    /// The server sends a live update every 20 s; after this long without one, the phone works it out itself.
    public static let localAfterMs: Double = 60_000

    private static func haversineM(_ lat1: Double, _ lon1: Double, _ lat2: Double, _ lon2: Double) -> Double {
        let rad = Double.pi / 180
        let a = pow(sin((lat2 - lat1) * rad / 2), 2) + cos(lat1 * rad) * cos(lat2 * rad) * pow(sin((lon2 - lon1) * rad / 2), 2)
        return 2 * 6_371_008.8 * asin(a.squareRoot())
    }

    /// A speed worth showing: from a fresh fix that passed the server's checks.
    public static func shownSpeed(_ fix: GpsFix?, now: Double) -> Double? {
        guard let fix, now - (fix.speedAt ?? fix.at) <= speedFreshMs else { return nil }
        return fix.speedKmh
    }

    public struct ExpectedTime: Hashable, Sendable {
        public var arr: Double?
        public var dep: Double?

        public init(arr: Double? = nil, dep: Double? = nil) {
            self.arr = arr
            self.dep = dep
        }
    }

    /// Best-known times at each ridden stop: actual, else Trafikverket's estimate, else the timetable shifted by the
    /// latest known delay (a train 5 min late at Hallsberg is probably 5 min late at Örebro too).
    public static func expectedTimes(_ stops: [LiveStop]) -> [ExpectedTime] {
        var delay: Double = 0
        return stops.map { stop in
            let knownArr = stop.actualArr ?? stop.estimatedArr
            let arr = knownArr ?? stop.schedArr.map { $0 + delay }
            if let schedArr = stop.schedArr, let knownArr { delay = max(0, knownArr - schedArr) }
            var dep = stop.actualDep ?? stop.estimatedDep ?? stop.schedDep.map { $0 + delay }
            // A train can't leave before it arrives.
            if let d = dep, let a = arr, d < a { dep = a }
            if let schedDep = stop.schedDep, let knownDep = stop.actualDep ?? stop.estimatedDep { delay = max(0, knownDep - schedDep) }
            return ExpectedTime(arr: arr, dep: dep)
        }
    }

    /// Cumulative distance along the line at each point, metres.
    public static func cumulative(_ line: [LatLon]) -> [Double] {
        var out: [Double] = [0]
        if line.count > 1 {
            for i in 1..<line.count {
                out.append(out[i - 1] + haversineM(line[i - 1].lat, line[i - 1].lon, line[i].lat, line[i].lon))
            }
        }
        return out
    }

    /// Distance along the line of the closest point to `p`, searching from `fromM` onwards (stops come in order).
    public static func locate(_ line: [LatLon], _ cum: [Double], lat: Double, lon: Double, from fromM: Double = 0) -> Double {
        var best = Double.infinity
        var at = fromM
        let kx = cos(lat * Double.pi / 180)
        if line.count > 1 {
            for i in 1..<line.count {
                if cum[i] < fromM { continue }
                let a = line[i - 1]
                let b = line[i]
                let ax = (a.lon - lon) * kx
                let ay = a.lat - lat
                let dx = (b.lon - a.lon) * kx
                let dy = b.lat - a.lat
                let l2 = dx * dx + dy * dy
                let t = l2 != 0 ? max(0, min(1, -(ax * dx + ay * dy) / l2)) : 0
                let d = hypot(ax + t * dx, ay + t * dy)
                if d < best {
                    best = d
                    at = cum[i - 1] + t * (cum[i] - cum[i - 1])
                }
            }
        }
        return max(at, fromM)
    }

    /// Point and bearing at a distance along the line.
    public static func pointAt(_ line: [LatLon], _ cum: [Double], _ m: Double) -> (lat: Double, lon: Double, bearing: Double) {
        var i = 1
        while i < line.count - 1 && cum[i] < m { i += 1 }
        let a = line[i - 1]
        let b = i < line.count ? line[i] : a
        let span = cum[i] - cum[i - 1]
        let t = span > 0 ? min(1, max(0, (m - cum[i - 1]) / span)) : 0
        let lat = a.lat + t * (b.lat - a.lat)
        let lon = a.lon + t * (b.lon - a.lon)
        let rad = Double.pi / 180
        let y = sin((b.lon - a.lon) * rad) * cos(b.lat * rad)
        let x = cos(a.lat * rad) * sin(b.lat * rad) - sin(a.lat * rad) * cos(b.lat * rad) * cos((b.lon - a.lon) * rad)
        let bearing = (atan2(y, x) * 180 / Double.pi + 360).truncatingRemainder(dividingBy: 360)
        return (lat, lon, bearing)
    }

    /// The live view of a leg from its ridden stops (board … alight), the route line and an optional GPS fix.
    /// Without fresh GPS the position is estimated: constant speed between the last stop left and the next one.
    public static func liveView(stops: [LiveStop], line: [LatLon], gps: GpsFix?, now: Double) -> LiveView {
        let times = expectedTimes(stops)
        let board = stops[0]
        let alight = stops[stops.count - 1]
        let lastTimes = times[times.count - 1]
        let depAt = times[0].dep ?? times[0].arr ?? 0
        let arrAt = lastTimes.arr ?? lastTimes.dep ?? 0
        let arrivalDelayMin = Delay.minutes(
            advertised: alight.schedArr ?? alight.schedDep,
            actual: alight.actualArr ?? alight.estimatedArr ?? (alight.schedArr == nil ? nil : lastTimes.arr)
        )
        var base = LiveView(
            status: .scheduled, prevStopId: nil, nextStopId: board.stationId, eta: depAt != 0 ? depAt : nil,
            arrivalEta: arrAt != 0 ? arrAt : nil, arrivalDelayMin: arrivalDelayMin, progress: 0, lat: nil, lon: nil,
            bearing: nil, speedKmh: nil, positionSource: nil, positionAt: nil
        )
        if board.canceled || alight.canceled {
            base.status = .cancelled
            base.progress = nil
            return base
        }

        // Where the train is relative to the stop you board at. A train that started earlier is on its way to you until it
        // gets there: not boarding (however close the departure time), and not departed because a late estimate passed.
        let cum = cumulative(line)
        let total = cum.last ?? 0
        let gpsFresh = gps.map { now - $0.at <= gpsFreshMs } ?? false
        var upstream = false
        if gpsFresh, let gps, line.count > 1 {
            upstream = haversineM(gps.lat, gps.lon, board.lat, board.lon) > approachM && locate(line, cum, lat: gps.lat, lon: gps.lon) < 500
        }
        let arrBoard = times[0].arr
        let reached = board.actualArr != nil || arrBoard == nil || now >= arrBoard! - reachedSlackMs

        let departed = board.actualDep != nil || (now >= depAt && !upstream)
        let arrived = alight.actualArr != nil || (now >= arrAt && arrAt > 0)
        if arrived {
            base.status = .arrived
            base.prevStopId = alight.stationId
            base.nextStopId = nil
            base.eta = nil
            base.progress = 1
            base.lat = alight.lat
            base.lon = alight.lon
            base.positionSource = nil
            return base
        }
        if !departed {
            let inWindow = now >= depAt - boardingMs
            let approaching = upstream || (inWindow && !reached)
            base.status = approaching ? .approaching : inWindow ? .boarding : .scheduled
            if approaching { base.eta = arrBoard ?? depAt }
            // On its way to you, and seen: show where it is.
            if upstream, let gps {
                base.lat = gps.lat
                base.lon = gps.lon
                base.bearing = gps.bearing
                base.speedKmh = shownSpeed(gps, now: now)
                base.positionSource = .gps
                base.positionAt = gps.at
            }
            return base
        }

        // Last stop the train has reached and the next one ahead.
        var prev = 0
        for i in stops.indices {
            let t = times[i]
            let reached = stops[i].actualArr != nil || stops[i].actualDep != nil || (t.arr ?? t.dep ?? .infinity) <= now
            if reached { prev = i }
        }
        let next = min(prev + 1, stops.count - 1)
        let prevT = times[prev]
        let leftPrev = stops[prev].actualDep != nil || (prevT.dep ?? prevT.arr ?? 0) <= now
        let status: LiveStatus = leftPrev ? .enRoute : .atStop

        var stopM: [Double] = []
        for stop in stops {
            stopM.append(line.count > 1 ? locate(line, cum, lat: stop.lat, lon: stop.lon, from: stopM.last ?? 0) : 0)
        }

        var m: Double
        if !leftPrev {
            m = stopM[prev]
        } else {
            let from = prevT.dep ?? prevT.arr ?? now
            let to = times[next].arr ?? times[next].dep ?? from
            let f = to > from ? min(1, max(0, (now - from) / (to - from))) : 1
            m = stopM[prev] + f * (stopM[next] - stopM[prev])
        }
        var out = base
        out.status = status
        out.prevStopId = stops[prev].stationId
        out.nextStopId = status == .atStop ? (prev + 1 < stops.count ? stops[prev + 1].stationId : nil) : stops[next].stationId
        out.eta = status == .atStop ? (prev + 1 < times.count ? times[prev + 1].arr : nil) : (times[next].arr ?? times[next].dep)

        let fresh = gps.map { now - $0.at <= gpsFreshMs } ?? false
        if fresh, let gps, line.count > 1 {
            let gm = locate(line, cum, lat: gps.lat, lon: gps.lon)
            out.progress = total != 0 ? gm / total : nil
            out.lat = gps.lat
            out.lon = gps.lon
            out.bearing = gps.bearing
            out.speedKmh = shownSpeed(gps, now: now)
            out.positionSource = .gps
            out.positionAt = gps.at
            return out
        }
        if fresh, let gps {
            out.lat = gps.lat
            out.lon = gps.lon
            out.bearing = gps.bearing
            out.speedKmh = shownSpeed(gps, now: now)
            out.positionSource = .gps
            out.positionAt = gps.at
            out.progress = nil
            return out
        }
        if line.count < 2 {
            out.progress = nil
            return out
        }
        if let gps, status == .enRoute, now - gps.at <= 30 * 60_000 {
            // Where the GPS last put it: an estimate never moves the train back behind that.
            let last = locate(line, cum, lat: gps.lat, lon: gps.lon)
            let cap = stopM[next]
            let recent = now - gps.at <= deadReckoningMs && (gps.speedKmh ?? 0) > 0
            let carried = recent ? last + ((gps.speedKmh ?? 0) / 3.6) * ((now - gps.at) / 1000) : m
            m = min(cap, max(carried, last))
        }
        let p = pointAt(line, cum, m)
        out.progress = total != 0 ? m / total : nil
        out.lat = p.lat
        out.lon = p.lon
        out.bearing = p.bearing
        out.positionSource = .estimated
        return out
    }

    /// Where the train is now from what the phone already has: the trip's stops and times, its track, and the last
    /// live report (its GPS fix and speed). The same rules as the server: on from the last fix at its last speed for
    /// a few minutes, never past the next stop, then by the timetable and the last known delays.
    public static func localLive(leg: LegDetail, live: LiveStateRow, now: Double) -> LiveStateRow {
        let ridden = leg.stops.filter { $0.role.isRidden }
        let stops = ridden.map { s in
            LiveStop(
                stationId: s.stationId, name: s.name, lat: s.lat, lon: s.lon, schedArr: s.schedArr?.ms,
                schedDep: s.schedDep?.ms, actualArr: s.actualArr?.ms, actualDep: s.actualDep?.ms,
                estimatedArr: s.estimatedArr?.ms, estimatedDep: s.estimatedDep?.ms, platform: s.platform,
                canceled: s.canceled
            )
        }
        if stops.isEmpty { return live }
        let line: [LatLon] = leg.geometry.map(Polyline.decode) ?? stops.map { LatLon($0.lat, $0.lon) }
        var gps: GpsFix?
        if live.positionSource == .gps, let lat = live.lat, let lon = live.lon, let at = live.positionAt?.ms {
            gps = GpsFix(lat: lat, lon: lon, at: at, bearing: live.bearing, speedKmh: live.speedKmh)
        }
        let v = liveView(stops: stops, line: line, gps: gps, now: now)
        return LiveStateRow(
            legId: live.legId, updatedAt: live.updatedAt, status: v.status, lat: v.lat, lon: v.lon, bearing: v.bearing,
            speedKmh: v.speedKmh, positionSource: v.positionSource, positionAt: v.positionAt.map { Instant(ms: $0) },
            progress: v.progress, prevStopId: v.prevStopId, nextStopId: v.nextStopId, eta: v.eta.map { Instant(ms: $0) },
            arrivalEta: v.arrivalEta.map { Instant(ms: $0) }, arrivalDelayMin: v.arrivalDelayMin,
            reportedAt: live.reportedAt, localEstimate: true
        )
    }
}
