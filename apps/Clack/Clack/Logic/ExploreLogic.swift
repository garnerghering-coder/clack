//
//  ExploreLogic.swift
//  Clack
//

import Foundation

/// The live map's rules (pages/LiveMapPage.tsx): which trains show, where the selected train's route is cut, how a
/// marker glides, what the status chip says, the train sheet's three sizes.
nonisolated enum ExploreLogic {
    static let products = ["high_speed", "intercity", "regional", "commuter", "night"]
    static let glideMs = 1500.0
    static let staleMs = 60_000.0
    /// A GPS fix older than this is shown as old, not as the train's position now (the server's GPS_FRESH_MS).
    static let gpsFreshMs = 120_000.0

    struct Filters: Equatable, Sendable {
        var products: Set<String> = []
        var operators: Set<String> = []
        var onlyDelayed = false
        var onlyMine = false
        var onlyFollowed = false

        /// What the filter button's badge counts: each product, each operator and each toggle.
        var count: Int { products.count + operators.count + (onlyDelayed ? 1 : 0) + (onlyMine ? 1 : 0) + (onlyFollowed ? 1 : 0) }
    }

    static func followKey(number: String, date: String) -> String { "\(number)|\(date)" }

    static func visible(_ train: LiveTrain, _ f: Filters, followed: Set<String>) -> Bool {
        if f.onlyMine && !train.mine { return false }
        if f.onlyFollowed && !followed.contains(followKey(number: train.number, date: train.date)) { return false }
        if f.onlyDelayed && !((train.delayMin ?? 0) > 5) { return false }
        if !f.products.isEmpty && !(train.product.map(f.products.contains) ?? false) { return false }
        if !f.operators.isEmpty && !(train.operatorId.map(f.operators.contains) ?? false) { return false }
        return true
    }

    /// A moved train is the old one with its position fields replaced.
    static func applying(_ moved: MovedTrain, to train: LiveTrain) -> LiveTrain {
        var t = train
        t.lat = moved.lat
        t.lon = moved.lon
        t.bearing = moved.bearing
        t.speedKmh = moved.speedKmh
        t.at = Instant(ms: moved.at)
        t.estimated = moved.estimated
        return t
    }

    // MARK: the selected train's route

    /// The point on a line closest to `p` (projected onto its segments), searching from segment `from` on.
    static func nearestOnLine(_ line: [LatLon], _ p: LatLon, from: Int = 0) -> (index: Int, point: LatLon) {
        guard line.count > 1 else { return (0, line.first ?? p) }
        let kx = cos(p.lat * .pi / 180)
        var best = (index: min(from, line.count - 2), point: line[min(from, line.count - 1)], d: Double.infinity)
        var i = from
        while i < line.count - 1 {
            let (a, b) = (line[i], line[i + 1])
            let dx = (b.lon - a.lon) * kx
            let dy = b.lat - a.lat
            let len = dx * dx + dy * dy
            let t = len > 0 ? max(0, min(1, (((p.lon - a.lon) * kx) * dx + (p.lat - a.lat) * dy) / len)) : 0
            let q = LatLon(a.lat + dy * t, a.lon + (b.lon - a.lon) * t)
            let d = pow((q.lon - p.lon) * kx, 2) + pow(q.lat - p.lat, 2)
            if d < best.d { best = (i, q, d) }
            i += 1
        }
        return (best.index, best.point)
    }

    /// The route split at the train: what it has done (solid) and what's ahead (dashed). `from` is where to start
    /// searching; it comes back a little before the cut so later searches never go backwards.
    static func split(_ line: [LatLon], at p: LatLon, from: Int) -> (done: [LatLon], ahead: [LatLon], next: Int) {
        let cut = nearestOnLine(line, p, from: from)
        return (Array(line[0...cut.index]) + [cut.point], [cut.point] + Array(line[(cut.index + 1)...]), max(0, cut.index - 3))
    }

    /// Where a gliding marker is `now`: from its old spot to the new one over 1.5 s, easing out.
    static func glide(from: LatLon, to: LatLon, startedAt: Double, now: Double) -> (position: LatLon, done: Bool) {
        let k = min(1, (now - startedAt) / glideMs)
        let e = 1 - pow(1 - k, 3)
        return (LatLon(from.lat + (to.lat - from.lat) * e, from.lon + (to.lon - from.lon) * e), k >= 1)
    }

    // MARK: status

    enum Status: Equatable, Sendable {
        case loading
        case unavailable
        case delayed(upstreamAt: Double)
        case none(filtered: Bool)
        case running(total: Int, simulated: Bool)
    }

    /// The chip over the map, first match wins (brief §6.3).
    static func status(loaded: Bool, streamDown: Bool, lastMessageAt: Double, mode: String?, upstreamAt: Double, shown: Int, total: Int, zoom: Double, filtered: Bool, now: Double) -> Status {
        if !loaded && !streamDown { return .loading }
        if (streamDown && now - lastMessageAt > 20_000) || mode == "stopped" { return .unavailable }
        if upstreamAt > 0 && now - upstreamAt > staleMs { return .delayed(upstreamAt: upstreamAt) }
        if shown == 0 && zoom >= 6.5 { return .none(filtered: filtered) }
        return .running(total: total, simulated: mode == "simulate")
    }

    enum PositionKind: Equatable, Sendable {
        case estimated
        case old(minutes: Int)
        case gps
    }

    /// Position status (brief §6.2): GPS only while fresh; an old fix says how old; estimates say so.
    static func position(of train: LiveTrain, now: Double) -> PositionKind {
        if train.estimated { return .estimated }
        let age = now - train.at.ms
        return age > gpsFreshMs ? .old(minutes: Int((age / 60_000).rounded())) : .gps
    }

    // MARK: search

    /// Running trains whose number starts with the digits typed, at most six.
    static func trainHits(_ trains: [LiveTrain], query: String) -> [LiveTrain] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let digits = q.filter(\.isNumber)
        let prefix = digits.isEmpty ? "#" : digits
        return Array(trains.filter { $0.number.hasPrefix(prefix) }.sorted { $0.number < $1.number }.prefix(6))
    }

    /// Station names are searched from two characters, and not for a bare train number.
    static func searchesStations(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.count >= 2 && !q.allSatisfy(\.isNumber)
    }

    // MARK: the train sheet

    enum SheetSize: Int, Sendable { case small, mid, full }

    struct SheetTargets: Equatable, Sendable {
        var small: Double
        var mid: Double
        var full: Double

        subscript(_ size: SheetSize) -> Double {
            switch size {
            case .small: small
            case .mid: mid
            case .full: full
            }
        }
    }

    /// The height each size settles at, from the room there is and what the sheet holds (`targets`, `:1011-1018`).
    static func sheetTargets(room: Double, content: Double, head: Double, foot: Double) -> SheetTargets {
        let full = room - 24
        let mid = min(content, min(room * 0.74, 680), full)
        let small = min(head + foot + 120, mid)
        return SheetTargets(small: small, mid: mid, full: full)
    }

    /// Where a drag ends: the nearest size, but a flick (faster than half a point a millisecond) goes at least one
    /// size on from where the drag began.
    static func settle(height: Double, velocity: Double, from: SheetSize, targets: SheetTargets) -> SheetSize {
        let order: [SheetSize] = [.small, .mid, .full]
        let nearest = order.reduce(SheetSize.small) { a, b in abs(targets[b] - height) < abs(targets[a] - height) ? b : a }
        let start = from.rawValue
        let near = nearest.rawValue
        let to: Int
        if velocity < -0.5 { to = max(near, min(2, start + 1)) }
        else if velocity > 0.5 { to = min(near, max(0, start - 1)) }
        else { to = near }
        return order[to]
    }

    // MARK: stops

    /// The stop list's per-stop facts: the time to show, how late it is, and which stop is next.
    struct StopTimes: Equatable, Sendable {
        var planned: Double?
        var real: Double?
        var lateMinutes: Int
        var shown: Double? { real ?? planned }
    }

    static func stopTimes(_ stop: LiveTrainStop, isLast: Bool) -> StopTimes {
        let planned = isLast ? stop.arr : (stop.dep ?? stop.arr)
        let real = isLast ? (stop.actualArr ?? stop.estimatedArr) : (stop.actualDep ?? stop.estimatedDep ?? stop.actualArr ?? stop.estimatedArr)
        let late = (planned != nil && real != nil) ? Int(((real! - planned!) / 60_000).rounded()) : 0
        return StopTimes(planned: planned, real: real, lateMinutes: late)
    }

    static func nextStopIndex(_ stops: [LiveTrainStop]) -> Int? {
        stops.firstIndex { !$0.passed && !$0.canceled }
    }

    /// A train's stops as the journey a ticket is bought for.
    static func ticketTrip(operatorId: String?, number: String, from: LiveTrainStop, to: LiveTrainStop, trip: TrainTrip?) -> TicketTrip {
        TicketTrip(
            operatorId: operatorId, trainNumber: number,
            from: .init(name: from.name, time: from.dep ?? from.arr ?? 0, tz: "Europe/Stockholm", seq: from.seq),
            to: .init(name: to.name, time: to.arr ?? to.dep ?? 0, tz: "Europe/Stockholm", seq: to.seq),
            tripKey: trip?.key, serviceDate: trip?.serviceDate
        )
    }

    /// The part of the train you could still catch: from the next stop that isn't the last.
    static func catchableFrom(_ stops: [LiveTrainStop]) -> LiveTrainStop? {
        guard stops.count > 1, let last = stops.last else { return nil }
        return stops.first { !$0.passed && !$0.canceled && $0.seq != last.seq }
    }
}
