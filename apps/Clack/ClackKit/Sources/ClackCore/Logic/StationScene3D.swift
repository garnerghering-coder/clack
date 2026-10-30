//
//  StationScene3D.swift
//  Clack
//

import Foundation

/// The 3D station view (one-station demo, Jönköping C): what to draw, as plain values the app turns into RealityKit
/// meshes. Scene coordinates are metres: x east, y up, z south (the map's local y), origin at the map's origin.
/// Nothing here is drawn that the map doesn't give; where a height is missing a stated default stands in and the
/// scene says so (`notes`).
public nonisolated enum StationScene3D {
    // MARK: values

    public struct Vec3: Hashable, Sendable {
        public var x: Double
        public var y: Double
        public var z: Double
        public init(_ x: Double, _ y: Double, _ z: Double) {
            self.x = x
            self.y = y
            self.z = z
        }
    }

    /// An upright prism: a footprint (x, z as the map's x, y) between two heights.
    public struct Prism: Hashable, Sendable {
        public let footprint: [Pt]
        public let bottom: Double
        public let top: Double
        public init(footprint: [Pt], bottom: Double, top: Double) {
            self.footprint = footprint
            self.bottom = bottom
            self.top = top
        }
    }

    public struct Platform3D: Hashable, Sendable {
        public let id: String
        public let ref: String
        public let pieces: [Prism]
        /// True when the map gives no height and `standardPlatformHeight` stands in.
        public let isStandardHeight: Bool
    }

    /// A flat strip along a line at one height (a track).
    public struct Strip: Hashable, Sendable {
        public let points: [Pt]
        public let width: Double
        public let y: Double
    }

    /// Stairs or an escalator as a sloping strip, lower end first.
    public struct Ramp: Hashable, Sendable {
        public let kind: EdgeKind
        public let points: [Vec3]
        public let width: Double
    }

    /// A floor above the ground level, from an outline the map has on that level.
    public struct Slab: Hashable, Sendable {
        public let level: String
        public let prism: Prism
    }

    public struct Building: Hashable, Sendable {
        public let prism: Prism
        public let heightKnown: Bool
        public let name: String?
    }

    /// A roof seen from above (a platform canopy, a footbridge): its top is measured, its underside isn't, so it is
    /// drawn as a thin sheet `roofThickness` under the top.
    public struct Roof: Hashable, Sendable {
        public let prism: Prism
        public let name: String?
    }

    /// What the panel must say about the scene (accuracy first).
    public struct Notes: Hashable, Sendable {
        public var draft = false
        public var standardPlatformHeight = false
        public var buildingHeightUnknown = false
        /// Stairs or escalators drawn at the standard slope because their ends in the data are too far apart for one flight.
        public var rampSlopeStandard = false
        /// Roofs are drawn from their measured tops; what is under them (a canopy's underside, a footbridge's deck) isn't.
        public var roofUndersideUnknown = false
        /// A footbridge's underside is drawn at a stated minimum (its `_source` says which), not measured.
        public var bridgeUndersideMinimum = false
        /// The map has no ground heights: the ground is drawn flat at rail level.
        public var flatGround = false
        /// Heights from Lantmäteriet's laser data (CC BY 4.0: the panel credits it).
        public var lantmateriet = false
        /// Platform heights from Trafikverket's register.
        public var trafikverket = false
    }

    /// Scene heights are the map's: metres above the platform surface (0). The rails sit at `railY`, the platform
    /// height below it.
    public struct Scene: Sendable {
        /// The ground's extent: min x, min z, max x, max z.
        public let ground: (minX: Double, minZ: Double, maxX: Double, maxZ: Double)
        /// The rail head, and the flat ground where the map has no terrain.
        public let railY: Double
        /// The ground's surface from the map's terrain grid (nil: flat at `railY`).
        public let terrain: MeshData?
        /// Below the terrain's lowest point, so the ground has no holes where the grid has no values.
        public let backdropY: Double
        public let platforms: [Platform3D]
        public let tracks: [Strip]
        public let slabs: [Slab]
        public let ramps: [Ramp]
        /// Lifts, and stairs or escalators whose two ends are at one point, as upright columns.
        public let columns: [Prism]
        public let buildings: [Building]
        public let roofs: [Roof]
        /// The extent of the platforms (min x, min z, max x, max z), what the starting camera frames.
        public let focus: (minX: Double, minZ: Double, maxX: Double, maxZ: Double)
        public let notes: Notes
    }

    // MARK: stated defaults

    /// Platform surface above the rail head when the map has no measured height: 0.55 m, the TSI's nominal low
    /// platform (EU 1299/2014 §4.2.9.2), which Trafikverket's TDOK 2014:0686 §5.2 uses for new and rebuilt platforms
    /// (Trafikverket PM TRV 2020/105979, 2020-10-06). Older Swedish platforms are 580 mm. A standard, not measured.
    public static let standardPlatformHeight = 0.55
    /// Box height for a building whose height no source gives (drawn, and said to be unknown).
    public static let defaultBuildingHeight = 4.0
    public static let slabThickness = 0.3
    /// How thick a roof is drawn under its measured top (a drawing choice: the underside isn't measured).
    public static let roofThickness = 0.4
    public static let trackWidth = 1.5
    public static let rampWidth = 1.6
    public static let liftSize = 2.0
    /// The slope stairs and escalators are drawn at when their ends are too far apart: 30°, the maximum escalator
    /// inclination in EN 115-1 (35° is allowed only up to a 6 m rise) and within the usual range for stairs.
    public static let rampSlopeDeg = 30.0
    /// Ramps shorter than this along the ground are drawn as a column: their two ends sit at one point in the data.
    static let minRampRun = 1.0

    // MARK: building the scene

    /// A level's floor, metres above the platform surface (the reference level is 0).
    public static func levelHeight(_ map: StationMap, _ id: String) -> Double {
        map.levels.first { $0.id == id }?.heightM ?? 0
    }

    /// The platform height the scene uses for the rails: the median of the platforms' measured heights, else the
    /// standard.
    public static func platformHeight(_ map: StationMap) -> Double {
        let known = map.platforms.compactMap(\.heightM).sorted()
        return known.isEmpty ? standardPlatformHeight : known[known.count / 2]
    }

    public static func build(_ map: StationMap) -> Scene {
        var notes = Notes()
        notes.draft = map.quality == .osmDraft
        notes.lantmateriet = map.sources.contains { $0.type == "lantmateriet" }
        notes.trafikverket = map.sources.contains { $0.type == "trafikverket" } && map.platforms.contains { $0.heightM != nil }
        let nodes = Dictionary(map.nodes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let ground0 = map.levels.min { $0.order < $1.order }?.id
        let railY = -platformHeight(map)

        var platforms: [Platform3D] = []
        for p in map.platforms {
            let top = levelHeight(map, p.level)
            let h = p.heightM ?? standardPlatformHeight
            if p.heightM == nil { notes.standardPlatformHeight = true }
            let pieces = p.geometry.map(clean).filter { $0.count >= 3 }.map { Prism(footprint: $0, bottom: top - h, top: top) }
            platforms.append(Platform3D(id: p.id, ref: p.ref, pieces: pieces, isStandardHeight: p.heightM == nil))
        }

        let tracks = map.shapes.filter { $0.kind == .track && $0.points.count >= 2 }
            .map { Strip(points: $0.points, width: trackWidth, y: levelHeight(map, $0.level) + railY + 0.01) }

        var buildings: [Building] = []
        var roofs: [Roof] = []
        for s in map.shapes where s.kind == .building || s.kind == .roof || s.kind == .bridge {
            let pts = clean(s.points)
            guard pts.count >= 3 else { continue }
            if s.kind == .bridge {
                guard let top = s.topM, let base = s.baseM, top > base else { continue }
                notes.bridgeUndersideMinimum = true
                buildings.append(Building(prism: Prism(footprint: pts, bottom: base, top: top), heightKnown: true, name: s.name))
                continue
            }
            if s.kind == .roof {
                guard let top = s.topM else { continue }
                notes.roofUndersideUnknown = true
                roofs.append(Roof(prism: Prism(footprint: pts, bottom: top - roofThickness, top: top), name: s.name))
                continue
            }
            // From the lowest ground at the outline (hidden under the terrain where the ground rises) to the top.
            let base = s.baseM ?? terrainMin(map.terrain, under: pts) ?? levelHeight(map, s.level) + railY
            let known = s.topM != nil || s.heightM != nil
            if !known { notes.buildingHeightUnknown = true }
            let top = s.topM ?? base + (s.heightM ?? defaultBuildingHeight)
            buildings.append(Building(prism: Prism(footprint: pts, bottom: min(base, top - 0.5), top: top), heightKnown: known, name: s.name))
        }

        // Floors above the ground, only where the map has their outline (a building or hall on that level). Nothing is
        // drawn from the walkway points alone: at Jönköping C the "upper level" is the town's ground (the terrain).
        var slabs: [Slab] = []
        for level in map.levels where level.id != ground0 && levelHeight(map, level.id) > 0 {
            let top = levelHeight(map, level.id)
            for s in map.shapes where s.level == level.id && (s.kind == .building || s.kind == .hall) {
                let pts = clean(s.points)
                if pts.count >= 3 { slabs.append(Slab(level: level.id, prism: Prism(footprint: pts, bottom: top - slabThickness, top: top))) }
            }
        }

        var ramps: [Ramp] = []
        var columns: [Prism] = []
        let floors = map.levels.map { levelHeight(map, $0.id) }
        for e in map.edges where e.kind != .walk {
            guard let a = nodes[e.from], let b = nodes[e.to] else { continue }
            let ha = levelHeight(map, a.level), hb = levelHeight(map, b.level)
            if e.kind == .lift {
                // The lift shaft: a box at the edge's middle, from the lowest floor to the top one.
                let c = Pt((a.x + b.x) / 2, (a.y + b.y) / 2)
                columns.append(Prism(footprint: square(c, liftSize), bottom: min(floors.min() ?? 0, min(ha, hb)), top: max(floors.max() ?? 0, max(ha, hb))))
                continue
            }
            guard ha != hb else { continue }
            var line = [Pt(a.x, a.y)] + (e.geometry.map { Array($0.dropFirst().dropLast()) } ?? []) + [Pt(b.x, b.y)]
            var (h0, h1) = (ha, hb)
            if ha > hb {
                line.reverse()
                (h0, h1) = (hb, ha)
            }
            var run = length(line)
            if run < minRampRun {
                columns.append(Prism(footprint: square(line[0], 1.2), bottom: h0, top: h1))
                continue
            }
            // Walk marks place the ends only to about ±10 m, which can stretch one flight over 50 m. When the run is
            // more than twice what the rise needs at `rampSlopeDeg`, draw that run instead, ending at the upper end
            // and pointing toward the lower one.
            let standardRun = (h1 - h0) / tan(rampSlopeDeg * .pi / 180)
            if run > 2 * standardRun, let top = line.last, let from = line.first {
                let k = standardRun / max(1e-9, hypot(top.x - from.x, top.y - from.y))
                line = [Pt(top.x + (from.x - top.x) * k, top.y + (from.y - top.y) * k), top]
                run = standardRun
                notes.rampSlopeStandard = true
            }
            let cum = cumulative(line)
            let pts = zip(line, cum).map { p, d in Vec3(p.x, h0 + (h1 - h0) * d / run, p.y) }
            ramps.append(Ramp(kind: e.kind, points: pts, width: rampWidth))
        }

        // The ground covers what is drawn, not every walkway node (a footway's far end can be hundreds of metres off).
        var all: [Pt] = map.shapes.flatMap(\.points) + map.platforms.flatMap { $0.geometry.flatMap { $0 } }
            + slabs.flatMap(\.prism.footprint) + columns.flatMap(\.footprint) + ramps.flatMap { $0.points.map { Pt($0.x, $0.z) } }
        if all.isEmpty { all = [Pt(0, 0)] }
        let ground = bounds(all, pad: 20)
        let platformPts = map.platforms.flatMap { $0.geometry.flatMap { $0 } }
        let focus = platformPts.isEmpty ? ground : bounds(platformPts, pad: 0)
        let terrain = map.terrain.map(terrainMesh)
        notes.flatGround = terrain == nil
        let lowest = map.terrain.flatMap { $0.heights.flatMap { $0 }.compactMap { $0 }.min() } ?? railY
        return Scene(ground: ground, railY: railY, terrain: terrain, backdropY: min(lowest, railY) - 0.05, platforms: platforms, tracks: tracks, slabs: slabs, ramps: ramps, columns: columns, buildings: buildings, roofs: roofs, focus: focus, notes: notes)
    }

    // MARK: the ground

    /// The terrain grid as triangles: two per cell whose four corners have values.
    public static func terrainMesh(_ t: StationMap.Terrain) -> MeshData {
        var m = MeshData()
        func h(_ i: Int, _ j: Int) -> Double? { j < t.heights.count && i < t.heights[j].count ? t.heights[j][i] : nil }
        for j in 0..<max(0, t.rows - 1) {
            for i in 0..<max(0, t.cols - 1) {
                guard let a = h(i, j), let b = h(i + 1, j), let c = h(i + 1, j + 1), let d = h(i, j + 1) else { continue }
                let x0 = t.x0 + Double(i) * t.step, z0 = t.y0 + Double(j) * t.step, x1 = x0 + t.step, z1 = z0 + t.step
                m.triangle(Vec3(x0, a, z0), Vec3(x1, b, z0), Vec3(x1, c, z1), facing: Vec3(0, 1, 0))
                m.triangle(Vec3(x0, a, z0), Vec3(x1, c, z1), Vec3(x0, d, z1), facing: Vec3(0, 1, 0))
            }
        }
        return m
    }

    /// The ground height at a point (bilinear between the grid's values), nil off the grid.
    public static func terrainHeight(_ t: StationMap.Terrain, x: Double, y: Double) -> Double? {
        let fi = (x - t.x0) / t.step, fj = (y - t.y0) / t.step
        guard t.cols >= 2, t.rows >= 2, t.heights.count >= t.rows, fi >= 0, fj >= 0, fi <= Double(t.cols - 1), fj <= Double(t.rows - 1) else { return nil }
        let i = min(Int(floor(fi)), t.cols - 2), j = min(Int(floor(fj)), t.rows - 2)
        let u = fi - Double(i), v = fj - Double(j)
        // Only the corners that carry weight need a value (a point on a grid line uses two, on a grid point one).
        var sum = 0.0
        for (ci, cj, w) in [(i, j, (1 - u) * (1 - v)), (i + 1, j, u * (1 - v)), (i, j + 1, (1 - u) * v), (i + 1, j + 1, u * v)] where w > 1e-9 {
            guard ci < t.heights[cj].count, let h = t.heights[cj][ci] else { return nil }
            sum += h * w
        }
        return sum
    }

    /// The lowest ground under an outline's corners, nil without a terrain grid there.
    static func terrainMin(_ t: StationMap.Terrain?, under pts: [Pt]) -> Double? {
        guard let t else { return nil }
        return pts.compactMap { terrainHeight(t, x: $0.x, y: $0.y) }.min()
    }

    // MARK: trains at the platforms

    /// How far a train runs in its 60 s of braking in or pulling out: uniform braking from 40 km/h. An illustration
    /// of arriving and leaving, not a measured run.
    public static let slideMeters = 330.0
    /// Straight run added at each end of a platform's track so a train can slide in from beyond the mapped rails.
    static let runOut = 600.0

    /// The track a platform's trains stand on, in local metres, lengthened `runOut` at both ends: the track shape
    /// whose number the platform serves, else the track shape nearest the platform's edge for its track (or its
    /// outline). Nil when the map has no track near the platform (within 10 m on average).
    public static func platformTrack(_ map: StationMap, platform p: StationPlatform) -> [Pt]? {
        let shapes = map.shapes.filter { $0.kind == .track && $0.points.count >= 2 }
        let line: [Pt]
        if let byRef = shapes.first(where: { $0.ref.map { p.tracks.contains($0) } ?? false }) {
            line = byRef.points
        } else {
            let edge = p.edges?.first { $0.track.map { p.tracks.contains($0) } ?? false } ?? p.edges?.first
            let probe = edge?.points ?? p.geometry.flatMap { $0 }
            guard !probe.isEmpty else { return nil }
            let scored = shapes.map { s in (s, probe.map { distance($0, to: s.points) }.reduce(0, +) / Double(probe.count)) }
            guard let best = scored.min(by: { $0.1 < $1.1 }), best.1 <= 10 else { return nil }
            line = best.0.points
        }
        return lengthen(line, by: runOut)
    }

    /// Where along `track` the platform's middle is, metres (the projection of its outline's extent); for a sector the
    /// board names ("2a") the middle of that sector's edge when the map has one (trains wait at their part).
    public static func platformMiddle(_ p: StationPlatform, track: [Pt], sector: String? = nil) -> Double {
        let s = (sector ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        if let last = s.last, last.isLetter, let edge = p.edges?.first(where: { $0.track == s && $0.points.count >= 2 }) {
            let along = edge.points.map { project($0, on: track) }
            if let lo = along.min(), let hi = along.max() { return (lo + hi) / 2 }
        }
        let along = p.geometry.flatMap { $0 }.map { project($0, on: track) }
        guard let lo = along.min(), let hi = along.max() else { return length(track) / 2 }
        return (lo + hi) / 2
    }

    /// One car as drawn: its middle on the ground (local metres) and its yaw about +y, for a box whose length runs
    /// along its local x axis.
    public struct CarPlace: Hashable, Sendable {
        public let x: Double
        public let z: Double
        public let yaw: Double
    }

    /// The cars of a train standing with its middle at the platform's middle, moved `offsetM` along the track (negative
    /// before it arrives, positive as it leaves). The car maths is TrainKit's, on the track turned into WGS84.
    public static func carPlaces(_ map: StationMap, track: [Pt], middleM: Double, offsetM: Double, count: Int, carLength: Double) -> [CarPlace] {
        let geo = track.map { StationRouting.toWGS84(map, x: $0.x, y: $0.y) }
        let head = middleM + TrainKit.trainLength(count: count, carLength: carLength) / 2 + offsetM
        // TrainKit measures on the sphere, the map's frame with its own metres per degree (about 0.5 % apart): carry
        // the head's place over segment by segment so the train stands where the map says.
        let local = cumulative(track), sphere = TrainKit.cumulative(geo)
        var i = 1
        while i < local.count - 1 && local[i] < head { i += 1 }
        let seg = local[i] - local[i - 1]
        let headOnSphere = sphere[i - 1] + (seg > 0 ? (head - local[i - 1]) / seg : 0) * (sphere[i] - sphere[i - 1])
        return TrainKit.carPoses(track: geo, headM: headOnSphere, count: count, carLength: carLength).map { pose in
            let p = StationRouting.toLocal(map, lat: pose.center.lat, lon: pose.center.lon)
            return CarPlace(x: p.x, z: p.y, yaw: (90 - pose.headingDeg) * .pi / 180)
        }
    }

    /// A car's box size (width, height) in metres: 3.0 m wide, 3.8 m high, 4.6 m for double-deck. Typical Nordic
    /// loading-gauge values for the drawing, not any one type's measurements.
    public static func carSize(_ t: TrainKit.Template) -> (width: Double, height: Double) {
        (3.0, t == .doubleDeck ? 4.6 : 3.8)
    }

    /// Design, car count and car length for a train type (nil when the board doesn't name one).
    public static func cars(for type: TrainType?) -> (template: TrainKit.Template, count: Int, length: Double) {
        let t = TrainKit.template(forArt: type?.art)
        return (t, TrainKit.carCount(live: nil, typical: type?.cars, template: t).count, TrainKit.carLength(t))
    }

    // MARK: the schedule

    public enum TrainState: String, Hashable, Sendable {
        /// Within 30 minutes, not yet in the 60 s before arriving (listed, not drawn).
        case upcoming
        case arriving, standing, leaving
    }

    public struct Scene3DTrain: Hashable, Sendable, Identifiable {
        public let id: String
        public let trainNumber: String
        public let operatorId: String?
        public let trainType: String?
        /// As the board gives it ("2a"), nil when it gives none.
        public let platform: String?
        /// The map's platform it stands at, nil when the board has none or the map lacks it.
        public let platformId: String?
        public let destination: String?
        public let origin: String?
        public let arrival: Double?
        public let departure: Double?
        public let state: TrainState
        /// Metres along the track from where it stands: negative while arriving, positive while leaving.
        public let offsetM: Double

        public var moving: Bool { state == .arriving || state == .leaving }
    }

    public static let windowMs = 30 * 60_000.0
    public static let slideMs = 60_000.0
    /// How long a train that starts or ends here is drawn at its platform before departing or after arriving, when
    /// the board gives only the one time (a display choice: the board doesn't say).
    public static let endLeadMs = 180_000.0

    /// The trains to show at `now` (epoch ms), from the arrivals and departures boards, joined by trip (else train
    /// number). Cancelled rows are left out. A train whose platform is missing or not on the map has no `platformId`:
    /// list it, don't draw it.
    public static func trainStates(arrivals: [BoardRow], departures: [BoardRow], now: Double, map: StationMap) -> [Scene3DTrain] {
        func key(_ r: BoardRow) -> String { r.trip?.key ?? r.trainNumber }
        var arr: [String: BoardRow] = [:]
        var dep: [String: BoardRow] = [:]
        for r in arrivals where !r.canceled { arr[key(r)] = arr[key(r)] ?? r }
        for r in departures where !r.canceled { dep[key(r)] = dep[key(r)] ?? r }
        var out: [Scene3DTrain] = []
        for k in Set(arr.keys).union(dep.keys) {
            let a = arr[k], d = dep[k]
            guard let state = state(arrival: a?.shown, departure: d?.shown, now: now) else { continue }
            let row = d ?? a!
            let platform = d?.platform ?? a?.platform
            out.append(Scene3DTrain(
                id: k, trainNumber: row.trainNumber, operatorId: row.operatorId, trainType: d?.trainType ?? a?.trainType,
                platform: platform, platformId: StationRouting.platform(forTrack: platform, in: map)?.id,
                destination: d?.endpoints.first, origin: a?.endpoints.first,
                arrival: a?.shown, departure: d?.shown, state: state.0, offsetM: state.1
            ))
        }
        return out.sorted { ($0.arrival ?? $0.departure ?? 0, $0.id) < ($1.arrival ?? $1.departure ?? 0, $1.id) }
    }

    /// The state and offset at `now` from the two times (either may be missing); nil when not shown.
    static func state(arrival: Double?, departure: Double?, now: Double) -> (TrainState, Double)? {
        if let departure, now >= departure {
            let s = (now - departure) / slideMs
            return s <= 1 ? (.leaving, slideMeters * s * s) : nil
        }
        if let arrival, now < arrival {
            let t = (arrival - now) / slideMs
            if t <= 1 { return (.arriving, -slideMeters * t * t) }
            return arrival - now <= windowMs ? (.upcoming, 0) : nil
        }
        if let arrival {
            // Arrived; standing until it leaves, or for a while if it ends here.
            if departure == nil { return now - arrival <= endLeadMs ? (.standing, 0) : nil }
            return (.standing, 0)
        }
        guard let departure else { return nil }
        // Starts here: drawn at its platform for a while before it leaves.
        if departure - now <= endLeadMs { return (.standing, 0) }
        return departure - now <= windowMs ? (.upcoming, 0) : nil
    }

    /// The next moment any train's state changes (epoch ms), so the view wakes only then when nothing moves.
    public static func nextChange(_ trains: [Scene3DTrain], now: Double) -> Double? {
        var times: [Double] = []
        for t in trains {
            if let a = t.arrival { times += [a - slideMs, a, a + endLeadMs] }
            if let d = t.departure { times += [d - endLeadMs, d, d + slideMs] }
        }
        return times.filter { $0 > now }.min()
    }

    // MARK: meshes

    /// Triangles ready for a mesh: positions, normals (flat per face) and indices, counter-clockwise from outside.
    public struct MeshData: Sendable {
        public var positions: [SIMD3<Float>] = []
        public var normals: [SIMD3<Float>] = []
        public var indices: [UInt32] = []
        public init() {}

        mutating func triangle(_ a: Vec3, _ b: Vec3, _ c: Vec3, facing want: Vec3) {
            let n = cross(sub(b, a), sub(c, a))
            let (p, q, r) = dot(n, want) >= 0 ? (a, b, c) : (a, c, b)
            let nn = normalized(dot(n, want) >= 0 ? n : Vec3(-n.x, -n.y, -n.z))
            let base = UInt32(positions.count)
            for v in [p, q, r] {
                positions.append(SIMD3(Float(v.x), Float(v.y), Float(v.z)))
                normals.append(SIMD3(Float(nn.x), Float(nn.y), Float(nn.z)))
            }
            indices += [base, base + 1, base + 2]
        }

        mutating func quad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3, facing want: Vec3) {
            triangle(a, b, c, facing: want)
            triangle(a, c, d, facing: want)
        }

        public mutating func append(_ other: MeshData) {
            let base = UInt32(positions.count)
            positions += other.positions
            normals += other.normals
            indices += other.indices.map { $0 + base }
        }
    }

    /// A prism's top, walls and (when `bottom` is set) its underside.
    public static func mesh(_ p: Prism, bottomCap: Bool = false) -> MeshData {
        var m = MeshData()
        let pts = p.footprint
        let sign: Double = signedArea(pts) >= 0 ? 1 : -1
        for tri in triangulate(pts) {
            let (a, b, c) = (pts[tri.0], pts[tri.1], pts[tri.2])
            m.triangle(Vec3(a.x, p.top, a.y), Vec3(b.x, p.top, b.y), Vec3(c.x, p.top, c.y), facing: Vec3(0, 1, 0))
            if bottomCap {
                m.triangle(Vec3(a.x, p.bottom, a.y), Vec3(b.x, p.bottom, b.y), Vec3(c.x, p.bottom, c.y), facing: Vec3(0, -1, 0))
            }
        }
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            let out = Vec3(sign * (b.y - a.y), 0, -sign * (b.x - a.x))
            m.quad(Vec3(a.x, p.bottom, a.y), Vec3(b.x, p.bottom, b.y), Vec3(b.x, p.top, b.y), Vec3(a.x, p.top, a.y), facing: out)
        }
        return m
    }

    /// A strip `width` wide along a line of points, facing up (and down too when `twoSided`).
    public static func strip(_ points: [Vec3], width: Double, twoSided: Bool = false) -> MeshData {
        var m = MeshData()
        guard points.count >= 2 else { return m }
        let w = width / 2
        func side(_ i: Int) -> (Double, Double) {
            let a = points[max(0, i - 1)], b = points[min(points.count - 1, i + 1)]
            let len = max(1e-9, hypot(b.x - a.x, b.z - a.z))
            return (-(b.z - a.z) / len * w, (b.x - a.x) / len * w)
        }
        for i in 0..<(points.count - 1) {
            let (p, q) = (points[i], points[i + 1])
            let (sp, sq) = (side(i), side(i + 1))
            let a = Vec3(p.x + sp.0, p.y, p.z + sp.1), b = Vec3(q.x + sq.0, q.y, q.z + sq.1)
            let c = Vec3(q.x - sq.0, q.y, q.z - sq.1), d = Vec3(p.x - sp.0, p.y, p.z - sp.1)
            m.quad(a, b, c, d, facing: Vec3(0, 1, 0))
            if twoSided { m.quad(a, b, c, d, facing: Vec3(0, -1, 0)) }
        }
        return m
    }

    // MARK: geometry helpers

    /// Drops a repeated closing point and consecutive duplicates.
    static func clean(_ pts: [Pt]) -> [Pt] {
        var out: [Pt] = []
        for p in pts where out.last.map({ hypot($0.x - p.x, $0.y - p.y) > 1e-6 }) ?? true { out.append(p) }
        if out.count > 1, let f = out.first, let l = out.last, hypot(f.x - l.x, f.y - l.y) < 1e-6 { out.removeLast() }
        return out
    }

    static func signedArea(_ pts: [Pt]) -> Double {
        guard pts.count >= 3 else { return 0 }
        var s = 0.0
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            s += a.x * b.y - b.x * a.y
        }
        return s / 2
    }

    /// Ear clipping; indices into `pts`. Falls back to a fan if the outline is self-crossing.
    static func triangulate(_ pts: [Pt]) -> [(Int, Int, Int)] {
        var idx = Array(pts.indices)
        if signedArea(pts) < 0 { idx.reverse() }
        func cross2(_ o: Pt, _ a: Pt, _ b: Pt) -> Double { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }
        func inside(_ p: Pt, _ a: Pt, _ b: Pt, _ c: Pt) -> Bool {
            cross2(a, b, p) >= 0 && cross2(b, c, p) >= 0 && cross2(c, a, p) >= 0
        }
        var out: [(Int, Int, Int)] = []
        var guardCount = 0
        while idx.count > 3 && guardCount < 10_000 {
            guardCount += 1
            var clipped = false
            for i in idx.indices {
                let (ia, ib, ic) = (idx[(i + idx.count - 1) % idx.count], idx[i], idx[(i + 1) % idx.count])
                let (a, b, c) = (pts[ia], pts[ib], pts[ic])
                guard cross2(a, b, c) > 1e-9 else { continue }
                let blocked = idx.contains { j in j != ia && j != ib && j != ic && inside(pts[j], a, b, c) }
                if blocked { continue }
                out.append((ia, ib, ic))
                idx.remove(at: i)
                clipped = true
                break
            }
            if !clipped { break }
        }
        if idx.count == 3 { out.append((idx[0], idx[1], idx[2])) } else if idx.count > 3 {
            for i in 1..<(idx.count - 1) { out.append((idx[0], idx[i], idx[i + 1])) }
        }
        return out
    }

    static func bounds(_ pts: [Pt], pad: Double) -> (minX: Double, minZ: Double, maxX: Double, maxZ: Double) {
        let xs = pts.map(\.x), ys = pts.map(\.y)
        return ((xs.min() ?? 0) - pad, (ys.min() ?? 0) - pad, (xs.max() ?? 0) + pad, (ys.max() ?? 0) + pad)
    }

    static func square(_ c: Pt, _ size: Double) -> [Pt] {
        let h = size / 2
        return [Pt(c.x - h, c.y - h), Pt(c.x + h, c.y - h), Pt(c.x + h, c.y + h), Pt(c.x - h, c.y + h)]
    }

    static func cumulative(_ pts: [Pt]) -> [Double] {
        var out = [0.0]
        for i in 1..<max(1, pts.count) { out.append(out[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
        return out
    }

    static func length(_ pts: [Pt]) -> Double { cumulative(pts).last ?? 0 }

    /// The line with a straight run of `by` metres added before its start and after its end.
    static func lengthen(_ pts: [Pt], by: Double) -> [Pt] {
        guard pts.count >= 2 else { return pts }
        func ext(_ from: Pt, _ to: Pt) -> Pt {
            let len = max(1e-9, hypot(to.x - from.x, to.y - from.y))
            return Pt(to.x + (to.x - from.x) / len * by, to.y + (to.y - from.y) / len * by)
        }
        return [ext(pts[1], pts[0])] + pts + [ext(pts[pts.count - 2], pts[pts.count - 1])]
    }

    /// Distance from a point to a polyline.
    static func distance(_ p: Pt, to line: [Pt]) -> Double {
        var best = Double.infinity
        for i in 1..<line.count {
            let c = closest(p, line[i - 1], line[i])
            best = min(best, hypot(p.x - c.x, p.y - c.y))
        }
        return best
    }

    /// Metres along a polyline to the point on it nearest `p`.
    static func project(_ p: Pt, on line: [Pt]) -> Double {
        let cum = cumulative(line)
        var best = (d: Double.infinity, along: 0.0)
        for i in 1..<line.count {
            let c = closest(p, line[i - 1], line[i])
            let d = hypot(p.x - c.x, p.y - c.y)
            if d < best.d { best = (d, cum[i - 1] + hypot(c.x - line[i - 1].x, c.y - line[i - 1].y)) }
        }
        return best.along
    }

    static func closest(_ p: Pt, _ a: Pt, _ b: Pt) -> Pt {
        let dx = b.x - a.x, dy = b.y - a.y
        let l2 = dx * dx + dy * dy
        let t = l2 > 0 ? max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / l2)) : 0
        return Pt(a.x + dx * t, a.y + dy * t)
    }

    static func sub(_ a: Vec3, _ b: Vec3) -> Vec3 { Vec3(a.x - b.x, a.y - b.y, a.z - b.z) }
    static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 { Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x) }
    static func dot(_ a: Vec3, _ b: Vec3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
    static func normalized(_ a: Vec3) -> Vec3 {
        let l = max(1e-12, sqrt(dot(a, a)))
        return Vec3(a.x / l, a.y / l, a.z / l)
    }
}
