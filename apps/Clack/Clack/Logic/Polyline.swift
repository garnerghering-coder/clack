//
//  Polyline.swift
//  Clack
//

import Foundation

/// A point on the map: WGS84 degrees.
nonisolated struct LatLon: Hashable, Sendable {
    let lat: Double
    let lon: Double

    init(_ lat: Double, _ lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

/// Encoded polylines (Google's format, precision 5, about 1 m); a port of `packages/shared/src/polyline.ts`.
nonisolated enum Polyline {
    static func encode(_ points: [LatLon]) -> String {
        var out = ""
        var previousLat = 0
        var previousLon = 0
        func write(_ value: Int) {
            var x = value < 0 ? ~(value << 1) : value << 1
            while x >= 0x20 {
                out.unicodeScalars.append(Unicode.Scalar(UInt8((0x20 | (x & 0x1F)) + 63)))
                x >>= 5
            }
            out.unicodeScalars.append(Unicode.Scalar(UInt8(x + 63)))
        }
        for point in points {
            let lat = Int((point.lat * 1e5).rounded())
            let lon = Int((point.lon * 1e5).rounded())
            write(lat - previousLat)
            write(lon - previousLon)
            previousLat = lat
            previousLon = lon
        }
        return out
    }

    static func decode(_ text: String) -> [LatLon] {
        let bytes = Array(text.utf8)
        var index = 0
        var lat = 0
        var lon = 0
        var out: [LatLon] = []
        func read() -> Int {
            var shift = 0
            var result = 0
            var byte = 0
            repeat {
                byte = index < bytes.count ? Int(bytes[index]) - 63 : 0
                index += 1
                result |= (byte & 0x1F) << shift
                shift += 5
            } while byte >= 0x20 && index <= bytes.count
            return result & 1 != 0 ? ~(result >> 1) : result >> 1
        }
        while index < bytes.count {
            lat += read()
            lon += read()
            out.append(LatLon(Double(lat) / 1e5, Double(lon) / 1e5))
        }
        return out
    }
}
