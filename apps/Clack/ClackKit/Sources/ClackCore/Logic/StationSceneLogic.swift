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

        public init(x: Double, y: Double, level: String, label: String, kind: Kind) {
            self.x = x
            self.y = y
            self.level = level
            self.label = label
            self.kind = kind
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
            if mark == nil, let near = chips.firstIndex(where: { $0.mark == nil && hypot($0.sx - sx, $0.sy - sy) < 28 }) {
                chips[near].label = [chips[near].label, platform.ref].sorted { (Double($0) ?? 0) < (Double($1) ?? 0) }.joined(separator: "/")
            } else {
                chips.append(PlatformChip(id: platform.id, x: node.x, y: node.y, label: mark?.label ?? platform.ref, mark: mark, sx: sx, sy: sy))
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

    /// Pins that would overlap at this zoom: one per 26 px cell, toilets and open places first; names only when zoomed
    /// in, and only where one fits (one per 96 × 30 px cell, below its pin). The route's own pins and the marked
    /// platforms come first: an amenity under one of them is left out.
    public static func shownPois(map: StationMap, level: String, k: Double, state: (StationPoi) -> OpenState, dim: (StationPoi) -> Bool, pins: [PlacePin] = [], marks: [PlatformMark] = []) -> (shown: Set<String>, named: Set<String>) {
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
        var taken = Set<String>()
        var shown = Set<String>()
        for p in ordered(onLevel) {
            let r = rotate(p.x, p.y, degrees: rot)
            let cell = "\(Int((r.x * k / 26).rounded())),\(Int((r.y * k / 26).rounded()))"
            if taken.contains(cell) { continue }
            taken.insert(cell)
            shown.insert(p.id)
        }
        var named = Set<String>()
        if k > 3.2 {
            var slots = Set<String>()
            for p in ordered(onLevel.filter { shown.contains($0.id) && !$0.name.isEmpty }) {
                let r = rotate(p.x, p.y, degrees: rot)
                let cell = "\(Int((r.x * k / 96).rounded())),\(Int(((r.y * k + 24) / 30).rounded()))"
                if slots.contains(cell) { continue }
                slots.insert(cell)
                named.insert(p.id)
            }
        }
        return (shown, named)
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
}
