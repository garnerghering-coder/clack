//
//  MapGeometry.swift
//  Clack
//

import Foundation

/// A stop drawn on a route map: `end` is where you got on or off (a big dot with a label), `mid` a stop you rode
/// through.
nonisolated struct MapStop: Hashable, Sendable {
    enum Kind: String, Sendable { case end, mid }

    var lat: Double
    var lon: Double
    var name: String
    var kind: Kind
}

/// The live train on a map: where it is, which way it points, and whether the position is only an estimate (drawn as a
/// hollow dot).
nonisolated struct MapTrain: Hashable, Sendable {
    var lat: Double
    var lon: Double
    var bearing: Double?
    var estimated: Bool
}

/// The geometry the route maps share (apps/web/src/map/RouteMap.tsx).
nonisolated enum MapGeometry {
    /// South-west and north-east corners of the points, as (lat, lon); nil for no points.
    static func bounds(_ points: [LatLon]) -> (south: Double, west: Double, north: Double, east: Double)? {
        guard !points.isEmpty else { return nil }
        var south = 90.0, west = 180.0, north = -90.0, east = -180.0
        for p in points {
            south = min(south, p.lat)
            north = max(north, p.lat)
            west = min(west, p.lon)
            east = max(east, p.lon)
        }
        return (south, west, north, east)
    }

    /// The first `frac` of a line by length, for the draw-on animation.
    static func part(_ points: [LatLon], _ frac: Double) -> [LatLon] {
        if frac >= 1 || points.count < 2 { return points }
        var segments: [Double] = []
        var total = 0.0
        for i in 1..<points.count {
            let d = hypot(points[i].lat - points[i - 1].lat, (points[i].lon - points[i - 1].lon) * cos(points[i].lat * .pi / 180))
            segments.append(d)
            total += d
        }
        var left = total * frac
        var out = [points[0]]
        for i in 1..<points.count {
            let d = segments[i - 1]
            if left >= d {
                out.append(points[i])
                left -= d
                continue
            }
            let t = d != 0 ? left / d : 0
            out.append(LatLon(
                points[i - 1].lat + t * (points[i].lat - points[i - 1].lat),
                points[i - 1].lon + t * (points[i].lon - points[i - 1].lon)
            ))
            break
        }
        return out
    }

    /// The route split at a share of its length: (travelled, ahead). The ahead part starts at the cut and runs on
    /// through every vertex after it.
    /// (The web's `splitAt` overwrites the vertex after the cut with the cut instead of inserting the cut before it,
    /// so it loses a corner, and the last point when the cut is on the last stretch. The port keeps them.)
    static func split(_ points: [LatLon], at frac: Double) -> (travelled: [LatLon], ahead: [LatLon]) {
        let before = part(points, max(0, min(1, frac)))
        if before.count < 2 || frac >= 1 { return (points, []) }
        let cut = before[before.count - 1]
        // `before` ends at the cut, which is `before.count - 2` vertices into the line plus the part of a stretch.
        let next = before.count - 1
        var rest = [cut]
        if next < points.count { rest += points[next...] }
        return (before, rest)
    }

    /// GeoJSON for a set of lines (parts with fewer than two points are left out).
    static func lines(_ parts: [[LatLon]]) -> [String: Any] {
        [
            "type": "FeatureCollection",
            "features": parts.filter { $0.count > 1 }.map { part in
                [
                    "type": "Feature", "properties": [String: Any](),
                    "geometry": ["type": "LineString", "coordinates": part.map { [$0.lon, $0.lat] }],
                ] as [String: Any]
            },
        ]
    }

    /// GeoJSON for the stops, each with its name and kind.
    static func points(_ stops: [MapStop]) -> [String: Any] {
        [
            "type": "FeatureCollection",
            "features": stops.map { stop in
                [
                    "type": "Feature", "properties": ["name": stop.name, "kind": stop.kind.rawValue],
                    "geometry": ["type": "Point", "coordinates": [stop.lon, stop.lat]],
                ] as [String: Any]
            },
        ]
    }
}

extension LegDetail {
    /// What a route map draws for this trip: the ridden route (the routed geometry, else the stops' coordinates), and
    /// its stops. A trip's own map labels where you got on and off; `endsOnly` keeps just those two (the featured card).
    func mapRoute(endsOnly: Bool = false) -> (route: [LatLon], stops: [MapStop]) {
        let ridden = stops.filter { $0.role.isRidden }
        let route = geometry.map(Polyline.decode) ?? ridden.map { LatLon($0.lat, $0.lon) }
        let mapped = ridden.map { MapStop(lat: $0.lat, lon: $0.lon, name: $0.name, kind: $0.role == .through ? .mid : .end) }
        return (route, endsOnly ? mapped.filter { $0.kind == .end } : mapped)
    }
}
