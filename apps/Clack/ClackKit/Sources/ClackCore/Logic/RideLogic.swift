//
//  RideLogic.swift
//  Clack
//

import Foundation

/// The Ride view's pure part (BUILDOUT O3): where the train is along its track between two position reports, which
/// speed the speedometer shows and why, and the camera presets. The drawing lives in the app (`RideMapView`).
public nonisolated enum RideLogic {
    /// A train's track with its running distances and where each stop sits along it.
    public struct Track: Sendable, Equatable {
        public let points: [LatLon]
        public let cum: [Double]
        /// Metres from the start of the track to each stop, by the stop's `seq`.
        public let stopsAt: [Int: Double]

        public var length: Double { cum.last ?? 0 }

        public init(points: [LatLon], stopsAt: [Int: Double] = [:]) {
            self.points = points
            cum = points.count >= 2 ? TrainKit.cumulative(points) : [0]
            self.stopsAt = stopsAt
        }

        /// From a trip's geometry: the segments joined end to end, each segment's end being a stop.
        public init(geometry: TripGeometry) {
            var pts: [LatLon] = []
            var stops: [Int: Double] = [:]
            for (i, s) in geometry.segments.enumerated() {
                let decoded = Polyline.decode(s.polyline)
                if i == 0 {
                    stops[s.fromSeq] = 0
                    pts = decoded
                } else {
                    pts += decoded.dropFirst()
                }
                stops[s.toSeq] = pts.count >= 2 ? TrainKit.cumulative(pts).last ?? 0 : 0
            }
            self.init(points: pts, stopsAt: stops)
        }

        public func point(at m: Double) -> LatLon? {
            guard points.count >= 2 else { return points.first }
            return TrainKit.point(at: max(0, min(length, m)), track: points, cum: cum)
        }
    }

    /// Metres from the start of the track to the point nearest `p` (the train's reported position snapped on).
    public static func metresAlong(_ track: Track, of p: LatLon) -> Double {
        guard track.points.count >= 2 else { return 0 }
        var best = (d2: Double.infinity, m: 0.0)
        let kx = cos(p.lat * .pi / 180)
        for i in 1..<track.points.count {
            let a = track.points[i - 1], b = track.points[i]
            let ax = (a.lon - p.lon) * kx, ay = a.lat - p.lat
            let bx = (b.lon - p.lon) * kx, by = b.lat - p.lat
            let dx = bx - ax, dy = by - ay
            let len2 = dx * dx + dy * dy
            let t = len2 > 0 ? max(0, min(1, -(ax * dx + ay * dy) / len2)) : 0
            let px = ax + dx * t, py = ay + dy * t
            let d2 = px * px + py * py
            if d2 < best.d2 { best = (d2, track.cum[i - 1] + (track.cum[i] - track.cum[i - 1]) * t) }
        }
        return best.m
    }

    /// Where the train is now: the last report moved on at its speed for the time since (at most `maxSeconds`), but
    /// never past the next stop it hadn't reached, and never past the end of the track. A train without a speed
    /// (or standing) stays where it was reported.
    public static func extrapolate(metres: Double, reportedAt: Double, speedKmh: Double?, now: Double, track: Track, maxSeconds: Double = 120) -> Double {
        guard let speedKmh, speedKmh > 0 else { return min(metres, track.length) }
        let dt = min(maxSeconds, max(0, (now - reportedAt) / 1000))
        var m = metres + speedKmh / 3.6 * dt
        if let nextStop = track.stopsAt.values.filter({ $0 > metres + 1 }).min() { m = min(m, nextStop) }
        return min(m, track.length)
    }

    // MARK: speed

    public enum SpeedSource: String, Sendable, Equatable {
        /// The phone's own GPS: the ride is under way and the phone is with the train.
        case phone
        /// The train's reported speed (a GPS fix from the feed).
        case trainLive
        /// The train's speed is an estimate (no fix; the run profile).
        case trainEstimated
        case none
    }

    public struct Speed: Sendable, Equatable {
        public let kmh: Double?
        public let source: SpeedSource
        public init(kmh: Double?, source: SpeedSource) {
            self.kmh = kmh
            self.source = source
        }
    }

    /// Within this distance of where the train is drawn, the phone counts as aboard.
    public static let aboardM = 1000.0
    /// A phone fix older than this says nothing about the speed now.
    public static let phoneFreshS = 10.0
    /// The train's own speed is shown while its report is this fresh.
    public static let trainFreshS = 120.0

    /// The speedometer's reading. The phone's GPS speed counts only when the ride is under way and the phone is with
    /// the train (a fresh fix within `aboardM` of where the train is drawn); it is the phone's and says so. Otherwise
    /// the train's own reported speed while fresh, labelled live or estimated; else nothing.
    public static func speed(
        phoneKmh: Double?, phoneAgeS: Double?, phoneDistanceM: Double?,
        trainKmh: Double?, trainEstimated: Bool, trainAgeS: Double, underWay: Bool
    ) -> Speed {
        if underWay, let phoneKmh, phoneKmh >= 0, let phoneAgeS, phoneAgeS <= phoneFreshS, let phoneDistanceM, phoneDistanceM <= aboardM {
            return Speed(kmh: phoneKmh, source: .phone)
        }
        if let trainKmh, trainAgeS <= trainFreshS {
            return Speed(kmh: trainKmh, source: trainEstimated ? .trainEstimated : .trainLive)
        }
        return Speed(kmh: nil, source: .none)
    }

    // MARK: camera

    /// The four camera presets (BUILDOUT, build 53).
    public enum CameraPreset: String, CaseIterable, Sendable, Codable {
        case behind, above, side, driver
    }

    public struct Camera: Sendable, Equatable {
        /// Degrees from straight down.
        public let pitch: Double
        /// Metres from the point looked at.
        public let distance: Double
        /// Added to the track heading: 90 looks at the train from its right side.
        public let headingOffset: Double
        /// Metres ahead of the front car to look at (the driver's eye looks down the line).
        public let lookAheadM: Double
        public init(pitch: Double, distance: Double, headingOffset: Double, lookAheadM: Double) {
            self.pitch = pitch
            self.distance = distance
            self.headingOffset = headingOffset
            self.lookAheadM = lookAheadM
        }
    }

    /// How close the camera may come and how far it may go (pinch).
    public static let distanceRange: ClosedRange<Double> = 80...2500

    public static func defaultDistance(_ p: CameraPreset) -> Double {
        switch p {
        case .behind: 320
        case .above: 900
        case .side: 260
        case .driver: 120
        }
    }

    /// The camera for a preset; `distance` overrides the preset's when the person has pinched (kept within range).
    public static func camera(_ p: CameraPreset, distance: Double? = nil) -> Camera {
        let d = min(distanceRange.upperBound, max(distanceRange.lowerBound, distance ?? defaultDistance(p)))
        return switch p {
        case .behind: Camera(pitch: 65, distance: d, headingOffset: 0, lookAheadM: 0)
        case .above: Camera(pitch: 30, distance: d, headingOffset: 0, lookAheadM: 0)
        case .side: Camera(pitch: 60, distance: d, headingOffset: 90, lookAheadM: 0)
        case .driver: Camera(pitch: 75, distance: d, headingOffset: 0, lookAheadM: 80)
        }
    }
}
