//
//  StationRouting.swift
//  Clack
//

import Foundation

/// Station maps (ADDITIONS_01 C1 to C3): validation, walking routes and the connection status; a port of
/// `packages/shared/src/station.ts`. Coordinates are metres in the map's local frame (x east, y south).
nonisolated struct WalkProfile: Hashable, Sendable {
    var pace: WalkPace = .normal
    var stepFree = false
    var luggage = false

    static let `default` = WalkProfile()

    /// The speed multiplier for a pace: relaxed is slower, brisk faster.
    var paceFactor: Double {
        switch pace {
        case .relaxed: 1.25
        case .brisk: 0.8
        case .normal, .unknown: 1
        }
    }
}

nonisolated struct RouteStep: Hashable, Sendable {
    let kind: EdgeKind
    let from: StationNode
    let to: StationNode
    let seconds: Double
    let edge: StationEdge
}

nonisolated struct StationRoute: Hashable, Sendable {
    let nodes: [StationNode]
    let steps: [RouteStep]
    let seconds: Int
    let meters: Int
    let levels: [String]
}

/// Where a walk starts or ends. As a URL value: a track ("11", "17b"), an amenity ("p:<poi id>"), any node such as an
/// entrance ("n:<node id>"), or the walker's own position snapped to the map ("me:<node id>").
nonisolated struct Endpoint: Hashable, Sendable {
    enum Kind: Sendable { case track, poi, node, me }

    let spec: String
    let kind: Kind
    let node: StationNode
    var track: String?
    var platform: StationPlatform?
    var poi: StationPoi?
}

/// A place a set of directions starts or ends at: a track by name, or a resolved endpoint.
nonisolated enum Place: Sendable {
    case track(String)
    case endpoint(Endpoint)
}

/// One line of directions, from a template key plus values (never generated text; the caller words it with L10n).
nonisolated struct Instruction: Hashable, Sendable {
    enum Key: String, Sendable {
        case leave, start, walk
        case stairsUp = "stairs_up", stairsDown = "stairs_down"
        case escalatorUp = "escalator_up", escalatorDown = "escalator_down"
        case liftUp = "lift_up", liftDown = "lift_down"
        case arrive, reach
    }

    var key: Key
    var level: String?
    var seconds: Int
    var track: String?
    /// For start and reach: the endpoint (the caller turns it into a name).
    var endpoint: Endpoint?
}

nonisolated enum SizeClass: String, Codable, Sendable {
    case small, medium, large
}

/// easy: mapped walk, live times, at least 5 min spare. tight: under 5 min spare. miss: no time left. margin: enough
/// time on paper, but the walk is an estimate or the times aren't live yet, so it's stated as a margin, not a promise
/// (product brief §7). broken: a train is cancelled. unknown: not enough to say.
nonisolated enum ConnectionStatus: String, Sendable {
    case easy, tight, miss, unknown, broken, margin
}

nonisolated struct ConnectionInput: Sendable {
    /// Expected arrival of the first train and departure of the second (best estimate, ms).
    var arrival: Double?
    var departure: Double?
    var arrivalPlatform: String?
    var departurePlatform: String?
    var canceledA = false
    var canceledB = false
    /// Walking seconds from the station map, or nil when there isn't one or no path.
    var walkSeconds: Double?
    /// Fallback when `walkSeconds` is nil.
    var sizeClass: SizeClass?
    /// Both times come from real-time data (actuals or Trafikverket's estimates), not just the timetable.
    var timesLive = true
}

nonisolated struct ConnectionResult: Equatable, Sendable {
    var status: ConnectionStatus
    var layoverSeconds: Int?
    var walkSeconds: Double?
    var slackSeconds: Double?
    /// The walk is an estimate from the station's size, not a route on a map.
    var estimated: Bool
}

