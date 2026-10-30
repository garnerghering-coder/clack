import Foundation

/// A platform's lettered sectors ("2a", "2b") and the lines across it where one meets the next, in the map's metres
/// (owner, 2026-10-30: the a and b pieces marked separately when zoomed in). The same rule as the server's
/// `platformSectors` (packages/shared/src/station.ts): a sector's line is its edge (BanInfo's track line or the
/// platform edge); its label sits on the platform's cross-section at the line's middle; a divider is the
/// cross-section halfway between two sectors' facing ends.
public nonisolated enum PlatformSectors {
    public struct Sector: Hashable, Sendable {
        public let sector: String
        public let label: Pt
        /// The middle of the platform along the sector, every 10 m.
        public let line: [Pt]
    }

    public static func of(_ p: StationPlatform) -> (sectors: [Sector], dividers: [(Pt, Pt)]) {
        let base = p.ref.trimmingCharacters(in: .whitespaces).lowercased()
        let lines = (p.edges ?? []).filter { e in
            guard let t = e.track, e.points.count >= 2, let last = t.last, last.isLetter, t.dropLast().allSatisfy(\.isNumber), !t.dropLast().isEmpty else { return false }
            return String(t.dropLast()) == base
        }
        guard lines.count >= 2, !p.geometry.isEmpty else { return ([], []) }
        let all = lines.flatMap(\.points)
        let a = all[0], b = all[all.count - 1]
        let dir = unit(Pt(b.x - a.x, b.y - a.y)) ?? Pt(1, 0)
        func along(_ q: Pt) -> Double { (q.x - a.x) * dir.x + (q.y - a.y) * dir.y }
        let sorted = lines.map { e -> (e: PlatformEdge, lo: Double, hi: Double) in
            let t = e.points.map(along)
            return (e, t.min() ?? 0, t.max() ?? 0)
        }.sorted { $0.lo < $1.lo }
        let sectors = sorted.map { s -> Sector in
            let mid = midpointAlong(s.e.points)
            let label = crossSection(p.geometry, at: mid, direction: localDirection(s.e.points, near: mid)).map { Pt(($0.0.x + $0.1.x) / 2, ($0.0.y + $0.1.y) / 2) } ?? mid
            let line = resample(s.e.points, step: 10).compactMap { q in
                crossSection(p.geometry, at: q, direction: localDirection(s.e.points, near: q)).map { Pt(($0.0.x + $0.1.x) / 2, ($0.0.y + $0.1.y) / 2) }
            }
            return Sector(sector: s.e.track ?? "", label: label, line: line)
        }
        var dividers: [(Pt, Pt)] = []
        for i in 0..<(sorted.count - 1) {
            let t = (sorted[i].hi + sorted[i + 1].lo) / 2
            let ordered = (sorted[i].e.points + sorted[i + 1].e.points).sorted { along($0) < along($1) }
            let j = max(1, ordered.firstIndex { along($0) >= t } ?? ordered.count - 1)
            let q0 = ordered[j - 1], q1 = ordered[min(j, ordered.count - 1)]
            let span = along(q1) - along(q0)
            let f = span > 1e-6 ? (t - along(q0)) / span : 0
            let at = Pt(q0.x + (q1.x - q0.x) * f, q0.y + (q1.y - q0.y) * f)
            if let cut = crossSection(p.geometry, at: at, direction: unit(Pt(q1.x - q0.x, q1.y - q0.y)) ?? dir) { dividers.append(cut) }
        }
        return (sectors, dividers)
    }

    /// The platform's width at `q` across `d`: where the line through `q` square to `d` crosses the outline, the stretch
    /// holding `q` or else the nearest within 15 m (q may lie just off the platform, on its track line).
    static func crossSection(_ rings: [[Pt]], at q: Pt, direction d: Pt) -> (Pt, Pt)? {
        let n = Pt(-d.y, d.x)
        var ts: [Double] = []
        for ring in rings where !ring.isEmpty {
            for i in ring.indices {
                let p0 = ring[i], p1 = ring[(i + 1) % ring.count]
                let ex = p1.x - p0.x, ey = p1.y - p0.y
                let den = n.x * ey - n.y * ex
                if abs(den) < 1e-9 { continue }
                let t = ((p0.x - q.x) * ey - (p0.y - q.y) * ex) / den
                let s = ((p0.x - q.x) * n.y - (p0.y - q.y) * n.x) / den
                if s >= 0 && s <= 1 { ts.append(t) }
            }
        }
        ts.sort()
        func gap(_ s: (Double, Double)) -> Double { s.0 <= 0 && s.1 >= 0 ? 0 : min(abs(s.0), abs(s.1)) }
        var best: (Double, Double)?
        var i = 0
        while i + 1 < ts.count {
            let span = (ts[i], ts[i + 1])
            if span.1 - span.0 >= 0.3, best.map({ gap(span) < gap($0) }) ?? true { best = span }
            i += 2
        }
        guard let best, gap(best) <= 15 else { return nil }
        return (Pt(q.x + n.x * best.0, q.y + n.y * best.0), Pt(q.x + n.x * best.1, q.y + n.y * best.1))
    }

    static func unit(_ v: Pt) -> Pt? {
        let l = hypot(v.x, v.y)
        return l > 1e-6 ? Pt(v.x / l, v.y / l) : nil
    }

    static func localDirection(_ pts: [Pt], near q: Pt) -> Pt {
        var best: Pt?, bestD = Double.infinity
        for i in 0..<(pts.count - 1) {
            let d = hypot((pts[i].x + pts[i + 1].x) / 2 - q.x, (pts[i].y + pts[i + 1].y) / 2 - q.y)
            if d < bestD, let u = unit(Pt(pts[i + 1].x - pts[i].x, pts[i + 1].y - pts[i].y)) { (best, bestD) = (u, d) }
        }
        return best ?? Pt(1, 0)
    }

    /// Points every `step` metres along a polyline, both ends included.
    static func resample(_ pts: [Pt], step: Double) -> [Pt] {
        guard var last = pts.first else { return [] }
        var out = [last]
        var carry = 0.0
        for i in 0..<(pts.count - 1) {
            let a = pts[i], b = pts[i + 1]
            let len = hypot(b.x - a.x, b.y - a.y)
            var d = step - carry
            while d <= len {
                last = Pt(a.x + (b.x - a.x) * d / len, a.y + (b.y - a.y) * d / len)
                out.append(last)
                d += step
            }
            carry = len - (d - step)
        }
        if let end = pts.last, hypot(end.x - last.x, end.y - last.y) > 1 { out.append(end) }
        return out
    }

    static func midpointAlong(_ pts: [Pt]) -> Pt {
        let seg = (1..<pts.count).map { hypot(pts[$0].x - pts[$0 - 1].x, pts[$0].y - pts[$0 - 1].y) }
        var left = seg.reduce(0, +) / 2
        for i in seg.indices {
            if left <= seg[i] {
                let f = seg[i] > 0 ? left / seg[i] : 0
                return Pt(pts[i].x + (pts[i + 1].x - pts[i].x) * f, pts[i].y + (pts[i + 1].y - pts[i].y) * f)
            }
            left -= seg[i]
        }
        return pts[pts.count - 1]
    }
}
