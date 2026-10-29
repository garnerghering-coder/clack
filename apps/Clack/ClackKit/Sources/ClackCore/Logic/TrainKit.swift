//
//  TrainKit.swift
//  Clack
//

import Foundation

/// The 3D trains (BUILDOUT F3): a few simple designs, each adapted per train, with as many cars as the data gives.
/// This is the pure part: which design a type gets, how many cars, and where each car sits along the track. The
/// RealityKit drawing lives in the app.
public nonisolated enum TrainKit {
    /// The five generic designs (owner, 2026-10-28: "super simple, a few generic designs").
    public enum Template: String, CaseIterable, Sendable {
        /// A multiple unit with a blunt cab (Coradia, Contessa, FLIRT, Regina, Desiro, LINT…).
        case multipleUnit
        /// A high-speed unit with a long nose (X2000, Pendolino, ICE-like).
        case highSpeed
        /// A double-deck unit or coach set (X40, ER1, DSB's double-deckers).
        case doubleDeck
        /// A locomotive pulling coaches (Rc6, Vectron, Sr2/Sr3, El18, Di4).
        case locoCoaches
        /// A one- or two-car railcar (Y31, Itino, Dm12).
        case railcar
    }

    /// The design for a type's art family (`art` in data/train_types.json).
    public static func template(forArt art: String?) -> Template {
        switch art ?? "" {
        case "x2000", "x3": .highSpeed
        case "double_deck": .doubleDeck
        case "loco", "loco_sleeper", "steam": .locoCoaches
        case "railcar", "dk_railcar": .railcar
        default: .multipleUnit
        }
    }

    /// Car length to draw for a design, metres (typical Nordic values; the drawing is schematic, not to each type's
    /// measured length: 26.4 m is the UIC coach; multiple-unit cars run 20–26 m; railcars about 20 m).
    public static func carLength(_ t: Template) -> Double {
        switch t {
        case .locoCoaches, .doubleDeck: 26.4
        case .highSpeed, .multipleUnit: 24.0
        case .railcar: 20.0
        }
    }

    /// How many cars to draw. The feed's count when it says (Sweden's coach order, Finland's composition), else the
    /// type's typical count, else a default per design; `known` says whether the number is the data's or a guess.
    public static func carCount(live: Int?, typical: Int?, template: Template) -> (count: Int, known: Bool) {
        if let live, live > 0 { return (live, true) }
        if let typical, typical > 0 { return (typical, false) }
        let fallback: Int = switch template {
        case .highSpeed: 6
        case .multipleUnit: 4
        case .doubleDeck: 3
        case .locoCoaches: 5
        case .railcar: 2
        }
        return (fallback, false)
    }

    /// One car's place on the track: its middle and its heading (degrees, 0 = north, clockwise).
    public struct CarPose: Equatable, Sendable {
        public let center: LatLon
        public let headingDeg: Double
        public init(center: LatLon, headingDeg: Double) {
            self.center = center
            self.headingDeg = headingDeg
        }
    }

    /// Where each car sits along `track` (the route, first point first) when the front of the train is `headM`
    /// metres along it: the cars follow one behind the other, each bent to the track where it is, so the train
    /// curves with the line. The first pose is the front car. Cars that would be before the start of the track sit
    /// at its start (a train just leaving its origin).
    public static func carPoses(track: [LatLon], headM: Double, count: Int, carLength: Double, gap: Double = 0.8) -> [CarPose] {
        guard track.count >= 2, count > 0 else { return [] }
        let cum = cumulative(track)
        let total = cum.last ?? 0
        var out: [CarPose] = []
        for i in 0..<count {
            let front = headM - Double(i) * (carLength + gap)
            let back = front - carLength
            let mid = max(0, min(total, (front + back) / 2))
            let a = point(at: max(0, min(total, back)), track: track, cum: cum)
            let b = point(at: max(0, min(total, front)), track: track, cum: cum)
            let heading = a == b ? bearing(at: mid, track: track, cum: cum) : bearing(from: a, to: b)
            out.append(CarPose(center: point(at: mid, track: track, cum: cum), headingDeg: heading))
        }
        return out
    }

    /// Length of the train, metres, for `count` cars of `carLength` with `gap` between them.
    public static func trainLength(count: Int, carLength: Double, gap: Double = 0.8) -> Double {
        guard count > 0 else { return 0 }
        return Double(count) * carLength + Double(count - 1) * gap
    }

    // MARK: geometry

    public static func cumulative(_ pts: [LatLon]) -> [Double] {
        var out = [0.0]
        for i in 1..<pts.count { out.append(out[i - 1] + distanceM(pts[i - 1], pts[i])) }
        return out
    }

    public static func point(at d: Double, track: [LatLon], cum: [Double]) -> LatLon {
        if d <= 0 { return track[0] }
        if d >= (cum.last ?? 0) { return track[track.count - 1] }
        var i = 1
        while i < cum.count && cum[i] < d { i += 1 }
        let a = track[i - 1], b = track[i]
        let seg = cum[i] - cum[i - 1]
        let f = seg > 0 ? (d - cum[i - 1]) / seg : 0
        return LatLon(a.lat + (b.lat - a.lat) * f, a.lon + (b.lon - a.lon) * f)
    }

    static func bearing(at d: Double, track: [LatLon], cum: [Double]) -> Double {
        var i = 1
        while i < cum.count - 1 && cum[i] < d { i += 1 }
        return bearing(from: track[i - 1], to: track[i])
    }

    static func distanceM(_ a: LatLon, _ b: LatLon) -> Double {
        let r = 6_371_000.0
        let dLat = (b.lat - a.lat) * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let la1 = a.lat * .pi / 180, la2 = b.lat * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * r * asin(min(1, sqrt(h)))
    }

    static func bearing(from a: LatLon, to b: LatLon) -> Double {
        let la1 = a.lat * .pi / 180, la2 = b.lat * .pi / 180
        let dLon = (b.lon - a.lon) * .pi / 180
        let y = sin(dLon) * cos(la2)
        let x = cos(la1) * sin(la2) - sin(la1) * cos(la2) * cos(dLon)
        let deg = atan2(y, x) * 180 / .pi
        return (deg + 360).truncatingRemainder(dividingBy: 360)
    }
}
