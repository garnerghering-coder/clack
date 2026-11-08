//
//  RouteGuide.swift
//  Clack
//

import Foundation

/// Walking directions at human scale (walk mode): each step with its distance, the turn that starts it and a landmark
/// beside the turn, from the route's own geometry. A port twin of `guide` in packages/shared/src/station.ts, so the
/// review tooling prints the same words. Never generated text: the caller words each step from a template.
public nonisolated enum RouteGuide {
    public enum Turn: String, Sendable, Hashable { case left, right, straight, uTurn = "u_turn" }
    public enum Side: String, Sendable, Hashable { case left, right }

    public struct Landmark: Hashable, Sendable {
        public let poiId: String
        public let name: String
        public let side: Side
    }

    public struct Step: Hashable, Sendable {
        /// What the step is: a walk, or a change of level (stairs, escalator, lift, ramp; up or down).
        public var key: Instruction.Key
        /// Metres along the step (a walk's length; a change of level's footprint, often a few metres).
        public var distanceM: Double
        /// The turn that starts a walk (nil where the walk begins, and for changes of level).
        public var turn: Turn?
        /// A named place within 10 m of where the step starts, and on which side of the way it is.
        public var landmark: Landmark?
        /// Where the step starts, in the map's metres.
        public var at: Pt
        /// The level the step is on (for a change of level: the level it goes to).
        public var level: String
        public var seconds: Double
        /// The step's line, start to end.
        public var points: [Pt]
    }

    /// A bend sharper than this between the 6 m before and after a point is a turn.
    public static let turnDegrees = 35.0
    static let resampleM = 2.0
    static let windowM = 6.0
    static let landmarkM = 10.0

    /// The route as steps: runs of walking on one level split where the way turns, and the changes of level between.
    public static func steps(_ map: StationMap, _ route: StationRoute) -> [Step] {
        let order = Dictionary(map.levels.map { ($0.id, $0.order) }, uniquingKeysWith: { a, _ in a })
        var out: [Step] = []
        var run: [Pt] = []
        var runSeconds = 0.0
        var runLevel = ""
        func flush() {
            guard run.count > 1 else { run = []; runSeconds = 0; return }
            out.append(contentsOf: splitWalk(map, run, level: runLevel, seconds: runSeconds))
            run = []
            runSeconds = 0
        }
        for step in route.steps {
            let pts = StationSceneLogic.stepPoints(step)
            if step.kind == .walk && step.from.level == step.to.level {
                if runLevel != step.from.level { flush() }
                runLevel = step.from.level
                run += run.last.map { last in pts.first.map { same(last, $0) } == true ? Array(pts.dropFirst()) : pts } ?? pts
                runSeconds += step.seconds
            } else {
                flush()
                let up = (order[step.to.level] ?? 0) > (order[step.from.level] ?? 0)
                let key: Instruction.Key
                switch step.kind {
                case .stairs: key = up ? .stairsUp : .stairsDown
                case .escalator: key = up ? .escalatorUp : .escalatorDown
                case .lift: key = up ? .liftUp : .liftDown
                case .ramp: key = up ? .rampUp : .rampDown
                default: key = .walk
                }
                if let last = out.last, last.key == key, key != .walk {
                    out[out.count - 1].distanceM += length(pts)
                    out[out.count - 1].seconds += step.seconds
                    out[out.count - 1].level = step.to.level
                    out[out.count - 1].points += pts.dropFirst()
                } else {
                    out.append(Step(key: key, distanceM: length(pts), turn: nil, landmark: nil, at: pts.first ?? Pt(step.from.x, step.from.y), level: step.to.level, seconds: step.seconds, points: pts))
                }
            }
        }
        flush()
        return out
    }

    /// One walk on one level, cut where it bends by more than `turnDegrees`.
    static func splitWalk(_ map: StationMap, _ pts: [Pt], level: String, seconds: Double) -> [Step] {
        let s = resample(pts, every: resampleM)
        guard s.count > 2 else {
            return [Step(key: .walk, distanceM: length(pts), turn: nil, landmark: nil, at: pts[0], level: level, seconds: seconds, points: pts)]
        }
        let w = Int(windowM / resampleM)
        // Where the bearing before a point and after it differ by more than the threshold, the sharpest point of each
        // such stretch is the turn.
        var cuts: [(index: Int, angle: Double)] = []
        var i = w
        while i < s.count - w {
            let a = bearing(s[i - w], s[i])
            let b = bearing(s[i], s[i + w])
            let d = delta(a, b)
            if abs(d) > turnDegrees {
                var best = (index: i, angle: d)
                var j = i + 1
                while j < s.count - w {
                    let dj = delta(bearing(s[j - w], s[j]), bearing(s[j], s[j + w]))
                    if abs(dj) <= turnDegrees { break }
                    if abs(dj) > abs(best.angle) { best = (j, dj) }
                    j += 1
                }
                cuts.append(best)
                i = j + w
            } else {
                i += 1
            }
        }
        let total = length(s)
        var out: [Step] = []
        var start = 0
        let bounds = cuts.map(\.index) + [s.count - 1]
        for (n, end) in bounds.enumerated() {
            let piece = Array(s[start...end])
            // The first piece's turn isn't known (it follows a start, or stairs): only bends inside the walk are turns.
            let turn: Turn? = n == 0 ? nil : turnFor(cuts[n - 1].angle)
            let dist = length(piece)
            let dir = start + 1 < s.count ? norm(Pt(s[min(start + w, s.count - 1)].x - s[start].x, s[min(start + w, s.count - 1)].y - s[start].y)) : nil
            // The landmark sits at the turn: seen from the way in (before the turn).
            let inDir = n == 0 ? dir : norm(Pt(s[start].x - s[max(start - w, 0)].x, s[start].y - s[max(start - w, 0)].y))
            out.append(Step(key: .walk, distanceM: dist, turn: turn, landmark: landmark(map, at: s[start], level: level, dir: inDir ?? dir), at: s[start], level: level,
                            seconds: total > 0 ? seconds * dist / total : 0, points: piece))
            start = end
        }
        return out
    }

    static func turnFor(_ angle: Double) -> Turn {
        if abs(angle) > 150 { return .uTurn }
        // x east, y south: a clockwise change of bearing is a turn to the right.
        return angle > 0 ? .right : .left
    }

    /// The nearest named place within 10 m of a point on the level, and its side of the way.
    static func landmark(_ map: StationMap, at p: Pt, level: String, dir: Pt?) -> Landmark? {
        guard let dir else { return nil }
        let near = map.pois.filter { $0.level == level && !$0.name.isEmpty && $0.approximate != true }
            .map { ($0, hypot($0.x - p.x, $0.y - p.y)) }
            .filter { $0.1 <= landmarkM }
            .min { $0.1 < $1.1 }
        guard let (poi, _) = near else { return nil }
        // Cross product in a y-south frame: positive is to the right of the way.
        let cross = dir.x * (poi.y - p.y) - dir.y * (poi.x - p.x)
        return Landmark(poiId: poi.id, name: poi.name, side: cross > 0 ? .right : .left)
    }

    // MARK: geometry

    static func same(_ a: Pt, _ b: Pt) -> Bool { abs(a.x - b.x) < 0.01 && abs(a.y - b.y) < 0.01 }

    public static func length(_ pts: [Pt]) -> Double {
        zip(pts, pts.dropFirst()).reduce(0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
    }

    /// Degrees clockwise from north (up, −y) from a to b.
    public static func bearing(_ a: Pt, _ b: Pt) -> Double {
        let deg = atan2(b.x - a.x, -(b.y - a.y)) * 180 / .pi
        return deg < 0 ? deg + 360 : deg
    }

    /// The signed change from bearing a to b, −180…180 (positive clockwise).
    static func delta(_ a: Double, _ b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    static func norm(_ v: Pt) -> Pt? {
        let l = hypot(v.x, v.y)
        return l > 1e-6 ? Pt(v.x / l, v.y / l) : nil
    }

    /// Points every `every` metres along a polyline, both ends kept.
    public static func resample(_ pts: [Pt], every: Double) -> [Pt] {
        guard let first = pts.first else { return [] }
        var out = [first]
        var carry = 0.0
        for (a, b) in zip(pts, pts.dropFirst()) {
            let len = hypot(b.x - a.x, b.y - a.y)
            guard len > 0 else { continue }
            var d = every - carry
            while d <= len {
                out.append(Pt(a.x + (b.x - a.x) * d / len, a.y + (b.y - a.y) * d / len))
                d += every
            }
            carry = len - (d - every)
        }
        if let last = pts.last, let end = out.last, hypot(end.x - last.x, end.y - last.y) > 0.5 { out.append(last) }
        return out
    }

    /// The point `s` metres along a polyline, and the bearing there.
    public static func point(along pts: [Pt], at s: Double) -> (pt: Pt, bearing: Double)? {
        guard pts.count > 1 else { return pts.first.map { ($0, 0) } }
        var left = max(0, s)
        for (a, b) in zip(pts, pts.dropFirst()) {
            let len = hypot(b.x - a.x, b.y - a.y)
            if left <= len, len > 0 {
                return (Pt(a.x + (b.x - a.x) * left / len, a.y + (b.y - a.y) * left / len), bearing(a, b))
            }
            left -= len
        }
        let a = pts[pts.count - 2], b = pts[pts.count - 1]
        return (b, bearing(a, b))
    }

    /// The nearest point of a polyline to `p`: how far along it is, and how far away.
    public static func project(_ p: Pt, on pts: [Pt]) -> (s: Double, distance: Double)? {
        guard pts.count > 1 else { return nil }
        var best: (s: Double, distance: Double)?
        var run = 0.0
        for (a, b) in zip(pts, pts.dropFirst()) {
            let dx = b.x - a.x, dy = b.y - a.y
            let l2 = dx * dx + dy * dy
            let t = l2 > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0
            let d = hypot(a.x + dx * t - p.x, a.y + dy * t - p.y)
            if best == nil || d < best!.distance { best = (run + t * sqrt(l2), d) }
            run += sqrt(l2)
        }
        return best
    }
}

extension RouteGuide {
    /// The template and values for a step (keys under `stationMap.step.`, en and sv in the String Catalog). Distances
    /// are rounded to 5 m (to 1 m under 10 m): a phone indoors can't count closer than that.
    public static func wording(_ step: Step, levelName: (String) -> String, sideName: (Side) -> String) -> (key: String, values: [String: String]) {
        let m = step.distanceM < 10 ? max(1, Int(step.distanceM.rounded())) : Int((step.distanceM / 5).rounded()) * 5
        var values = ["m": String(m)]
        guard step.key == .walk else {
            values["level"] = levelName(step.level)
            return ("stationMap.step.\(step.key.rawValue)", values)
        }
        if let landmark = step.landmark {
            values["landmark"] = landmark.name
            values["side"] = sideName(landmark.side)
        }
        switch step.turn {
        case .left: return (step.landmark == nil ? "stationMap.step.turnLeftPlain" : "stationMap.step.turnLeft", values)
        case .right: return (step.landmark == nil ? "stationMap.step.turnRightPlain" : "stationMap.step.turnRight", values)
        case .uTurn: return ("stationMap.step.uTurn", values)
        case .straight, nil: return (step.landmark == nil ? "stationMap.step.continuePlain" : "stationMap.step.continue", values)
        }
    }
}
