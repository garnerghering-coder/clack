//
//  StationScene3DView.swift
//  Clack
//

import ClackCore
import ClackDesign
import RealityKit
import SwiftUI
import UIKit

/// The 3D station view (one-station demo, Jönköping C; DESIGN §2.7): the levels, platforms, stairs, escalators and
/// lifts from the station map, with the trains standing at their platforms from the board. Opened full screen from the
/// station map. The geometry and the train schedule are `StationScene3D` (ClackCore, tested); this file only turns
/// them into RealityKit entities and moves the cars.
@available(iOS 18.0, *)
struct StationScene3DView: View {
    let map: StationMap

    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var stage = Station3DStage()
    @State private var orbit: OrbitCamera?
    @State private var dragStart: OrbitCamera?
    @State private var zoomStart: OrbitCamera?
    @State private var arrivals: [String: BoardRow] = [:]
    @State private var departures: [String: BoardRow] = [:]
    @State private var boardVersion = 0
    @State private var boardFailed = false
    @State private var trains: [StationScene3D.Scene3DTrain] = []

    private var scene: StationScene3D.Scene { stage.scene ?? StationScene3D.build(map) }
    private var dark: Bool { colorScheme == .dark }
    private var tz: String { "Europe/Stockholm" }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RealityView { content in
                content.camera = .virtual
                // Nothing here needs RealityKit's camera effects; off, they cost no GPU time.
                content.renderingEffects.motionBlur = .disabled
                content.renderingEffects.depthOfField = .disabled
                content.renderingEffects.cameraGrain = .disabled
                content.renderingEffects.dynamicRange = .standard
                content.add(stage.root)
            }
            .background(Ink.mapBg)
            .gesture(orbitGesture.simultaneously(with: zoomGesture))
            .gesture(TwoFingerPan { delta, ended in pan(delta, ended: ended) })
            .ignoresSafeArea()
            .accessibilityLabel(map.name)

