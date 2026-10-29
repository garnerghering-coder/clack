//
//  ExploreLogic.swift
//  Clack
//

import Foundation

/// The live map's rules (pages/LiveMapPage.tsx): which trains show, where the selected train's route is cut, how a
/// marker glides, what the status chip says, the train sheet's three sizes.
public nonisolated enum ExploreLogic {
    public static let products = ["high_speed", "intercity", "regional", "commuter", "night"]
    public static let glideMs = 1500.0
    public static let staleMs = 60_000.0
    /// A GPS fix older than this is shown as old, not as the train's position now (the server's GPS_FRESH_MS).
    public static let gpsFreshMs = 120_000.0

    /// How late a train must be to show (replacing "only delayed", owner 2026-10-27).
    public enum Delay: String, CaseIterable, Sendable {
        case any, onTime, late5, late15
    }

    public struct Filters: Equatable, Sendable {
        public var products: Set<String> = []
        public var operators: Set<String> = []
        /// SE, NO, FI, DK; empty means all.
        public var countries: Set<String> = []
        public var delay: Delay = .any
        public var onlyMine = false
        public var onlyFollowed = false

        /// What the filter button's badge counts: each product, operator and country, and each setting that's on.
        public var count: Int { products.count + operators.count + countries.count + (delay != .any ? 1 : 0) + (onlyMine ? 1 : 0) + (onlyFollowed ? 1 : 0) }

        public init(products: Set<String> = [], operators: Set<String> = [], countries: Set<String> = [], delay: Delay = .any, onlyMine: Bool = false, onlyFollowed: Bool = false) {
            self.products = products
            self.operators = operators
            self.countries = countries
            self.delay = delay
            self.onlyMine = onlyMine
            self.onlyFollowed = onlyFollowed
        }
    }

    public static func followKey(number: String, date: String) -> String { "\(number)|\(date)" }

    /// The country of a train on the map, from its id ("dk:…", "fi:…", "no:…"; Sweden's carry no prefix).
    public static func country(ofTrainId id: String) -> String {
        if id.hasPrefix("dk:") { return "DK" }
        if id.hasPrefix("fi:") { return "FI" }
        if id.hasPrefix("no:") { return "NO" }
        return "SE"
    }

    public static func visible(_ train: LiveTrain, _ f: Filters, followed: Set<String>) -> Bool {
        if f.onlyMine && !train.mine { return false }
        if f.onlyFollowed && !followed.contains(followKey(number: train.number, date: train.date)) { return false }
        switch f.delay {
        case .any: break
        case .onTime: if (train.delayMin ?? 0) >= 3 { return false }
        case .late5: if (train.delayMin ?? 0) < 5 { return false }
        case .late15: if (train.delayMin ?? 0) < 15 { return false }
        }
        if !f.countries.isEmpty && !f.countries.contains(country(ofTrainId: train.id)) { return false }
        if !f.products.isEmpty && !(train.product.map(f.products.contains) ?? false) { return false }
        if !f.operators.isEmpty && !(train.operatorId.map(f.operators.contains) ?? false) { return false }
        return true
    }

    /// A moved train is the old one with its position fields replaced.
    public static func applying(_ moved: MovedTrain, to train: LiveTrain) -> LiveTrain {
        var t = train
        t.lat = moved.lat
        t.lon = moved.lon
        t.bearing = moved.bearing
        t.speedKmh = moved.speedKmh
        t.at = Instant(ms: moved.at)
        t.estimated = moved.estimated
        if let state = moved.state { t.state = state }
        t.progress = moved.progress
        return t
    }

    // MARK: the selected train's route

    /// The point on a line closest to `p` (projected onto its segments), searching from segment `from` on.
    public static func nearestOnLine(_ line: [LatLon], _ p: LatLon, from: Int = 0) -> (index: Int, point: LatLon) {
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
    public static func split(_ line: [LatLon], at p: LatLon, from: Int) -> (done: [LatLon], ahead: [LatLon], next: Int) {
        let cut = nearestOnLine(line, p, from: from)
        return (Array(line[0...cut.index]) + [cut.point], [cut.point] + Array(line[(cut.index + 1)...]), max(0, cut.index - 3))
    }

    /// Where a gliding marker is `now`: from its old spot to the new one over 1.5 s, easing out.
    public static func glide(from: LatLon, to: LatLon, startedAt: Double, now: Double) -> (position: LatLon, done: Bool) {
        let k = min(1, (now - startedAt) / glideMs)
        let e = 1 - pow(1 - k, 3)
        return (LatLon(from.lat + (to.lat - from.lat) * e, from.lon + (to.lon - from.lon) * e), k >= 1)
    }

    // MARK: gliding along the track

    /// A train track as a polyline with cumulative lengths in metres (the answer of `GET /api/live/segment`).
    public struct TrackPath: Sendable, Equatable {
        public let points: [LatLon]
        private let cumulative: [Double]
        public var length: Double { cumulative.last ?? 0 }

        public init(points: [LatLon]) {
            self.points = points
            var sum = 0.0
            var c: [Double] = points.isEmpty ? [] : [0]
            for i in 1..<max(1, points.count) {
                sum += ExploreLogic.metres(points[i - 1], points[i])
                c.append(sum)
            }
            cumulative = c
        }

        /// How far along the track the nearest point to `p` is, and how far `p` lies from the track.
        public func project(_ p: LatLon) -> (along: Double, offsetM: Double) {
            guard points.count >= 2 else { return (0, .infinity) }
            var best = (along: 0.0, offsetM: Double.infinity)
            let k = cos(p.lat * .pi / 180)
            for i in 1..<points.count {
                let a = points[i - 1], b = points[i]
                let ax = (b.lon - a.lon) * k, ay = b.lat - a.lat
                let px = (p.lon - a.lon) * k, py = p.lat - a.lat
                let len2 = ax * ax + ay * ay
                let t = len2 == 0 ? 0 : max(0, min(1, (px * ax + py * ay) / len2))
                let q = LatLon(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t)
                let d = ExploreLogic.metres(p, q)
                if d < best.offsetM { best = (cumulative[i - 1] + (cumulative[i] - cumulative[i - 1]) * t, d) }
            }
            return best
        }

        /// The point `m` metres along (clamped to the track) and the direction of travel there, degrees from north.
        public func at(_ m: Double) -> (position: LatLon, bearing: Double) {
            guard points.count >= 2 else { return (points.first ?? LatLon(0, 0), 0) }
            let d = max(0, min(length, m))
            var i = 1
            while i < points.count - 1 && cumulative[i] < d { i += 1 }
            let a = points[i - 1], b = points[i]
            let span = cumulative[i] - cumulative[i - 1]
            let t = span == 0 ? 0 : (d - cumulative[i - 1]) / span
            return (LatLon(a.lat + (b.lat - a.lat) * t, a.lon + (b.lon - a.lon) * t), ExploreLogic.bearing(a, b))
        }
    }

    /// How long a train is carried on at its speed after an update, waiting for the next one (they come every 2 s).
    public static let extrapolateMs = 4_000.0

    /// A marker's move to a new fix. Straight (`track` nil) it eases from `from` to `to`; along a track it eases along
    /// the rails from `fromM` to `toM`, then keeps going at `speed` (m/s) for `extrapolateMs`, never past the track's end
    /// (the next station), and its heading follows the track.
    public struct Glide: Sendable {
        public var from: LatLon
        public var to: LatLon
        public var start: Double
        public var track: TrackPath?
        public var fromM = 0.0
        public var toM = 0.0
        public var speed = 0.0

        public init(from: LatLon, to: LatLon, start: Double) {
            self.from = from
            self.to = to
            self.start = start
        }

        public init(track: TrackPath, fromM: Double, toM: Double, speed: Double, start: Double) {
            self.from = track.at(fromM).position
            self.to = track.at(toM).position
            self.start = start
            self.track = track
            self.fromM = fromM
            self.toM = toM
            self.speed = speed
        }

        public func step(now: Double) -> (position: LatLon, bearing: Double?, done: Bool) {
            guard let track else {
                let s = ExploreLogic.glide(from: from, to: to, startedAt: start, now: now)
                return (s.position, nil, s.done)
            }
            let elapsed = max(0, now - start)
            let k = min(1, elapsed / ExploreLogic.glideMs)
            let e = 1 - pow(1 - k, 3)
            let ahead = speed * min(elapsed, ExploreLogic.extrapolateMs) / 1000
            let target = min(track.length, toM + ahead)
            let along = target - (toM - fromM) * (1 - e)
            let p = track.at(along)
            let finished = speed > 0 ? (elapsed >= ExploreLogic.extrapolateMs || target >= track.length) : true
            return (p.position, p.bearing, finished && k >= 1)
        }
    }

    /// Starts a glide for a train that moved from `old` (where it is drawn now) to a new fix. On the track when both
    /// points lie within 100 m of it; a standing train never creeps along it.
    public static func makeGlide(track: TrackPath?, from old: LatLon, to new: LatLon, standing: Bool, speedKmh: Double?, start: Double) -> Glide {
        guard let track, !standing else { return Glide(from: old, to: new, start: start) }
        let a = track.project(old), b = track.project(new)
        guard a.offsetM < 100, b.offsetM < 100 else { return Glide(from: old, to: new, start: start) }
        let v = max(0, speedKmh ?? 0) / 3.6
        return Glide(track: track, fromM: a.along, toM: b.along, speed: v, start: start)
    }

    public static func metres(_ a: LatLon, _ b: LatLon) -> Double {
        let dy = (b.lat - a.lat) * 111_320
        let dx = (b.lon - a.lon) * 111_320 * cos((a.lat + b.lat) / 2 * .pi / 180)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Degrees from north, clockwise, from `a` towards `b`.
    public static func bearing(_ a: LatLon, _ b: LatLon) -> Double {
        let dy = b.lat - a.lat
        let dx = (b.lon - a.lon) * cos((a.lat + b.lat) / 2 * .pi / 180)
        let d = atan2(dx, dy) * 180 / .pi
        return d < 0 ? d + 360 : d
    }

    // MARK: status

    public enum Status: Equatable, Sendable {
        case loading
        case unavailable
        case delayed(upstreamAt: Double)
        case none(filtered: Bool)
        case running(total: Int, simulated: Bool)
    }

    /// The chip over the map, first match wins (brief §6.3).
    public static func status(loaded: Bool, streamDown: Bool, lastMessageAt: Double, mode: String?, upstreamAt: Double, shown: Int, total: Int, zoom: Double, filtered: Bool, now: Double) -> Status {
        if !loaded && !streamDown { return .loading }
        if (streamDown && now - lastMessageAt > 20_000) || mode == "stopped" { return .unavailable }
        if upstreamAt > 0 && now - upstreamAt > staleMs { return .delayed(upstreamAt: upstreamAt) }
        if shown == 0 && zoom >= 6.5 { return .none(filtered: filtered) }
        // With filters on, the count is of the trains that match them, so it follows the filters.
        return .running(total: filtered ? shown : total, simulated: mode == "simulate")
    }

    public enum PositionKind: Equatable, Sendable {
        case estimated
        case old(minutes: Int)
        case gps
    }

    /// Position status (brief §6.2): GPS only while fresh; an old fix says how old; estimates say so.
    public static func position(of train: LiveTrain, now: Double) -> PositionKind {
        if train.estimated { return .estimated }
        let age = now - train.at.ms
        return age > gpsFreshMs ? .old(minutes: Int((age / 60_000).rounded())) : .gps
    }

    // MARK: search

    /// Running trains whose number starts with the digits typed, at most six.
    public static func trainHits(_ trains: [LiveTrain], query: String) -> [LiveTrain] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let digits = q.filter(\.isNumber)
        let prefix = digits.isEmpty ? "#" : digits
        return Array(trains.filter { $0.number.hasPrefix(prefix) }.sorted { $0.number < $1.number }.prefix(6))
    }

    /// Station names are searched from two characters, and not for a bare train number.
    public static func searchesStations(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        return q.count >= 2 && !q.allSatisfy(\.isNumber)
    }

    // MARK: the train sheet

    public enum SheetSize: Int, Sendable { case small, mid, full }

    public struct SheetTargets: Equatable, Sendable {
        public var small: Double
        public var mid: Double
        public var full: Double

        public subscript(_ size: SheetSize) -> Double {
            switch size {
            case .small: small
            case .mid: mid
            case .full: full
            }
        }

        public init(small: Double, mid: Double, full: Double) {
            self.small = small
            self.mid = mid
            self.full = full
        }
    }

    /// The height each size settles at, from the room there is and what the sheet holds (`targets`, `:1011-1018`).
    public static func sheetTargets(room: Double, content: Double, head: Double, foot: Double) -> SheetTargets {
        let full = room - 24
        let mid = min(content, min(room * 0.74, 680), full)
        let small = min(head + foot + 120, mid)
        return SheetTargets(small: small, mid: mid, full: full)
    }

    /// Where a drag ends: the nearest size, but a flick (faster than half a point a millisecond) goes at least one
    /// size on from where the drag began.
    public static func settle(height: Double, velocity: Double, from: SheetSize, targets: SheetTargets) -> SheetSize {
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
    public struct StopTimes: Equatable, Sendable {
        public var planned: Double?
        public var real: Double?
        public var lateMinutes: Int
        public var shown: Double? { real ?? planned }

        public init(planned: Double? = nil, real: Double? = nil, lateMinutes: Int) {
            self.planned = planned
            self.real = real
            self.lateMinutes = lateMinutes
        }
    }

    /// A stand of `longStopMin` or more at an intermediate stop: the best-known arrival and departure. Nil at the
    /// ends of the run and for ordinary stops (owner, 2026-10-29: only the clearly long stands). Pure.
    public static let longStopMin = 5.0
    public static func dwell(_ stop: LiveTrainStop, isEnd: Bool) -> (arr: Double, dep: Double)? {
        guard !isEnd, !stop.canceled, let arr = stop.actualArr ?? stop.estimatedArr ?? stop.arr, let dep = stop.actualDep ?? stop.estimatedDep ?? stop.dep else { return nil }
        return dep - arr >= longStopMin * 60_000 ? (arr, dep) : nil
    }

    public static func stopTimes(_ stop: LiveTrainStop, isLast: Bool) -> StopTimes {
        let planned = isLast ? stop.arr : (stop.dep ?? stop.arr)
        let real = isLast ? (stop.actualArr ?? stop.estimatedArr) : (stop.actualDep ?? stop.estimatedDep ?? stop.actualArr ?? stop.estimatedArr)
        let late = (planned != nil && real != nil) ? Int(((real! - planned!) / 60_000).rounded()) : 0
        return StopTimes(planned: planned, real: real, lateMinutes: late)
    }

    public static func nextStopIndex(_ stops: [LiveTrainStop]) -> Int? {
        stops.firstIndex { !$0.passed && !$0.canceled }
    }

    /// A train's stops as the journey a ticket is bought for.
    /// The stops carry no zone of their own, so it comes from the station ids (`fi:` is Finland).
    public static func ticketTrip(operatorId: String?, number: String, from: LiveTrainStop, to: LiveTrainStop, trip: TrainTrip?) -> TicketTrip {
        TicketTrip(
            operatorId: operatorId, trainNumber: number,
            from: .init(name: from.name, time: from.dep ?? from.arr ?? 0, tz: Format.zone(stationId: from.stationId), seq: from.seq),
            to: .init(name: to.name, time: to.arr ?? to.dep ?? 0, tz: Format.zone(stationId: to.stationId), seq: to.seq),
            tripKey: trip?.key, serviceDate: trip?.serviceDate
        )
    }

    /// The part of the train you could still catch: from the next stop that isn't the last.
    public static func catchableFrom(_ stops: [LiveTrainStop]) -> LiveTrainStop? {
        guard stops.count > 1, let last = stops.last else { return nil }
        return stops.first { !$0.passed && !$0.canceled && $0.seq != last.seq }
    }

    /// For each stop but the last: how far the train is along the stretch to the next one, 0 to 1 (the Explore sheet draws
    /// it as the trip view does). Worked out from the times: a stretch is fully covered once the next stop is passed, the
    /// stretch the train is on is placed by the time since it left the stop behind, and a stop the train is standing at
    /// (arrived, not yet left) has the stretch into it fully covered.
    public static func railFills(_ stops: [LiveTrainStop], now: Double) -> [Double] {
        guard stops.count > 1 else { return [] }
        return (0..<(stops.count - 1)).map { i in
            let a = stops[i], b = stops[i + 1]
            if b.passed || b.actualArr != nil { return 1 }
            guard a.passed else { return 0 }
            guard let dep = a.actualDep ?? a.estimatedDep ?? a.dep, let arr = b.actualArr ?? b.estimatedArr ?? b.arr, arr > dep else { return 0.05 }
            return min(0.95, max(0.05, (now - dep) / (arr - dep)))
        }
    }

    // MARK: colour by (owner, 2026-10-28)

    /// What a train dot's colour means on Explore: its operator (the brand colour), its kind of train, how late it is
    /// (DESIGN.md's delay bands), or its country.
    public enum ColorBy: String, CaseIterable, Codable, Sendable {
        case operatorBrand = "operator", product, delay, country
    }

    /// One colour per kind of train, apart from each other on both map themes.
    public static let productColors: [String: String] = [
        "high_speed": "#FF6B3D", "intercity": "#4C8DFF", "regional": "#3DDC84", "commuter": "#F5D90A", "night": "#A78BFA",
    ]
    /// DESIGN.md's delay bands: on time, 1–15, 16–30, 31+ minutes late; unknown in grey.
    public static let delayColors = (onTime: "#3DDC84", slight: "#F5D90A", late: "#FF9500", veryLate: "#FF453A", unknown: "#9AA0A6")
    /// One colour per country, from its flag where the flags don't clash (Norway's and Denmark's reds would).
    public static let countryColors: [String: String] = ["SE": "#FECC00", "NO": "#5B8DEF", "DK": "#E03A3E", "FI": "#9FD3FF"]
    public static let otherColor = "#9AA0A6"

    /// The dot colour for `by`; nil for `.operatorBrand` (the operator's own colour, which the app knows).
    public static func color(of train: LiveTrain, by: ColorBy) -> String? {
        switch by {
        case .operatorBrand: return nil
        case .product: return train.product.flatMap { productColors[$0] } ?? otherColor
        case .delay: return delayColor(train.delayMin)
        case .country: return countryColors[country(ofTrainId: train.id)] ?? otherColor
        }
    }

    public static func delayColor(_ min: Int?) -> String {
        guard let min else { return delayColors.unknown }
        if min <= 0 { return delayColors.onTime }
        if min <= 15 { return delayColors.slight }
        if min <= 30 { return delayColors.late }
        return delayColors.veryLate
    }
}

