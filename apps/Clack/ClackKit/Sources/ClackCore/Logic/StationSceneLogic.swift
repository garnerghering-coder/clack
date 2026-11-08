//
//  StationSceneLogic.swift
//  Clack
//

import Foundation

/// The geometry of the station map's scene: fitting the view, which platform chips and amenity pins are drawn at a
/// zoom, and the filters. A port of the logic in `map/StationScene.tsx` and `pages/StationMapPage.tsx`.
public nonisolated enum StationSceneLogic {
    public struct View: Equatable, Sendable {
        public var tx = 0.0
        public var ty = 0.0
        public var k = 1.0

        public init(tx: Double = 0.0, ty: Double = 0.0, k: Double = 1.0) {
            self.tx = tx
            self.ty = ty
            self.k = k
        }
    }

    public struct Insets: Equatable, Sendable {
        public var top = 130.0
        public var bottom = 140.0
        /// The floor buttons down the right-hand side.
        public var right = 60.0

        public init(top: Double = 130.0, bottom: Double = 140.0, right: Double = 60.0) {
            self.top = top
            self.bottom = bottom
            self.right = right
        }
    }

    /// A platform's arrive / depart chip: its operator's colour and what it says.
    public struct PlatformMark: Equatable, Sendable {
        public var platformId: String
        public var label: String
        public var color: String

        public init(platformId: String, label: String, color: String) {
            self.platformId = platformId
            self.label = label
            self.color = color
        }
    }

    /// A walk's start or end that isn't a platform: an amenity, an entrance, or the walker ("me").
    public struct PlacePin: Equatable, Sendable {
        public enum Kind: Sendable { case from, to, me }
        public var x: Double
        public var y: Double
        public var level: String
        public var label: String
        public var kind: Kind
        /// For "me": how far off the position may be (metres, the fix's horizontal accuracy), drawn as a circle.
        public var accuracyM: Double?
        /// For "me": which way you face, degrees from true north, drawn as a cone; nil when not known well enough.
        public var headingDeg: Double?

        public init(x: Double, y: Double, level: String, label: String, kind: Kind, accuracyM: Double? = nil, headingDeg: Double? = nil) {
            self.x = x
            self.y = y
            self.level = level
            self.label = label
            self.kind = kind
            self.accuracyM = accuracyM
            self.headingDeg = headingDeg
        }
    }

    public struct PlatformChip: Equatable, Sendable, Identifiable {
        public var id: String
        public var x: Double
        public var y: Double
        public var label: String
        public var mark: PlatformMark?
        public var sx: Double
        public var sy: Double

        public init(id: String, x: Double, y: Double, label: String, mark: PlatformMark? = nil, sx: Double, sy: Double) {
            self.id = id
            self.x = x
            self.y = y
            self.label = label
            self.mark = mark
            self.sx = sx
            self.sy = sy
        }
    }

    /// "Along my path": amenities at most this many seconds' walk from the route.
    public static let alongSeconds = 40.0
    public static let minZoom = 0.3
    public static let maxZoom = 40.0

    /// The category filter chips, in order (StationMapPage.tsx FILTERS).
    public static let filters: [(key: String, categories: [PoiCategory])] = [
        ("toilets", [.toilet]), ("food", [.cafe, .restaurant, .kiosk]), ("shops", [.shop, .pharmacy]),
        ("tickets", [.ticket]), ("lockers", [.locker]), ("info", [.info, .waiting, .atm]),
    ]

    /// Lucide icon per kind of place: one pictogram per category (owner feedback 2026-10-21).
    public static func icon(_ category: PoiCategory) -> String {
        switch category {
        case .toilet: "toilet"
        case .cafe: "coffee"
        case .restaurant: "utensils-crossed"
        case .kiosk: "shopping-basket"
        case .shop: "shopping-bag"
        case .ticket: "ticket"
        case .locker: "luggage"
        case .waiting: "armchair"
        case .info: "info"
        case .pharmacy: "pill"
        case .atm: "banknote"
        case .taxi: "car-taxi-front"
        case .bus: "bus"
        case .other, .unknown: "map-pin"
        }
    }

    public static func rotate(_ x: Double, _ y: Double, degrees: Double) -> (x: Double, y: Double) {
        let r = degrees * .pi / 180
        return (x * cos(r) - y * sin(r), x * sin(r) + y * cos(r))
    }

    /// Diacritics-folded, lower-cased text for searching.
    public static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
    }

    public static func stateRank(_ state: OpenState) -> Int {
        switch state {
        case .open: 0
        case .closingSoon: 1
        case .unknown: 2
        case .closed: 3
        }
    }

    /// World points of one route step, for drawing: the edge's own geometry, flipped when the route walks it the
    /// other way.
    public static func stepPoints(_ step: RouteStep) -> [Pt] {
        let pts: [Pt]
        if let g = step.edge.geometry, g.count > 1 { pts = g } else { pts = [Pt(step.from.x, step.from.y), Pt(step.to.x, step.to.y)] }
        return step.edge.from == step.from.id ? pts : pts.reversed()
    }

    // MARK: fitting the view

    /// Fits the route, or else the chosen ends, or else the halls with their amenities (StationScene.tsx `:129-160`).
    public static func fit(map: StationMap, level: String, route: StationRoute?, marks: [PlatformMark], pins: [PlacePin], width: Double, height: Double, insets: Insets) -> View? {
        let rot = map.view?.rotation ?? 0
        let pois = map.pois.map { Pt($0.x, $0.y) }
        var ends = pins.filter { $0.level == level }.map { Pt($0.x, $0.y) }
        for mark in marks {
            if let platform = map.platforms.first(where: { $0.id == mark.platformId }), platform.level == level,
               let node = map.nodes.first(where: { $0.id == platform.node }) {
                ends.append(Pt(node.x, node.y))
            }
        }
        let hasRoute = !(route?.nodes.isEmpty ?? true)
        let pts: [Pt]
        if hasRoute, let route { pts = route.nodes.map { Pt($0.x, $0.y) } }
        else if !ends.isEmpty { pts = ends }
        else if !pois.isEmpty { pts = pois }
        else { pts = map.platforms.flatMap { $0.geometry.flatMap { $0 } } }
        guard !pts.isEmpty else { return nil }
        let r = pts.map { rotate($0.x, $0.y, degrees: rot) }
        let xs = r.map(\.x).sorted()
        let ys = r.map(\.y).sorted()
        // Without a route: the middle 70 % of the amenities plus 25 m (a few sit far out along the platforms).
        func q(_ values: [Double], _ f: Double) -> Double {
            values[min(values.count - 1, max(0, Int((f * Double(values.count - 1)).rounded())))]
        }
        let x0, x1, y0, y1: Double
        if hasRoute { (x0, x1, y0, y1) = (xs[0], xs[xs.count - 1], ys[0], ys[ys.count - 1]) }
        else if !ends.isEmpty { (x0, x1, y0, y1) = (xs[0] - 60, xs[xs.count - 1] + 60, ys[0] - 60, ys[ys.count - 1] + 60) }
        else { (x0, x1, y0, y1) = (q(xs, 0.15) - 25, q(xs, 0.85) + 25, q(ys, 0.15) - 25, q(ys, 0.85) + 25) }
        // Routes leave room at the sides for the arrive / depart chips; a short walk isn't zoomed in all the way.
        let (padX, padY): (Double, Double) = route != nil ? (marks.isEmpty ? 70 : 110, 40) : (16, 16)
        let w = width - insets.right - padX * 2
        let h = height - insets.top - insets.bottom - padY * 2
        let k = min(route != nil ? 9 : 40, max(0.5, w / max(x1 - x0, 20)), max(0.5, h / max(y1 - y0, 20)))
        return View(tx: padX + w / 2 - (x0 + x1) / 2 * k, ty: insets.top + padY + h / 2 - (y0 + y1) / 2 * k, k: k)
    }

    /// Zooms by a factor around a screen point, keeping that point still.
    public static func zoom(_ view: View, by factor: Double, aroundX cx: Double, y cy: Double) -> View {
        let k = min(maxZoom, max(minZoom, view.k * factor))
        let g = k / view.k
        return View(tx: cx - (cx - view.tx) * g, ty: cy - (cy - view.ty) * g, k: k)
    }

    // MARK: chips and pins at a zoom

    /// One chip per platform on this level: its number (island halves that would overlap share one chip), or the
    /// arrive / depart chip; marked chips win over plain ones under them.
    /// The route's own pins (from, to, me) come first: a plain chip under one is left out.
    public static func platformChips(map: StationMap, level: String, marks: [PlatformMark], k: Double, pins: [PlacePin] = []) -> [PlatformChip] {
        let rot = map.view?.rotation ?? 0
        let markFor = Dictionary(marks.map { ($0.platformId, $0) }, uniquingKeysWith: { first, _ in first })
        var chips: [PlatformChip] = []
        for platform in map.platforms where platform.level == level {
            guard let node = map.nodes.first(where: { $0.id == platform.node }) else { continue }
            let p = rotate(node.x, node.y, degrees: rot)
            let (sx, sy) = (p.x * k, p.y * k)
            let mark = markFor[platform.id]
            // Zoomed in far enough that its lettered sectors ("2a", "2b") sit apart: a chip on each instead.
            let sectors = mark == nil ? PlatformSectors.of(platform).sectors : []
            let sectorPoints = sectors.map { (rotate($0.label.x, $0.label.y, degrees: rot), $0) }
            if sectorPoints.count >= 2, zip(sectorPoints, sectorPoints.dropFirst()).allSatisfy({ hypot(($0.0.x - $1.0.x) * k, ($0.0.y - $1.0.y) * k) >= 70 }) {
                // From the sector's middle outwards along it, one every 160 px, so any stretch on screen is named.
                for (q, s) in sectorPoints {
                    chips.append(PlatformChip(id: "\(platform.id)#\(s.sector)", x: s.label.x, y: s.label.y, label: s.sector, sx: q.x * k, sy: q.y * k))
                    for (n, pt) in PlatformSectors.repeats(along: s.line, from: s.label, every: 160 / k).enumerated() {
                        let r = rotate(pt.x, pt.y, degrees: rot)
                        chips.append(PlatformChip(id: "\(platform.id)#\(s.sector)#\(n)", x: pt.x, y: pt.y, label: s.sector, sx: r.x * k, sy: r.y * k))
                    }
                }
                continue
            }
            if mark == nil, let near = chips.firstIndex(where: { $0.mark == nil && hypot($0.sx - sx, $0.sy - sy) < 28 }) {
                chips[near].label = [chips[near].label, platform.ref].sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }.joined(separator: "/")
            } else {
                chips.append(PlatformChip(id: platform.id, x: node.x, y: node.y, label: mark?.label ?? platform.ref, mark: mark, sx: sx, sy: sy))
            }
        }
        // A register's lettered stopping sectors (Entur's boarding positions at Oslo S), once zoomed in enough to read
        // them: a small chip at each sign; the same letter for the two tracks of an island shows once.
        if k >= 2.5 {
            for platform in map.platforms where platform.level == level {
                for mark in platform.sectors ?? [] {
                    let r = rotate(mark.point.x, mark.point.y, degrees: rot)
                    let (sx, sy) = (r.x * k, r.y * k)
                    if chips.contains(where: { hypot($0.sx - sx, $0.sy - sy) < 28 && ($0.label == mark.ref || $0.mark != nil) }) { continue }
                    chips.append(PlatformChip(id: "\(platform.id)@\(mark.track ?? "")\(mark.ref)", x: mark.point.x, y: mark.point.y, label: mark.ref, sx: sx, sy: sy))
                }
            }
        }
        let marked = chips.filter { $0.mark != nil }
        let plain = chips.filter { chip in
            chip.mark == nil && !marked.contains { m in
                abs(m.sx - chip.sx) < (Double(m.label.count) * 6.6 + 16) / 2 + 14 && abs(m.sy - chip.sy) < 24
            } && !covered(sx: chip.sx, sy: chip.sy, halfWidth: 11, by: pins, level: level, rot: rot, k: k)
        }
        return plain + marked
    }

    /// Whether something at a screen point (`halfWidth` wide on each side) lies under one of the route's own pins on
    /// this level: those pins say where you are, where you get on and where you go, so they are never covered.
    static func covered(sx: Double, sy: Double, halfWidth: Double, by pins: [PlacePin], level: String, rot: Double, k: Double) -> Bool {
        pins.contains { pin in
            guard pin.level == level else { return false }
            let p = rotate(pin.x, pin.y, degrees: rot)
            let pinHalf = min(190, Double(pin.label.count) * 6.4 + 18) / 2
            return abs(p.x * k - sx) < pinHalf + halfWidth && abs(p.y * k - sy) < 24
        }
    }

    /// Pins that would overlap at this zoom: one per 26 px cell, toilets and open places first, and `counts` says how
    /// many more sit under each shown pin (designer, 2026-11-07: pins stacked on top of each other with no sign of it;
    /// the pin now carries the number and a tap zooms in). Names only when zoomed in, and only where one fits (one per
    /// 96 × 30 px cell, below its pin). The route's own pins and the marked platforms come first: an amenity under one
    /// of them is left out.
    public static func shownPois(map: StationMap, level: String, k: Double, state: (StationPoi) -> OpenState, dim: (StationPoi) -> Bool, pins: [PlacePin] = [], marks: [PlatformMark] = []) -> (shown: Set<String>, named: Set<String>, counts: [String: Int]) {
        let rot = map.view?.rotation ?? 0
        let markedPlatforms = map.platforms.filter { p in p.level == level && marks.contains { $0.platformId == p.id } }
        let markPoints = markedPlatforms.compactMap { p in map.nodes.first { $0.id == p.node } }
        func underRoute(_ p: StationPoi) -> Bool {
            let r = rotate(p.x, p.y, degrees: rot)
            if covered(sx: r.x * k, sy: r.y * k, halfWidth: 11, by: pins, level: level, rot: rot, k: k) { return true }
            return markPoints.contains { node in
                let m = rotate(node.x, node.y, degrees: rot)
                return abs(m.x * k - r.x * k) < 40 && abs(m.y * k - r.y * k) < 24
            }
        }
        func rank(_ p: StationPoi) -> Int {
            (p.category == .toilet ? 0 : 1) * 10 + stateRank(state(p)) + (dim(p) ? 20 : 0)
        }
        func ordered(_ list: [StationPoi]) -> [StationPoi] {
            // A stable sort: ties keep the data's order, as the web's does.
            list.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
        }
        let onLevel = map.pois.filter { $0.level == level && !underRoute($0) }
        var taken = [String: String]()
        var shown = Set<String>()
        var counts = [String: Int]()
        for p in ordered(onLevel) {
            let r = rotate(p.x, p.y, degrees: rot)
            let cell = "\(Int((r.x * k / 26).rounded())),\(Int((r.y * k / 26).rounded()))"
            if let winner = taken[cell] {
                counts[winner, default: 0] += 1
                continue
            }
            taken[cell] = p.id
            shown.insert(p.id)
        }
        var named = Set<String>()
        if k > 3.2 {
            var slots = Set<String>()
            // Platform chips and the route's pins hold their place: a name (about 90 px wide, under its pin) never runs
            // under one of them.
            let chips = platformChips(map: map, level: level, marks: marks, k: k, pins: pins)
            func underChipOrPin(_ x: Double, _ y: Double) -> Bool {
                chips.contains { abs($0.sx - x) < (Double($0.label.count) * 6.6 + 16) / 2 + 45 && abs($0.sy - y) < 22 }
                    || covered(sx: x, sy: y, halfWidth: 45, by: pins, level: level, rot: rot, k: k)
            }
            for p in ordered(onLevel.filter { shown.contains($0.id) && !$0.name.isEmpty }) {
                let r = rotate(p.x, p.y, degrees: rot)
                let cell = "\(Int((r.x * k / 96).rounded())),\(Int(((r.y * k + 24) / 30).rounded()))"
                if slots.contains(cell) || underChipOrPin(r.x * k, r.y * k + 24) { continue }
                slots.insert(cell)
                named.insert(p.id)
            }
        }
        return (shown, named, counts)
    }

    // MARK: the page

    /// The level each step happens on: where the walk starts, then wherever the last stairs, escalator or lift went.
    public static func stepLevels(_ steps: [Instruction], routeStart: String?, fallback: String) -> [String] {
        var out: [String] = []
        for step in steps {
            if let level = step.level, step.key != .walk { out.append(level) } else { out.append(out.last ?? routeStart ?? fallback) }
        }
        return out
    }

    /// Unnamed entrances are told apart by where they are from the station's middle (true north up).
    public static func compass(of node: StationNode, from centre: (x: Double, y: Double)) -> String {
        let deg = atan2(node.x - centre.x, centre.y - node.y) * 180 / .pi
        let names = ["n", "ne", "e", "se", "s", "sw", "w", "nw"]
        let index = Int(((deg + 360).truncatingRemainder(dividingBy: 360) / 45).rounded()) % 8
        return names[index]
    }

    /// The middle of the platforms.
    public static func centre(of map: StationMap) -> (x: Double, y: Double) {
        let nodes = map.platforms.compactMap { p in map.nodes.first { $0.id == p.node } }
        guard !nodes.isEmpty else { return (0, 0) }
        return (nodes.reduce(0) { $0 + $1.x } / Double(nodes.count), nodes.reduce(0) { $0 + $1.y } / Double(nodes.count))
    }

    /// The level a map opens on: the walk's start, else the one showing, else the main level (order 0), else the first.
    public static func initialLevel(_ map: StationMap, startLevel: String?, current: String?) -> String? {
        if let startLevel { return startLevel }
        return current ?? map.levels.first(where: { $0.order == 0 })?.id ?? map.levels.first?.id
    }

    /// "+2", "0", "-1": a floor button's label.
    public static func levelLabel(_ level: StationLevel) -> String {
        level.order > 0 ? "+\(level.order)" : String(level.order)
    }
    /// The one sentence under a draft map's name saying what it doesn't have yet (an L10n key), most important gap
    /// first; nil for a hand-curated map, or one with no gap worth saying.
    public static func coverageNote(_ map: StationMap) -> String? {
        guard map.quality != .handCurated else { return nil }
        if map.platforms.contains(where: { $0.unconnected == true }) { return "stationMap.coverage.unconnected" }
        guard let c = map.coverage else { return nil }
        if map.levels.count > 1 && c.vertical < 1 { return "stationMap.coverage.noLevels" }
        if c.entrances < 1 { return "stationMap.coverage.exits" }
        if c.sides < 1 { return "stationMap.coverage.sides" }
        return nil
    }

    /// The me pin's accuracy circle, in screen points across: the fix's accuracy at this zoom, never smaller than the
    /// pin's own halo (32) and capped so a rough fix doesn't cover the whole plan.
    public static func accuracyDiameter(_ meters: Double?, k: Double, maxPoints: Double = 600) -> Double? {
        guard let meters, meters > 0, meters.isFinite else { return nil }
        return min(max(meters * 2 * k, 32), maxPoints)
    }

    /// A heading (degrees from true north) as an angle on screen, clockwise from straight up: the plan is drawn
    /// turned by its rotation, so north on screen is turned by as much.
    public static func screenHeading(_ heading: Double, mapRotation: Double) -> Double {
        let a = (heading + mapRotation).truncatingRemainder(dividingBy: 360)
        return a < 0 ? a + 360 : a
    }

    /// Walk mode's camera: heading-up and following you, about 15 m across, you a third up from the bottom.
    public struct Camera: Equatable, Sendable {
        public var x: Double
        public var y: Double
        /// Which way is up on screen, degrees from true north.
        public var heading: Double
        public var acrossM: Double
        /// How far down the screen you are (0 top, 1 bottom).
        public var anchor: Double

        public init(x: Double, y: Double, heading: Double, acrossM: Double = 15, anchor: Double = 2.0 / 3) {
            self.x = x
            self.y = y
            self.heading = heading
            self.acrossM = acrossM
            self.anchor = anchor
        }
    }

    /// The view and the plan's rotation for a camera on a screen this size: turning the plan by −heading puts the
    /// heading straight up (rotations are clockwise on screen, bearings clockwise from north).
    public static func view(for camera: Camera, width: Double, height: Double) -> (view: View, rotation: Double) {
        let rotation = -camera.heading
        let k = width / camera.acrossM
        let r = rotate(camera.x, camera.y, degrees: rotation)
        return (View(tx: width / 2 - r.x * k, ty: height * camera.anchor - r.y * k, k: k), rotation)
    }

    /// Whether a position is within `meters` of the station: of any platform's or shape's point, else the map's origin.
    public static func within(_ map: StationMap, lat: Double, lon: Double, meters: Double) -> Bool {
        let p = StationRouting.toLocal(map, lat: lat, lon: lon)
        let points = map.platforms.flatMap { $0.geometry.flatMap { $0 } } + map.shapes.filter { $0.kind == .building }.flatMap(\.points)
        if points.isEmpty { return hypot(p.x, p.y) <= meters }
        return points.contains { hypot($0.x - p.x, $0.y - p.y) <= meters }
    }

    /// When a map's OpenStreetMap hours were last read (re-read weekly by scripts/stations/hours_recheck.py, else the
    /// extract's date), as YYYY-MM-DD, when that is more than 30 days before `now`; nil while they are fresh.
    public static func hoursStale(_ map: StationMap, now: Date = .now) -> String? {
        guard let date = map.hoursChecked ?? map.sources.first(where: { $0.type == "osm" })?.retrieved else { return nil }
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Stockholm")
        f.dateFormat = "yyyy-MM-dd"
        guard let day = f.date(from: String(date.prefix(10))) else { return nil }
        return now.timeIntervalSince(day) > 30 * 86_400 ? String(date.prefix(10)) : nil
    }
}