            MapButton(icon: "x", label: l10n.t("station3d.close")) { dismiss() }
                .padding(.trailing, 12).padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { panel }
        // Built again in the other theme; the cars are placed afresh after.
        .task(id: colorScheme) {
            stage.build(map: map, dark: dark)
            if orbit == nil {
                orbit = OrbitCamera.start(for: stage.scene ?? scene, rotation: map.view?.rotation ?? 0)
                #if DEBUG
                // `-camera3D <bearing>,<pitch>,<distance>[,<x>,<z>]` starts from another angle (screenshots).
                let args = CommandLine.arguments
                if let i = args.firstIndex(of: "-camera3D"), args.indices.contains(i + 1) {
                    let v = args[i + 1].split(separator: ",").compactMap { Double($0) }
                    if v.count >= 3 { orbit?.bearing = v[0]; orbit?.pitch = v[1]; orbit?.distance = v[2] }
                    if v.count == 5 { orbit?.target = SIMD3(Float(v[3]), 0, Float(v[4])) }
                }
                #endif
            }
            if let orbit { stage.setCamera(orbit) }
            place(Date().timeIntervalSince1970 * 1000)
        }
        .task { await loadBoard() }
        .task { await follow(arrivals: true) }
        .task { await follow(arrivals: false) }
        // The clock: every frame only while a train slides in or out, else asleep until the next change.
        .task(id: boardVersion) {
            while !Task.isCancelled {
                let now = Date().timeIntervalSince1970 * 1000
                place(now)
                if trains.contains(where: \.moving) {
                    try? await Task.sleep(for: .milliseconds(33))
                } else {
                    let next = StationScene3D.nextChange(trains, now: now) ?? now + 60_000
                    try? await Task.sleep(for: .milliseconds(Int(max(50, min(next - now, 60_000)))))
                }
            }
        }
        .countsScreen("station3d")
    }

    // MARK: data

    private func place(_ now: Double) {
        trains = StationScene3D.trainStates(arrivals: Array(arrivals.values), departures: Array(departures.values), now: now, map: map)
        stage.placeTrains(trains, map: map, dark: dark, type: { id in app.trainTypes.first { $0.id == id } }, brand: { id in app.operatorsById[id]?.brandColor })
    }

    private func loadBoard() async {
        #if DEBUG
        if CommandLine.arguments.contains("-fakeBoard3D") {
            let fake = Self.fakeBoard(now: Date().timeIntervalSince1970 * 1000)
            arrivals = Dictionary(fake.arrivals.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            departures = Dictionary(fake.departures.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            boardVersion += 1
            return
        }
        #endif
        // From an hour back, so a train that arrived a while ago and is still standing is known.
        let now = Date().timeIntervalSince1970 * 1000
        async let a = try? app.client.board(map.stationId, arrivals: true, from: now - 3_600_000, to: now + StationScene3D.windowMs)
        async let d = try? app.client.board(map.stationId, arrivals: false, from: now - 600_000, to: now + StationScene3D.windowMs)
        let (arr, dep) = await (a, d)
        if arr == nil && dep == nil { boardFailed = true }
        merge(arr?.rows ?? [], arrivals: true)
        merge(dep?.rows ?? [], arrivals: false)
    }

    /// Follows the live board while the view is open; the stream's rows replace the loaded ones with the same id.
    private func follow(arrivals: Bool) async {
        #if DEBUG
        if CommandLine.arguments.contains("-fakeBoard3D") { return }
        #endif
        while !Task.isCancelled {
            do {
                for try await event in app.client.boardStream(map.stationId, arrivals: arrivals) where event.name == "board" {
                    if let board = await EventStream.decode(Board.self, from: event) {
                        merge(board.rows, arrivals: arrivals)
                        boardFailed = false
                    }
                }
            } catch {}
            try? await Task.sleep(for: .seconds(5))
        }
    }

    private func merge(_ rows: [BoardRow], arrivals isArrivals: Bool) {
        let cutoff = Date().timeIntervalSince1970 * 1000 - 2 * 3_600_000
        var into = isArrivals ? arrivals : departures
        for r in rows { into[r.id] = r }
        into = into.filter { $0.value.shown > cutoff }
        if isArrivals { arrivals = into } else { departures = into }
        boardVersion += 1
    }

    #if DEBUG
    /// `-fakeBoard3D`: one train standing at platform 2a (arrived 2 min ago, leaves in 5) and one arriving at platform 1
    /// in 40 s. Made up, to look at the view; never in a release build.
    static func fakeBoard(now: Double) -> (arrivals: [BoardRow], departures: [BoardRow]) {
        func row(_ n: String, _ at: Double, _ platform: String, _ type: String, _ places: [String]) -> BoardRow {
            BoardRow(id: "fake-\(n)-\(places[0])", trainNumber: n, advertised: at, estimated: nil, actual: nil, done: false, delayMin: nil, platform: platform, platformChange: nil, canceled: false, deviations: [], endpoints: places, via: [], operatorId: "sj", productName: nil, product: "regional", trainType: type, trip: .init(key: "fake-\(n)", serviceDate: "", seq: 0))
        }
        return (
            [row("1234", now - 120_000, "2a", "x40", ["Nässjö C"]), row("1301", now + 40_000, "1", "x61", ["Vaggeryd"])],
            [row("1234", now + 300_000, "2a", "x40", ["Göteborg C"]), row("1301", now + 280_000, "1", "x61", ["Nässjö C"])]
        )
    }
    #endif

    // MARK: camera gestures

    /// One finger: sideways turns round the middle, up and down tilts.
    private var orbitGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                guard let base = dragStart ?? orbit else { return }
                if dragStart == nil { dragStart = base }
                var o = base
                o.bearing = base.bearing - v.translation.width * 0.3
                o.pitch = min(85, max(12, base.pitch + v.translation.height * 0.2))
                setOrbit(o)
            }
            .onEnded { _ in dragStart = nil }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { v in
                guard let base = zoomStart ?? orbit else { return }
                if zoomStart == nil { zoomStart = base }
                var o = orbit ?? base
                o.distance = min(1_500, max(25, base.distance / v.magnification))
                setOrbit(o)
            }
            .onEnded { _ in zoomStart = nil }
    }

    /// Two fingers: moves the point the camera turns round, along the ground as seen from the camera.
    private func pan(_ delta: CGPoint, ended: Bool) {
        guard var o = orbit else { return }
        dragStart = nil
        let k = o.distance / 600
        let b = o.bearing * .pi / 180
        // Screen right is the camera's right on the ground, screen up is away from the camera.
        let right = SIMD2(-cos(b), -sin(b)), away = SIMD2(-sin(b), cos(b))
        o.target.x -= Float((right.x * delta.x - away.x * delta.y) * k)
        o.target.z -= Float((right.y * delta.x - away.y * delta.y) * k)
        setOrbit(o)
    }

    private func setOrbit(_ o: OrbitCamera) {
        orbit = o
        stage.setCamera(o)
    }

    // MARK: panel

    private var panel: some View {
        let notes = scene.notes
        let shown = trains.filter { $0.state != .upcoming }
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(map.name).clack(.headline).foregroundStyle(Ink.text)
                    if notes.draft { note(l10n.t("station3d.note.draft")) }
                    if notes.standardPlatformHeight { note(l10n.t("station3d.note.platformHeight")) }
                    if notes.buildingHeightUnknown { note(l10n.t("station3d.note.buildingHeight")) }
                    if notes.rampSlopeStandard { note(l10n.t("station3d.note.rampSlope")) }
                    if notes.roofUndersideUnknown { note(l10n.t("station3d.note.roofUnderside")) }
                    if notes.bridgeUndersideMinimum { note(l10n.t("station3d.note.bridgeMinimum")) }
                    if notes.flatGround { note(l10n.t("station3d.note.flatGround")) }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("station3d.trains")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    if boardFailed {
                        Text(l10n.t("station3d.boardError")).clack(.caption).foregroundStyle(Ink.text2)
                    } else if trains.isEmpty {
                        Text(l10n.t("station3d.noTrains")).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    ForEach(shown.filter { $0.platformId != nil } + trains.filter { $0.state == .upcoming && $0.platformId != nil }) { trainRow($0) }
                }
                let unknown = trains.filter { $0.platformId == nil }
                if !unknown.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(l10n.t("station3d.platformUnknown")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                        ForEach(unknown) { trainRow($0) }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("station3d.credits")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    Text(l10n.t("station3d.credit.osm")).clack(.micro).foregroundStyle(Ink.text3)
                    if let laser = notes.laserCredit { Text(l10n.t("station3d.credit.\(laser)")).clack(.micro).foregroundStyle(Ink.text3) }
                    if let register = notes.registerCredit { Text(l10n.t("station3d.credit.\(register)")).clack(.micro).foregroundStyle(Ink.text3) }
                }
                Text(l10n.t("station3d.hint")).clack(.micro).foregroundStyle(Ink.text3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxHeight: 260)
        .fixedSize(horizontal: false, vertical: true)
        .background(Ink.surface, in: UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet, style: .continuous))
    }

    private func note(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            LucideIcon(name: "info", size: 12).foregroundStyle(Ink.text3)
            Text(text).clack(.caption).foregroundStyle(Ink.text2)
        }
    }

    private func trainRow(_ t: StationScene3D.Scene3DTrain) -> some View {
        let op = t.operatorId.flatMap { app.operatorsById[$0] }
        let name = [op?.shortName, t.trainNumber].compactMap { $0 }.joined(separator: " ")
        let place = t.destination.map { l10n.t("station3d.to", ["place": $0]) } ?? t.origin.map { l10n.t("station3d.from", ["place": $0]) } ?? ""
        let platform = t.platform.map { l10n.t("station3d.platform", ["p": $0]) } ?? l10n.t("station3d.platformUnknown")
        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                OperatorBadge(op: op, size: .small)
                Text(name).clack(.trainNumber).foregroundStyle(Ink.text)
                Text(place).clack(.body).foregroundStyle(Ink.text).lineLimit(1)
            }
            Text("\(platform) · \(status(t))").clack(.caption).foregroundStyle(t.state == .upcoming ? Ink.text3 : Ink.text2)
        }
        .accessibilityElement(children: .combine)
    }

    private func status(_ t: StationScene3D.Scene3DTrain) -> String {
        let clock = app.settings.clock
        switch t.state {
        case .arriving: return l10n.t("station3d.arriving")
        case .leaving: return l10n.t("station3d.leaving")
        case .standing:
            if let d = t.departure { return l10n.t("station3d.standing", ["time": Format.time(d, tz: tz, clock: clock)]) }
            return l10n.t("station3d.standingEnds", ["time": Format.time(t.arrival, tz: tz, clock: clock)])
        case .upcoming:
            if let a = t.arrival { return l10n.t("station3d.arrives", ["time": Format.time(a, tz: tz, clock: clock)]) }
            return l10n.t("station3d.departs", ["time": Format.time(t.departure, tz: tz, clock: clock)])
        }
    }
}