nonisolated enum StationRouting {
    // MARK: Validation (the build of a map fails on any of these)

    private static func adjacency(_ map: StationMap) -> [String: [(to: String, edge: StationEdge)]] {
        var adj: [String: [(to: String, edge: StationEdge)]] = [:]
        for edge in map.edges {
            adj[edge.from, default: []].append((edge.to, edge))
            adj[edge.to, default: []].append((edge.from, edge))
        }
        return adj
    }

    static func validate(_ map: StationMap) -> [String] {
        var errors: [String] = []
        let levels = Set(map.levels.map(\.id))
        var nodes: [String: StationNode] = [:]
        for node in map.nodes { nodes[node.id] = node }
        if nodes.count != map.nodes.count { errors.append("duplicate node ids") }
        for node in map.nodes where !levels.contains(node.level) { errors.append("node \(node.id): unknown level \(node.level)") }
        for edge in map.edges {
            if nodes[edge.from] == nil || nodes[edge.to] == nil { errors.append("edge \(edge.from)→\(edge.to): unknown node") }
            if !(edge.seconds > 0 && edge.seconds.isFinite) { errors.append("edge \(edge.from)→\(edge.to): no seconds") }
        }
        let adj = adjacency(map)
        // Everything must be reachable from the first platform (one connected walking graph).
        var seen = Set<String>()
        if let start = map.platforms.first?.node {
            var stack = [start]
            while let n = stack.popLast() {
                if seen.contains(n) { continue }
                seen.insert(n)
                for (to, _) in adj[n] ?? [] { stack.append(to) }
            }
        }
        for platform in map.platforms {
            if !levels.contains(platform.level) { errors.append("platform \(platform.ref): unknown level \(platform.level)") }
            if nodes[platform.node] == nil {
                errors.append("platform \(platform.ref): unknown node \(platform.node)")
            } else if !seen.contains(platform.node) {
                errors.append("platform \(platform.ref): unreachable")
            }
            if platform.tracks.isEmpty { errors.append("platform \(platform.ref): no tracks") }
        }
        for poi in map.pois {
            if nodes[poi.node] == nil {
                errors.append("poi \(poi.id): unknown node \(poi.node)")
            } else if !seen.contains(poi.node) {
                errors.append("poi \(poi.id): unreachable")
            }
            if !levels.contains(poi.level) { errors.append("poi \(poi.id): unknown level \(poi.level)") }
        }
        return errors
    }

    // MARK: Walking profile and routes (C3)

    /// Seconds for one edge for this person; nil = not allowed (stairs when step-free only).
    static func edgeSeconds(_ edge: StationEdge, _ profile: WalkProfile) -> Double? {
        if profile.stepFree && !edge.stepFree { return nil }
        var s = edge.seconds
        switch edge.kind {
        case .walk: s *= profile.paceFactor
        case .stairs: s = s * profile.paceFactor * (profile.luggage ? 1.8 : 1) + (profile.luggage ? 15 : 0)
        case .escalator: s = s * (profile.luggage ? 1.2 : 1) + (profile.luggage ? 5 : 0)
        case .lift, .unknown: break
        }
        return s
    }

    /// Shortest walk between two nodes (Dijkstra; station graphs are a few hundred nodes).
    static func route(_ map: StationMap, from: String, to: String, profile: WalkProfile = .default) -> StationRoute? {
        let adj = adjacency(map)
        var byId: [String: StationNode] = [:]
        for node in map.nodes { byId[node.id] = node }
        guard byId[from] != nil, byId[to] != nil else { return nil }
        var dist: [String: Double] = [from: 0]
        var prev: [String: (node: String, edge: StationEdge)] = [:]
        var done = Set<String>()
        // A plain array as the queue: fine at this size.
        var queue: [(Double, String)] = [(0, from)]
        while !queue.isEmpty {
            var best = 0
            for i in 1..<max(queue.count, 1) where queue[i].0 < queue[best].0 { best = i }
            let (d, n) = queue.remove(at: best)
            if done.contains(n) { continue }
            done.insert(n)
            if n == to { break }
            for (next, edge) in adj[n] ?? [] {
                guard let s = edgeSeconds(edge, profile), !done.contains(next) else { continue }
                let nd = d + s
                if nd < (dist[next] ?? .infinity) {
                    dist[next] = nd
                    prev[next] = (n, edge)
                    queue.append((nd, next))
                }
            }
        }
        guard done.contains(to), let total = dist[to] else { return nil }
        var path = [to]
        var edges: [StationEdge] = []
        while path[0] != from {
            guard let step = prev[path[0]] else { return nil }
            path.insert(step.node, at: 0)
            edges.insert(step.edge, at: 0)
        }
        let nodes = path.compactMap { byId[$0] }
        var steps: [RouteStep] = []
        for (i, edge) in edges.enumerated() {
            steps.append(RouteStep(kind: edge.kind, from: nodes[i], to: nodes[i + 1], seconds: edgeSeconds(edge, profile) ?? 0, edge: edge))
        }
        var levels: [String] = []
        for node in nodes where levels.last != node.level { levels.append(node.level) }
        let meters = edges.reduce(0.0) { sum, edge in
            if let m = edge.meters { return sum + m }
            guard let a = byId[edge.from], let b = byId[edge.to] else { return sum }
            return sum + hypot(a.x - b.x, a.y - b.y)
        }
        return StationRoute(nodes: nodes, steps: steps, seconds: Int(total.rounded()), meters: Int(meters.rounded()), levels: levels)
    }

    /// Walking seconds from the nearest of `sources` to every node (for "along my path": detours to amenities).
    static func secondsFrom(_ map: StationMap, sources: [String], profile: WalkProfile = .default) -> [String: Double] {
        let adj = adjacency(map)
        var dist: [String: Double] = [:]
        for s in sources { dist[s] = 0 }
        var done = Set<String>()
        var queue: [(Double, String)] = sources.map { (0, $0) }
        while !queue.isEmpty {
            var best = 0
            for i in 1..<max(queue.count, 1) where queue[i].0 < queue[best].0 { best = i }
            let (d, n) = queue.remove(at: best)
            if done.contains(n) { continue }
            done.insert(n)
            for (next, edge) in adj[n] ?? [] {
                guard let s = edgeSeconds(edge, profile), !done.contains(next) else { continue }
                if d + s < (dist[next] ?? .infinity) {
                    dist[next] = d + s
                    queue.append((d + s, next))
                }
            }
        }
        return dist
    }

    /// The platform serving a Trafikverket track ("17b" gives the platform with track 17).
    static func platform(forTrack track: String?, in map: StationMap) -> StationPlatform? {
        guard let track, !track.isEmpty else { return nil }
        var base = track.lowercased()
        while let last = base.last, last.isLetter, last.isASCII { base.removeLast() }
        return map.platforms.first { $0.tracks.contains(base) }
    }

    static func routeTracks(
        _ map: StationMap, from fromTrack: String?, to toTrack: String?, profile: WalkProfile = .default
    ) -> StationRoute? {
        func endpoint(_ t: String?) -> Endpoint? {
            guard let t, !t.contains(":") else { return nil }
            return resolveEndpoint(map, t)
        }
        return routeBetween(map, endpoint(fromTrack), endpoint(toTrack), profile: profile)
    }

    // MARK: Endpoints

    static func resolveEndpoint(_ map: StationMap, _ spec: String?) -> Endpoint? {
        guard let spec, !spec.isEmpty else { return nil }
        func node(_ id: String) -> StationNode? { map.nodes.first { $0.id == id } }
        let kind: String
        let id: String
        if let colon = spec.firstIndex(of: ":") {
            kind = String(spec[..<colon])
            id = String(spec[spec.index(after: colon)...])
        } else {
            kind = "track"
            id = spec
        }
        switch kind {
        case "track":
            guard let platform = platform(forTrack: id, in: map), let n = node(platform.node) else { return nil }
            return Endpoint(spec: spec, kind: .track, node: n, track: id, platform: platform)
        case "p":
            guard let poi = map.pois.first(where: { $0.id == id }), let n = node(poi.node) else { return nil }
            return Endpoint(spec: spec, kind: .poi, node: n, poi: poi)
        case "n", "me":
            guard let n = node(id) else { return nil }
            return Endpoint(spec: spec, kind: kind == "n" ? .node : .me, node: n)
        default:
            return nil
        }
    }

    static func routeBetween(_ map: StationMap, _ a: Endpoint?, _ b: Endpoint?, profile: WalkProfile = .default) -> StationRoute? {
        guard let a, let b else { return nil }
        // The same platform (or the same spot): no walk to speak of.
        if (a.platform != nil && a.platform?.id == b.platform?.id) || a.node.id == b.node.id {
            return StationRoute(nodes: [a.node], steps: [], seconds: a.platform != nil ? 30 : 0, meters: 0, levels: [a.node.level])
        }
        return route(map, from: a.node.id, to: b.node.id, profile: profile)
    }

    /// WGS84 to the map's local metres (x east, y south); an equirectangular step is plenty inside one station.
    static func toLocal(_ map: StationMap, lat: Double, lon: Double) -> Pt {
        let kx = 111_320 * cos(map.origin.lat * Double.pi / 180)
        return Pt((lon - map.origin.lon) * kx, -(lat - map.origin.lat) * 110_574)
    }

    /// The walking-graph node closest to a point on a level, if one is within `maxMeters`.
    static func nearestNode(_ map: StationMap, level: String, x: Double, y: Double, maxMeters: Double = .infinity) -> StationNode? {
        var reachable = Set<String>()
        for edge in map.edges {
            reachable.insert(edge.from)
            reachable.insert(edge.to)
        }
        var best: StationNode?
        var bestDistance = maxMeters
        for node in map.nodes where node.level == level && reachable.contains(node.id) {
            let d = hypot(node.x - x, node.y - y)
            if d <= bestDistance {
                best = node
                bestDistance = d
            }
        }
        return best
    }

    /// Directions from templates, merging consecutive walking. A track end reads "Leave track 11"; others "Start at ...".
    static func instructions(_ map: StationMap, _ route: StationRoute, from: Place? = nil, to: Place? = nil) -> [Instruction] {
        var order: [String: Int] = [:]
        for level in map.levels { order[level.id] = level.order }
        func end(_ place: Place?, track: Instruction.Key, other: Instruction.Key) -> Instruction {
            switch place {
            case nil: return Instruction(key: track, seconds: 0)
            case .track(let name): return Instruction(key: track, seconds: 0, track: name)
            case .endpoint(let endpoint):
                if endpoint.kind == .track { return Instruction(key: track, seconds: 0, track: endpoint.track) }
                return Instruction(key: other, seconds: 0, endpoint: endpoint)
            }
        }
        var out = [end(from, track: .leave, other: .start)]
        // Seconds are summed unrounded and rounded once at the end, as on the web.
        var seconds: [Double] = [0]
        for step in route.steps {
            let up = (order[step.to.level] ?? 0) > (order[step.from.level] ?? 0)
            let key: Instruction.Key
            switch step.kind {
            case .walk, .unknown: key = .walk
            case .stairs: key = up ? .stairsUp : .stairsDown
            case .escalator: key = up ? .escalatorUp : .escalatorDown
            case .lift: key = up ? .liftUp : .liftDown
            }
            if out[out.count - 1].key == key {
                seconds[seconds.count - 1] += step.seconds
            } else {
                out.append(Instruction(key: key, level: key == .walk ? nil : step.to.level, seconds: 0))
                seconds.append(step.seconds)
            }
        }
        out.append(end(to, track: .arrive, other: .reach))
        seconds.append(0)
        for i in out.indices { out[i].seconds = Int(seconds[i].rounded()) }
        return out
    }

    // MARK: Connections (Layover Guide, C3)

    /// Walk estimate when there's no station map (or the two platforms aren't connected in it).
    static func sizeWalkSeconds(_ size: SizeClass) -> Double {
        switch size {
        case .small: 120
        case .medium: 240
        case .large: 420
        }
    }

    /// Station size from the number of distinct base tracks (Trafikverket PlatformLine): up to 4 small, up to 10 medium.
    static func sizeClass(baseTracks: Int) -> SizeClass {
        baseTracks <= 4 ? .small : baseTracks <= 10 ? .medium : .large
    }

    static let deboardSeconds: Double = 60
    static let boardSeconds: Double = 30

    /// Pure, so a platform change or delay can recompute it instantly: slack = layover - walk - deboard - board
    /// buffers. Green (easy) at 5 min or more only with a mapped walk and live times; yellow 0 to 5; red under 0. With an
    /// estimated walk or timetable-only times it's a neutral "margin" with the minutes.
    static func connectionStatus(_ c: ConnectionInput) -> ConnectionResult {
        var layover: Int?
        if let arrival = c.arrival, let departure = c.departure { layover = Int(((departure - arrival) / 1000).rounded()) }
        let estimated = c.walkSeconds == nil
        let walk = c.walkSeconds ?? c.sizeClass.map(sizeWalkSeconds)
        if c.canceledA || c.canceledB {
            return ConnectionResult(status: .broken, layoverSeconds: layover, walkSeconds: walk, slackSeconds: nil, estimated: estimated)
        }
        let platformsMissing = (c.arrivalPlatform ?? "").isEmpty || (c.departurePlatform ?? "").isEmpty
        guard let layover, let walk, !(!estimated && platformsMissing) else {
            return ConnectionResult(status: .unknown, layoverSeconds: layover, walkSeconds: walk, slackSeconds: nil, estimated: estimated)
        }
        let slack = Double(layover) - walk - deboardSeconds - boardSeconds
        let status: ConnectionStatus
        if slack < 0 {
            status = .miss
        } else if slack < 5 * 60 {
            status = .tight
        } else if estimated || !c.timesLive {
            status = .margin
        } else {
            status = .easy
        }
        return ConnectionResult(status: status, layoverSeconds: layover, walkSeconds: walk, slackSeconds: slack, estimated: estimated)
    }
}
