//
//  StationDetailLogic.swift
//  Clack
//

import Foundation

/// The pure part of the station detail at close zoom (plan 2026-10-29, step 2): a train drawn as its cars along the
/// nearest track. Snapping, heading and car geometry live here and are tested; the map style and the fetch are in
/// the app.
public nonisolated enum StationDetailLogic {
    /// A track as the detail answer gives it (lon/lat pairs turned into points), with its service flag.
    public struct Track: Sendable, Equatable {
        public let points: [LatLon]
        public let service: Bool
        public init(points: [LatLon], service: Bool) {
            self.points = points
            self.service = service
        }
    }

    /// One car on the map: the line from its back to its front.
    public struct Car: Sendable, Equatable {
        public let back: LatLon
        public let front: LatLon
        public let isFront: Bool
        public init(back: LatLon, front: LatLon, isFront: Bool) {
            self.back = back
            self.front = front
            self.isFront = isFront
        }
    }

    /// A train is laid on a track when its point is within this many metres of one.
    public static let snapM = 30.0

    /// The nearest track to `p` within `snapM`, with where along it the point falls (metres from the track's start)
    /// and the track's bearing there. Running tracks win over sidings at equal distance.
    public static func nearest(_ p: LatLon, tracks: [Track]) -> (track: Track, alongM: Double, bearingDeg: Double)? {
        var best: (d: Double, t: Track, along: Double, bearing: Double)?
        for t in tracks where t.points.count >= 2 {
            let hit = ExploreLogic.nearestOnLine(t.points, p)
            let d = TrainKit.distanceM(hit.point, p) + (t.service ? 3 : 0)
            if d > snapM || (best.map { d >= $0.d } ?? false) { continue }
            let cum = TrainKit.cumulative(t.points)
            let along = cum[hit.index] + TrainKit.distanceM(t.points[hit.index], hit.point)
            best = (d, t, along, TrainKit.bearing(from: t.points[hit.index], to: t.points[hit.index + 1]))
        }
        return best.map { ($0.t, $0.along, $0.bearing) }
    }

    /// The train's cars with its middle at `p`: along the nearest track (bent with it), facing the way of travel
    /// that agrees with `bearing` (else the track's own direction); off any track, a straight line along `bearing`
    /// (or north). The first car is the front.
    public static func cars(at p: LatLon, bearing: Double?, count: Int, carLength: Double, tracks: [Track]) -> [Car] {
        guard count > 0 else { return [] }
        let length = TrainKit.trainLength(count: count, carLength: carLength)
        if let hit = nearest(p, tracks: tracks) {
            // Travelling against the track's point order when the bearing says so.
            let forward = bearing.map { angleDiff($0, hit.bearingDeg) <= 90 } ?? true
            let line = forward ? hit.track.points : Array(hit.track.points.reversed())
            let cum = TrainKit.cumulative(line)
            let along = forward ? hit.alongM : (cum.last ?? 0) - hit.alongM
            let headM = along + length / 2
            return (0..<count).map { i in
                let front = headM - Double(i) * (carLength + 0.8)
                let back = front - carLength
                return Car(back: TrainKit.point(at: max(0, back), track: line, cum: cum), front: TrainKit.point(at: min(cum.last ?? 0, front), track: line, cum: cum), isFront: i == 0)
            }
        }
        let b = (bearing ?? 0) * Double.pi / 180
        func offset(_ m: Double) -> LatLon {
            LatLon(p.lat + m * cos(b) / 111_320, p.lon + m * sin(b) / (111_320 * cos(p.lat * .pi / 180)))
        }
        return (0..<count).map { i in
            let front = length / 2 - Double(i) * (carLength + 0.8)
            return Car(back: offset(front - carLength), front: offset(front), isFront: i == 0)
        }
    }

    static func angleDiff(_ a: Double, _ b: Double) -> Double {
        let d = abs((a - b).truncatingRemainder(dividingBy: 360))
        return min(d, 360 - d)
    }
}