// MARK: camera

/// The camera: it looks at `target` from `distance` metres away, `pitch` degrees above the ground, standing at compass
/// `bearing` (0 north, clockwise) from the target.
struct OrbitCamera: Equatable {
    var target: SIMD3<Float>
    var bearing: Double
    var pitch: Double
    var distance: Double

    var position: SIMD3<Float> {
        let b = bearing * .pi / 180, p = pitch * .pi / 180
        // North is -z, east is +x.
        let offset = SIMD3(cos(p) * sin(b), sin(p), -cos(p) * cos(b)) * distance
        return target + SIMD3<Float>(Float(offset.x), Float(offset.y), Float(offset.z))
    }

    /// The start: framing the platforms at 45°, seen from the bottom of the 2D map's screen and a little to its right
    /// (15°), so the platforms run up the screen as they do on the station map (`view.rotation`). Portrait leaves a
    /// narrow field sideways, so the long platforms are kept close to the view's axis.
    static func start(for scene: StationScene3D.Scene, rotation: Double) -> OrbitCamera {
        let f = scene.focus
        let extent = max(f.maxX - f.minX, f.maxZ - f.minZ, 60)
        return OrbitCamera(
            target: SIMD3(Float((f.minX + f.maxX) / 2), 0, Float((f.minZ + f.maxZ) / 2)),
            bearing: 180 - rotation + 15, pitch: 45, distance: extent * 1.05
        )
    }
}

/// A two-finger pan (SwiftUI has none), reported as the change since the last call.
@available(iOS 18.0, *)
private struct TwoFingerPan: UIGestureRecognizerRepresentable {
    let changed: (CGPoint, Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let g = UIPanGestureRecognizer()
        g.minimumNumberOfTouches = 2
        g.maximumNumberOfTouches = 2
        g.delegate = context.coordinator
        return g
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let t = recognizer.translation(in: recognizer.view)
        recognizer.setTranslation(.zero, in: recognizer.view)
        changed(t, recognizer.state == .ended || recognizer.state == .cancelled)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        // Pinch and pan together.
        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
    }
}

// MARK: RealityKit

/// The entities: the station built once per theme, the cars placed per update.
@available(iOS 18.0, *)
@MainActor
final class Station3DStage {
    let root = Entity()
    private let camera = Entity()
    private let fixed = Entity()
    private let trainsRoot = Entity()
    private(set) var scene: StationScene3D.Scene?
    private var tracks: [String: (track: [Pt], middle: Double)] = [:]
    private var cars: [String: [ModelEntity]] = [:]
    private var carMeshes: [String: MeshResource] = [:]
    private var carsDark: Bool?

    init() {
        // Car bodies are 3–4.6 m in a scene a few hundred metres across: a narrow lens from far keeps them readable.
        camera.components.set(PerspectiveCameraComponent(near: 1, far: 6_000, fieldOfViewInDegrees: 40))
        root.addChild(camera)
        root.addChild(fixed)
        root.addChild(trainsRoot)
    }

    func setCamera(_ o: OrbitCamera) {
        camera.look(at: o.target, from: o.position, relativeTo: nil)
    }

    /// The station's colours. The platform and shop greys mirror the station map's (`Palette` in
    /// StationSceneView.swift), the ground and track the map style's land and station-rail ink (the rail ink's alpha
    /// mixed onto the land, since the 3D materials are opaque).
    private enum Colors {
        static func ground(_ dark: Bool) -> String { MapStyle.colors(dark: dark).land }
        static func track(_ dark: Bool) -> String { dark ? "#676767" : "#949494" }
        static func platform(_ dark: Bool) -> String { dark ? "#2a2a2a" : "#dcdcdc" }
        static func building(_ dark: Bool) -> String { dark ? "#222222" : "#e6e6e6" }
        /// Roofs one step darker (light) or lighter (dark) than the platform grey, to tell them from the floor.
        static func roof(_ dark: Bool) -> String { dark ? "#3a3a3a" : "#c4c4c4" }
        /// `accent-soft` (signal yellow at 35 % light, 16 % dark) mixed onto the land: the hall grey is too close to
        /// the ground's to find the upper level.
        static func upperLevel(_ dark: Bool) -> String { dark ? "#39341d" : "#f7ebba" }
    }

    func build(map: StationMap, dark: Bool) {
        let scene = StationScene3D.build(map)
        self.scene = scene
        fixed.children.removeAll()
        trainsRoot.children.removeAll()
        cars = [:]
        carsDark = nil

        // The ground: the terrain grid where the map has one (its steep cells a shade apart, like walls), over a flat
        // backdrop below its lowest point; else flat at rail level.
        let g = scene.ground
        let ground = ModelEntity(mesh: .generatePlane(width: Float(g.maxX - g.minX), depth: Float(g.maxZ - g.minZ)), materials: [Self.flat(Colors.ground(dark))])
        ground.position = SIMD3(Float((g.minX + g.maxX) / 2), Float(scene.terrain == nil ? scene.railY - 0.02 : scene.backdropY), Float((g.minZ + g.maxZ) / 2))
        fixed.addChild(ground)
        // 5 cm down: the ground model reads the platforms as ground, and level with their tops the two would flicker.
        if let terrain = scene.terrain {
            add(terrain, top: Colors.ground(dark), dark: dark)?.position.y = -0.05
        }

        var tracksMesh = StationScene3D.MeshData()
        for t in scene.tracks { tracksMesh.append(StationScene3D.strip(t.points.map { .init($0.x, t.y, $0.y) }, width: t.width)) }
        add(tracksMesh, top: Colors.track(dark), dark: dark)

        var platforms = StationScene3D.MeshData()
        for p in scene.platforms { for piece in p.pieces { platforms.append(StationScene3D.mesh(piece)) } }
        add(platforms, top: Colors.platform(dark), dark: dark)

        // Slightly see-through, so the levels, platforms and trains inside and behind them still show.
        var buildings = StationScene3D.MeshData()
        for b in scene.buildings { buildings.append(StationScene3D.mesh(b.prism, bottomCap: true)) }
        add(buildings, top: UIColor(cssColor: Colors.building(dark)), dark: dark, opacity: 0.8)

        // Roofs: thin sheets under their measured tops.
        var roofs = StationScene3D.MeshData()
        for r in scene.roofs { roofs.append(StationScene3D.mesh(r.prism, bottomCap: true)) }
        add(roofs, top: UIColor(cssColor: Colors.roof(dark)), dark: dark, opacity: 0.5)

        var slabs = StationScene3D.MeshData()
        for s in scene.slabs { slabs.append(StationScene3D.mesh(s.prism, bottomCap: true)) }
        add(slabs, top: Colors.upperLevel(dark), dark: dark)

        // Ways between the levels in the secondary ink, so they read against the greys.
        let link = UIColor(Ink.text2).resolvedColor(with: UITraitCollection(userInterfaceStyle: dark ? .dark : .light))
        var links = StationScene3D.MeshData()
        for r in scene.ramps { links.append(StationScene3D.strip(r.points, width: r.width, twoSided: true)) }
        for c in scene.columns { links.append(StationScene3D.mesh(c)) }
        add(links, top: link, dark: dark)

        tracks = [:]
        for p in map.platforms {
            if let t = StationScene3D.platformTrack(map, platform: p) { tracks[p.id] = (t, StationScene3D.platformMiddle(p, track: t)) }
        }
    }

    /// Puts each shown train's cars where the schedule says; removes the trains no longer shown.
    func placeTrains(_ trains: [StationScene3D.Scene3DTrain], map: StationMap, dark: Bool, type: (String) -> TrainType?, brand: (String) -> String?) {
        if carsDark != dark {
            trainsRoot.children.removeAll()
            cars = [:]
            carsDark = dark
        }
        var seen = Set<String>()
        for t in trains where t.state != .upcoming {
            guard let pid = t.platformId, let place = tracks[pid], let platform = map.platforms.first(where: { $0.id == pid }) else { continue }
            // Its sector ("2a") when the board names one, else the platform's middle.
            let middle = StationScene3D.platformMiddle(platform, track: place.track, sector: t.platform)
            let spec = StationScene3D.cars(for: t.trainType.flatMap(type))
            let railY = Float(scene?.railY ?? 0)
            let places = StationScene3D.carPlaces(map, track: place.track, middleM: middle, offsetM: t.offsetM, count: spec.count, carLength: spec.length)
            seen.insert(t.id)
            var entities = cars[t.id] ?? []
            if entities.count != places.count {
                entities.forEach { $0.removeFromParent() }
                let colour = MapStyle.opColor(t.operatorId.flatMap(brand), dark: dark)
                let size = StationScene3D.carSize(spec.template)
                let mesh = carMesh(length: spec.length, width: size.width, height: size.height)
                entities = places.indices.map { i in
                    let top = i == 0 ? MapStyle.lighten(colour, 0.35) : colour
                    let e = ModelEntity(mesh: mesh, materials: [Self.flat(top), UnlitMaterial(color: Self.shade(UIColor(cssColor: top), dark: dark))])
                    trainsRoot.addChild(e)
                    return e
                }
                cars[t.id] = entities
            }
            for (e, p) in zip(entities, places) {
                e.transform = Transform(rotation: simd_quatf(angle: Float(p.yaw), axis: [0, 1, 0]), translation: [Float(p.x), railY, Float(p.z)])
            }
        }
        for (id, entities) in cars where !seen.contains(id) {
            entities.forEach { $0.removeFromParent() }
            cars[id] = nil
        }
    }

    /// A car body along local x, from just above the rails (its entity sits at rail level) to its height (the roof in material 0, the sides in 1).
    private func carMesh(length: Double, width: Double, height: Double) -> MeshResource {
        let key = "\(length)-\(width)-\(height)"
        if let m = carMeshes[key] { return m }
        let l = length / 2, w = width / 2
        let prism = StationScene3D.Prism(footprint: [Pt(-l, -w), Pt(l, -w), Pt(l, w), Pt(-l, w)], bottom: 0.4, top: height)
        let m = (try? Self.resource(StationScene3D.mesh(prism))) ?? .generateBox(width: Float(length), height: Float(height), depth: Float(width))
        carMeshes[key] = m
        return m
    }

    @discardableResult
    private func add(_ m: StationScene3D.MeshData, top: String, dark: Bool) -> ModelEntity? {
        add(m, top: UIColor(cssColor: top), dark: dark)
    }

    @discardableResult
    private func add(_ m: StationScene3D.MeshData, top: UIColor, dark: Bool, opacity: Float = 1) -> ModelEntity? {
        guard !m.indices.isEmpty, let mesh = try? Self.resource(m) else { return nil }
        var materials = [UnlitMaterial(color: top), UnlitMaterial(color: Self.shade(top, dark: dark))]
        if opacity < 1 { for i in materials.indices { materials[i].blending = .transparent(opacity: .init(floatLiteral: opacity)) } }
        let entity = ModelEntity(mesh: mesh, materials: materials)
        fixed.addChild(entity)
        return entity
    }

    /// The mesh with faces looking up in material 0 and the rest (walls, undersides) in material 1: unlit colours,
    /// with the walls a shade apart so the shapes read without lights to compute.
    static func resource(_ m: StationScene3D.MeshData) throws -> MeshResource {
        var d = MeshDescriptor(name: "station3d")
        d.positions = MeshBuffers.Positions(m.positions)
        d.normals = MeshBuffers.Normals(m.normals)
        d.primitives = .triangles(m.indices)
        d.materials = .perFace(stride(from: 0, to: m.indices.count, by: 3).map { m.normals[Int(m.indices[$0])].y > 0.5 ? 0 : 1 })
        return try MeshResource.generate(from: [d])
    }

    static func flat(_ hex: String) -> UnlitMaterial { UnlitMaterial(color: UIColor(cssColor: hex)) }

    /// Walls: the same colour darker in light mode, lighter in dark mode (a shade of a token colour, not a new one).
    static func shade(_ c: UIColor, dark: Bool) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: dark ? min(1, b * 1.35 + 0.04) : b * 0.8, alpha: a)
    }
}
