//
//  StationMapScreen.swift
//  Clack
//

import ClackCore
import CoreLocation
import ClackDesign
import SwiftUI

/// The station map and the Layover Guide (pages/StationMapPage.tsx). Opened from a station page, or from a connection
/// with the two tracks, their times and operators: then it shows the walk between the platforms, how much time is
/// left, and which amenities are open during the layover and close to the way. The ends can also be any point on the
/// map (an amenity, an entrance, "my location"), picked from the search.
struct StationMapScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    let link: StationMapLink

    private enum Loaded { case loading, none, map(StationMap) }
    private enum Picking: String, Identifiable { case find, from, to; var id: String { rawValue } }

    @State private var loaded = Loaded.loading
    @State private var info: StationInfo?
    @State private var level: String?
    @State private var filter: String?
    @State private var listView = false
    /// The 3D view (one-station demo, Debug builds on iOS 18 and later).
    @State private var show3D = false
    @State private var poi: StationPoi?
    /// The open place's sheet content height, so the sheet fits it.
    @State private var poiHeight: CGFloat = 200
    @State private var picked: Date?
    @State private var planning = false
    @State private var picking: Picking?
    @State private var along = false
    @State private var showSteps = false
    @State private var now = Date().timeIntervalSince1970 * 1000
    // What the web keeps in the URL.
    @State private var from: String?
    @State private var to: String?
    @State private var arr: Double?
    @State private var dep: Double?
    @State private var operatorA: String?
    @State private var operatorB: String?
    @State private var canceledA = false
    @State private var canceledB = false
    @State private var live = false
    @State private var seeded = false
    @State private var cardHeight: CGFloat = 0
    @State private var stateCache = PoiStateCache()
    /// How exact the last position was (metres), while the walk starts at you.
    @State private var meAccuracy: Double?
    /// Walk mode, over the map.
    @State private var walking = false
    /// Walk mode started by itself once already on this screen (a layover near the station).
    @State private var autoWalked = false
    @AppStorage("walkModeAutoStart") private var walkModeAuto = true

    private var tz: String { "Europe/Stockholm" }
    private var clock: ClockFormat { app.settings.clock }

    var body: some View {
        Group {
            switch loaded {
            case .loading:
                Page { Skeleton(height: 300) }
            case .none:
                Page {
                    BackLink()
                    Text(l10n.t("stationMap.none")).clack(.body).foregroundStyle(Ink.text2)
                }
            case .map(let map):
                if let level { content(map, level: level) } else { Page { Skeleton(height: 300) } }
            }
        }
        .task {
            if !seeded {
                seeded = true
                from = link.from; to = link.to
                arr = link.arrival; dep = link.departure
                operatorA = link.operatorA; operatorB = link.operatorB
                canceledA = link.canceledA; canceledB = link.canceledB; live = link.live
                #if DEBUG
                // `-stationSteps` opens the directions list, to check or photograph it.
                if CommandLine.arguments.contains("-stationSteps") { showSteps = true }
                // `-walkMode` opens walk mode on the route (with `-simulateWalk`, walking it).
                if CommandLine.arguments.contains("-walkMode") { walking = true }
                // `-station3D` opens the 3D view (where it is offered).
                if CommandLine.arguments.contains("-station3D") { show3D = true }
                // `-stationTime <ms>` looks at opening hours at that moment (a layover seen from the morning it happens).
                let args = CommandLine.arguments
                if let at = args.firstIndex(of: "-stationTime"), args.indices.contains(at + 1), let ms = Double(args[at + 1]) {
                    picked = Date(timeIntervalSince1970: ms / 1000)
                }
                #endif
            }
            info = await app.stations.info(link.stationId)
            if let map = await app.stations.map(link.stationId) {
                loaded = .map(map)
                level = StationSceneLogic.initialLevel(map, startLevel: startLevel(map), current: level)
                #if DEBUG
                // `-stationPoi <id>` opens a place's card (to check or photograph it).
                let args = CommandLine.arguments
                if let at = args.firstIndex(of: "-stationPoi"), args.indices.contains(at + 1) { poi = map.pois.first { $0.id == args[at + 1] } }
                #endif
            } else {
                loaded = .none
            }
        }
        // The clock ticks every 30 s.
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                now = Date().timeIntervalSince1970 * 1000
            }
        }
        .onChange(of: from) { reselectLevel() }
        .onChange(of: to) { reselectLevel() }
        // Walking from "My location" (owner, 2026-10-25): the position is followed while the walk starts at you, and the
        // walk is planned again from the walkway point nearest you whenever that changes, so "you" and the next step move
        // as you walk. iOS asks once for the precise position if only an approximate one is shared.
        .task(id: walkingMe) {
            guard walkingMe else { meAccuracy = nil; return }
            let location = LocationModel.shared
            location.start()
            location.askPreciseForWalking()
            while !Task.isCancelled {
                if case .map(let map) = loaded, let fix = location.location, -fix.timestamp.timeIntervalSinceNow < 30 { follow(map, fix) }
                try? await Task.sleep(for: .seconds(2))
            }
            location.stop()
        }
        .overlay(alignment: .top) {
            // Indoors GPS is rough: say how rough rather than pretend.
            if walkingMe, let m = meAccuracy, m > 20 {
                Text(l10n.t("stationMap.roughGps", ["m": String(Int(m.rounded()))]))
                    .clack(.caption).foregroundStyle(Ink.text2)
                    .padding(.vertical, 4).padding(.horizontal, 12)
                    .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .padding(.top, 116)
                    .allowsHitTesting(false)
            }
        }
        // Full-bleed: the map runs under where the bar would be; its own buttons float over it.
        .toolbar(.hidden, for: .navigationBar)
        .countsScreen("stationMap")
    }

    /// The level the walk starts on, when it has an end.
    private func startLevel(_ map: StationMap) -> String? {
        (StationRouting.resolveEndpoint(map, from) ?? StationRouting.resolveEndpoint(map, to))?.node.level
    }

    /// Show the level the walk starts on (or the main level), and again whenever the start changes.
    private func reselectLevel() {
        guard case .map(let map) = loaded else { return }
        level = StationSceneLogic.initialLevel(map, startLevel: startLevel(map), current: level)
    }

    // MARK: derived

    private func window() -> (Double, Double) {
        if let arr, let dep { return (arr, dep) }
        let t = picked.map { $0.timeIntervalSince1970 * 1000 } ?? now
        return (t, t)
    }

    /// Whether a place is open at the time being looked at. Worked out once per place per minute: the map asks for
    /// it for every pin on every frame of a pan, and each answer means walking the opening hours minute by minute.
    private func state(_ p: StationPoi) -> OpenState {
        let w = window()
        return stateCache.state(p, from: w.0, to: w.1)
    }

    private func levelName(_ map: StationMap, _ id: String) -> String { map.levels.first { $0.id == id }?.name ?? id }

    private func label(_ map: StationMap, _ e: Endpoint) -> String {
        switch e.kind {
        case .track: l10n.t("stationMap.trackN", ["track": e.track ?? ""])
        case .poi: e.poi.flatMap { $0.name.isEmpty ? l10n.t("stationMap.cat.\($0.category.rawValue)") : $0.name } ?? ""
        case .me: l10n.t("stationMap.myLocationApprox")
        case .node: nodeLabel(map, e.node, centre: nil)
        }
    }

    /// Unnamed entrances are told apart by where they are from the station's middle (true north).
    private func nodeLabel(_ map: StationMap, _ n: StationNode, centre: (x: Double, y: Double)?) -> String {
        if let name = n.name, !name.isEmpty { return name }
        if n.type != .entrance { return levelName(map, n.level) }
        guard let centre else { return l10n.t("stationMap.entranceOn", ["level": levelName(map, n.level)]) }
        let dir = StationSceneLogic.compass(of: n, from: centre)
        return l10n.t("stationMap.entranceDir", ["dir": l10n.t("stationMap.compass.\(dir)"), "level": levelName(map, n.level)])
    }

    private var walkingMe: Bool { from?.hasPrefix("me:") == true }

    /// Debug builds: `-simulateWalk` walks the route at 1.3 m/s in walk mode, to watch it without a station.
    private var simulateWalk: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-simulateWalk")
        #else
        false
        #endif
    }

    /// The walk starts at the walkway point nearest the new position, on the level you're on.
    private func follow(_ map: StationMap, _ fix: CLLocation) {
        meAccuracy = fix.horizontalAccuracy
        let here = StationRouting.resolveEndpoint(map, from)?.node
        let local = StationRouting.toLocal(map, lat: fix.coordinate.latitude, lon: fix.coordinate.longitude)
        let reach = 60 + min(max(fix.horizontalAccuracy, 0), 150)
        guard let node = StationRouting.nearestNode(map, level: here?.level ?? level ?? "", x: local.x, y: local.y, maxMeters: reach),
              node.id != here?.id else { return }
        setRoute("me:\(node.id)", to)
    }

    private func setRoute(_ f: String?, _ t: String?) {
        from = f
        to = t
        // A layover's times only belong to the two tracks they came with.
        if !(f != nil && t != nil && !(f ?? "").contains(":") && !(t ?? "").contains(":")) {
            arr = nil; dep = nil; operatorA = nil; operatorB = nil; canceledA = false; canceledB = false
        }
    }

    private func pickAs(_ end: StationMapEnd, _ spec: String) {
        if end == .from { setRoute(spec, to == spec ? nil : to) } else { setRoute(from == spec ? nil : from, spec) }
        planning = true
        picking = nil
    }

    private func clearRoute() {
        setRoute(nil, nil)
        planning = false
        along = false
        showSteps = false
    }

    // MARK: content

    private func content(_ map: StationMap, level: String) -> some View {
        let profile = app.walkProfile
        let fromE = StationRouting.resolveEndpoint(map, from)
        let toE = StationRouting.resolveEndpoint(map, to)
        let route = StationRouting.routeBetween(map, fromE, toE, profile: profile)
        let detours: [String: Double]? = along && route != nil ? StationRouting.secondsFrom(map, sources: route!.nodes.map(\.id), profile: profile) : nil
        let activeCategories = filter.flatMap { key in StationSceneLogic.filters.first { $0.key == key }?.categories }
        let dim: (StationPoi) -> Bool = { p in
            (activeCategories.map { !$0.contains(p.category) } ?? false) || (detours.map { !(($0[p.node] ?? .infinity) <= StationSceneLogic.alongSeconds) } ?? false)
        }
        let layover = arr != nil && dep != nil
        let dark = app.colorScheme != .light
        var marks: [StationSceneLogic.PlatformMark] = []
        var pins: [StationSceneLogic.PlacePin] = []
        if let fromE {
            if let platform = fromE.platform {
                let colour = MapStyle.opColor(operatorA.flatMap { app.operatorsById[$0]?.brandColor }, dark: dark)
                marks.append(.init(platformId: platform.id, label: arr.map { l10n.t("stationMap.arriveChip", ["track": fromE.track ?? "", "time": Format.time($0, tz: tz, clock: clock)]) } ?? l10n.t("stationMap.fromChip", ["track": fromE.track ?? ""]), color: colour))
            } else {
                pins.append(.init(x: fromE.poi?.x ?? fromE.node.x, y: fromE.poi?.y ?? fromE.node.y, level: fromE.node.level, label: label(map, fromE), kind: fromE.kind == .me ? .me : .from, accuracyM: fromE.kind == .me ? meAccuracy : nil))
            }
        }
        if let toE {
            if let platform = toE.platform {
                let colour = MapStyle.opColor(operatorB.flatMap { app.operatorsById[$0]?.brandColor }, dark: dark)
                marks.append(.init(platformId: platform.id, label: dep.map { l10n.t("stationMap.departChip", ["track": toE.track ?? "", "time": Format.time($0, tz: tz, clock: clock)]) } ?? l10n.t("stationMap.toChip", ["track": toE.track ?? ""]), color: colour))
            } else {
                pins.append(.init(x: toE.poi?.x ?? toE.node.x, y: toE.poi?.y ?? toE.node.y, level: toE.node.level, label: label(map, toE), kind: .to))
            }
        }
        let steps = route.map { StationRouting.instructions(map, $0, from: fromE.map(Place.endpoint), to: toE.map(Place.endpoint)) } ?? []
        let stepLevels = StationSceneLogic.stepLevels(steps, routeStart: route?.levels.first, fallback: level)
        let planningOrSet = from != nil || to != nil || planning

        return GeometryReader { proxy in
        ZStack(alignment: .topLeading) {
            if listView {
                list(map, dim: dim, detours: detours)
            } else {
                StationSceneView(
                    map: map, level: level, route: route, marks: marks, pins: pins, poiState: state, dimPoi: dim,
                    onPoi: { poi = $0 }, fitKey: "\(from ?? "")|\(to ?? "")|\(level)", selectedPoi: poi?.id,
                    insets: .init(top: 140, bottom: (layover ? 250 : planningOrSet ? 320 : 150))
                )
            }
            header(map)
            filters
            side(map, level: level)
            VStack {
                Spacer()
                bottom(map, level: level, fromE: fromE, toE: toE, route: route, steps: steps, stepLevels: stepLevels, layover: layover, planningOrSet: planningOrSet)
            }
        }
        .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Ink.mapBg)
        .sheet(item: $picking) { mode in
            PlaceSearchSheet(map: map, mode: mode == .from ? .from : mode == .to ? .to : .find, level: level, state: state,
                             onPick: { spec in pickAs(mode == .from ? StationMapEnd.from : .to, spec) }, onPoi: { p in picking = nil; poi = p })
                .presentationDetents([.fraction(0.8), .large])
        }
        .fullScreenCover(isPresented: $walking) {
            if let route {
                WalkModeView(map: map, route: route, simulate: simulateWalk, levelName: { levelName(map, $0) }, poiState: state)
            }
        }
        // A layover: walk mode starts by itself once you are within 150 m of the station (Settings can turn it off).
        .task(id: layover && route != nil && walkModeAuto && !autoWalked) {
            guard layover, route != nil, walkModeAuto, !autoWalked, LocationModel.shared.allowed else { return }
            let location = LocationModel.shared
            location.start()
            defer { location.stop() }
            while !Task.isCancelled && !autoWalked {
                if let fix = location.location, -fix.timestamp.timeIntervalSinceNow < 30,
                   StationSceneLogic.within(map, lat: fix.coordinate.latitude, lon: fix.coordinate.longitude, meters: 150) {
                    autoWalked = true
                    walking = true
                }
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .sheet(item: $poi) { p in
            PoiSheet(map: map, poi: p, state: OpeningHours.openState(p.openingHours, from: window().0, to: window().1), detour: detours?[p.node], onHeight: { poiHeight = $0 }) { end in
                poi = nil
                pickAs(end, "p:\(p.id)")
            }
            // As tall as what it says (designer, 2026-11-07: "two buttons floating above 300 pt of nothing").
            .presentationDetents([.height(min(max(poiHeight + 128, 220), 700)), .large])
        }
    }

    private func header(_ map: StationMap) -> some View {
        HStack(spacing: 8) {
            MapButton(icon: "arrow-left", label: l10n.t("common.back")) { dismiss() }
            // A draft says so under the name (not a badge); what it is missing is said in the card below.
            VStack(alignment: .leading, spacing: 0) {
                Text(map.name).clack(.headline).foregroundStyle(Ink.text).lineLimit(1)
                if map.quality != .handCurated {
                    Text(l10n.t("stationMap.draftOsm")).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
                }
            }
                .padding(.vertical, 8).padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                .hairlineBorder(radius: 14)
                .accessibilityAddTraits(.isHeader)
            MapButton(icon: "search", label: l10n.t("stationMap.search")) { picking = .find }
            MapButton(icon: "train-front", label: l10n.t("stationMap.departures")) { router.push(.board(stationId: map.stationId, arrivals: false)) }
        }
        .padding(.horizontal, 12).padding(.top, 12)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StationSceneLogic.filters, id: \.key) { f in
                    ChipButton(text: l10n.t("stationMap.filters.\(f.key)"), active: filter == f.key) { filter = filter == f.key ? nil : f.key }
                }
            }
            .padding(.horizontal, 12)
        }
        // The row runs on past the edge: a fade says so (designer, 2026-11-07: the chips looked cut off).
        .mask(
            // A mask reads alpha only: any opaque ink does.
            HStack(spacing: 0) {
                Ink.bg
                LinearGradient(colors: [Ink.bg, Ink.bg.opacity(0)], startPoint: .leading, endPoint: .trailing).frame(width: 28)
            }
        )
        .padding(.top, 64)
    }

    private func side(_ map: StationMap, level: String) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            if map.levels.count > 1 && !listView {
                // The floors as the app's one pick-one control (owner, 2026-11-07); the chosen segment is the floor's
                // name, so the separate label that sat under it is gone.
                let levels = map.levels.sorted { $0.order < $1.order }
                SegmentedControl(
                    selection: Binding(get: { level }, set: { self.level = $0 }),
                    options: levels.map { ($0.id, StationSceneLogic.levelLabel($0)) }, small: true
                )
                .frame(width: min(260, CGFloat(levels.count) * 64 + 8))
            }
            MapButton(icon: listView ? "map" : "list", label: l10n.t(listView ? "stationMap.map" : "stationMap.list")) { listView.toggle() }
            #if DEBUG
            // The 3D view is a demo at Jönköping C only until the owner has tried it (BUILDOUT, 2026-10-29).
            if #available(iOS 18.0, *), map.stationId == "740000090", !listView {
                MapButton(icon: "box", label: l10n.t("station3d.open")) { show3D = true }
                    .fullScreenCover(isPresented: $show3D) { StationScene3DView(map: map) }
            }
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.trailing, 12).padding(.top, 112)
    }

    /// All the places that aren't dimmed, open first (the list view).
    private func list(_ map: StationMap, dim: (StationPoi) -> Bool, detours: [String: Double]?) -> some View {
        let sorted = map.pois.sorted { a, b in
            let (ra, rb) = (StationSceneLogic.stateRank(state(a)), StationSceneLogic.stateRank(state(b)))
            if ra != rb { return ra < rb }
            if a.category.rawValue != b.category.rawValue { return a.category.rawValue < b.category.rawValue }
            return a.name.localizedCompare(b.name) == .orderedAscending
        }
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sorted.filter { !dim($0) }) { p in
                    PoiRow(poi: p, state: state(p), level: levelName(map, p.level), detour: detours?[p.node]) { poi = p }
                }
            }
            .padding(.horizontal, 16).padding(.top, 168).padding(.bottom, 220)
        }
        .background(Ink.bg)
    }

    // MARK: the card at the bottom

    private func bottom(_ map: StationMap, level: String, fromE: Endpoint?, toE: Endpoint?, route: StationRoute?, steps: [Instruction], stepLevels: [String], layover: Bool, planningOrSet: Bool) -> some View {
        let walkMin = route.map { max(1, Int(($0.seconds.asDouble / 60).rounded())) }
        return ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if planningOrSet {
                    if layover {
                        HStack(spacing: 12) {
                            // No route (the other platform isn't drawn yet): said, not a dash (user test 2026-11-07).
                            Text(walkMin.map { l10n.t("stationMap.walk", ["min": String($0)]) } ?? l10n.t(fromE?.platform?.unconnected == true || toE?.platform?.unconnected == true ? "stationMap.noRouteToPlatform" : "stationMap.noWalk")).clack(walkMin == nil ? .body : .walkBig).monospacedDigit().foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                            // Walking time only: the change's rating is the change rule's (the gauge), shown on the trip.
                            Spacer(minLength: 0)
                            IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: clearRoute)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            VStack(spacing: 8) {
                                EndButton(caption: l10n.t("stationMap.from"), value: fromE.map { label(map, $0) }, me: fromE?.kind == .me) { picking = .from }
                                EndButton(caption: l10n.t("stationMap.to"), value: toE.map { label(map, $0) }, me: toE?.kind == .me) { picking = .to }
                            }
                            VStack(spacing: 8) {
                                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: clearRoute)
                                IconButton(icon: "arrow-down-up", label: l10n.t("stationMap.swap"), size: .overMap) { setRoute(to, from) }
                                    .disabled(from == nil && to == nil)
                            }
                        }
                    }
                    if !layover, fromE != nil, toE != nil, let route {
                        Text(route.seconds < 30 ? l10n.t("stationMap.here") : l10n.t("stationMap.walk", ["min": String(walkMin ?? 1)]))
                            .clack(.walkBig).monospacedDigit().foregroundStyle(Ink.text)
                    }
                    if fromE != nil, toE != nil, route == nil {
                        let unconnected = fromE?.platform?.unconnected == true || toE?.platform?.unconnected == true
                        Text(l10n.t(unconnected ? "stationMap.noRouteToPlatform" : app.settings.stepFree ? "stationMap.noStepFree" : "stationMap.noRoute")).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    if let me = [fromE, toE].compactMap({ $0 }).first(where: { $0.kind == .me }) {
                        Text(l10n.t("stationMap.locationNote", ["level": levelName(map, me.node.level)])).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    if layover, let arr, let dep {
                        Text(l10n.t("stationMap.layover", ["from": Format.time(arr, tz: tz, clock: clock), "to": Format.time(dep, tz: tz, clock: clock), "min": String(Int(((dep - arr) / 60_000).rounded()))]))
                            .clack(.caption).foregroundStyle(Ink.text2)
                    }
                    if let route, !route.steps.isEmpty {
                        // Walk mode on a row of its own: the walk's main action.
                        Button { walking = true } label: {
                            HStack(spacing: 8) { LucideIcon(name: "navigation", size: 16); Text(l10n.t("stationMap.walkMode.start")) }
                                .clack(.button).foregroundStyle(Ink.onAccent).frame(maxWidth: .infinity, minHeight: 44)
                                .background(Ink.accent, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        HStack(spacing: 8) {
                            Button { showSteps.toggle() } label: {
                                HStack(spacing: 8) { LucideIcon(name: "route", size: 14); Text(l10n.t("stationMap.steps")) }
                                    .clack(.chipButton).foregroundStyle(Ink.text).padding(.horizontal, 16).frame(minHeight: 34)
                                    .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                                    .hairlineBorder(radius: Radius.controlSm)
                            }
                            .buttonStyle(.plain).accessibilityAddTraits(showSteps ? .isSelected : [])
                            ChipButton(text: l10n.t("stationMap.alongPath"), active: along) { along.toggle() }
                        }
                    }
                    if showSteps, let route {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                                stepRow(map, step, index: i, level: level, stepLevel: stepLevels[i], multi: route.levels.count > 1)
                            }
                        }
                    }
                } else {
                    // Directions as the system button every other action uses (designer, 2026-11-07: "yet another
                    // button style"); the time as the system's own picker, with a line saying what it changes.
                    HStack(spacing: 8) {
                        Button { planning = true } label: {
                            HStack(spacing: 8) { LucideIcon(name: "route", size: 14); Text(l10n.t("stationMap.directions")) }
                        }
                        .buttonStyle(.clack(.primary, small: true))
                        Spacer(minLength: 0)
                        timeChip
                        if picked != nil { ChipButton(text: l10n.t("stationMap.now")) { picked = nil } }
                    }
                    Text(l10n.t("stationMap.timeHint")).clack(.caption).foregroundStyle(Ink.text2)
                }
                // What the draft doesn't have yet, in full (the header has room for "Draft" only).
                if let note = StationSceneLogic.coverageNote(map) {
                    Text(l10n.t(note)).clack(.caption).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
                }
                Text("\(l10n.t("stationMap.hoursNote")) · © OpenStreetMap contributors").clack(.mapAttribution).foregroundStyle(Ink.text3)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { cardHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(height: min(cardHeight, 360))
        .background(Ink.glassStrong, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .padding(.horizontal, 12).padding(.bottom, 12)
    }

    private func stepRow(_ map: StationMap, _ step: Instruction, index: Int, level: String, stepLevel: String, multi: Bool) -> some View {
        let text = l10n.t("stationMap.step.\(step.key.rawValue)", [
            "track": step.track ?? "", "place": step.endpoint.map { label(map, $0) } ?? "",
            "level": step.level.map { levelName(map, $0) } ?? "", "min": String(max(1, Int((Double(step.seconds) / 60).rounded()))),
        ])
        let here = multi && stepLevel == level
        return Group {
            if multi {
                // On a walk that changes level, each step shows its level on the plan when tapped.
                Button { self.level = stepLevel } label: {
                    (Text("\(index + 1). \(text)") + (step.level == nil ? Text(" · \(levelName(map, stepLevel))").foregroundStyle(Ink.text2) : Text("")))
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain).accessibilityAddTraits(here ? .isSelected : [])
            } else {
                Text("\(index + 1). \(text)")
            }
        }
        .clack(.stopName).fontWeight(here || !multi ? .semibold : .regular)
        .foregroundStyle(here || !multi ? Ink.text : Ink.text2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The time to look at opening hours for: the system's own time picker, in sight (designer, 2026-11-07: the
    /// picker hidden under a chip meant "Now" did nothing anyone could see).
    private var timeChip: some View {
        HStack(spacing: 8) {
            LucideIcon(name: "clock", size: 14).foregroundStyle(Ink.text2)
            DatePicker("", selection: Binding(get: { picked ?? Date() }, set: { picked = $0 }), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Ink.accentInk)
                .accessibilityLabel(l10n.t("stationMap.pickTime"))
        }
    }
}

private extension Int {
    var asDouble: Double { Double(self) }
}

/// Opening state per place, kept for the minute being asked about.
@MainActor
final class PoiStateCache {
    private var window = ""
    private var states: [String: OpenState] = [:]

    func state(_ p: StationPoi, from: Double, to: Double) -> OpenState {
        let key = "\(Int(from / 60_000))|\(Int(to / 60_000))"
        if key != window {
            window = key
            states = [:]
        }
        if let known = states[p.id] { return known }
        let computed = OpeningHours.openState(p.openingHours, from: from, to: to).state
        states[p.id] = computed
        return computed
    }
}

/// One end of a walk: its caption, and what it is or "Choose…".
private struct EndButton: View {
    @Environment(L10n.self) private var l10n
    let caption: String
    let value: String?
    var me = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(caption).clack(.caption).foregroundStyle(Ink.text2).frame(minWidth: 38, alignment: .leading)
                if me { LucideIcon(name: "locate-fixed", size: 14).foregroundStyle(Ink.text) }
                Text(value ?? l10n.t("stationMap.choose")).clack(.body).fontWeight(value == nil ? .medium : .semibold)
                    .foregroundStyle(value == nil ? Ink.text3 : Ink.text).lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).frame(minHeight: 42)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .hairlineBorder(radius: Radius.input)
        }
        .buttonStyle(.plain)
    }
}

enum StationMapEnd { case from, to }

/// An amenity in a list: its pictogram, name, kind, floor and detour, and whether it's open.
struct PoiRow: View {
    @Environment(L10n.self) private var l10n
    let poi: StationPoi
    let state: OpenState
    let level: String
    var detour: Double?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                PoiBadge(category: poi.category)
                VStack(alignment: .leading, spacing: 1) {
                    Text(poi.name.isEmpty ? l10n.t("stationMap.cat.\(poi.category.rawValue)") : poi.name).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
                    Text(detail).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(l10n.t("stationMap.state.\(state.rawValue)")).clack(.chip)
                    .foregroundStyle(state == .open ? Ink.onTimeInk : state == .closingSoon ? Ink.lateInk : Ink.text3)
            }
            .padding(.vertical, 12).padding(.horizontal, 4)
            .opacity(state == .closed ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    private var detail: String {
        var text = "\(l10n.t("stationMap.cat.\(poi.category.rawValue)")) · \(level)"
        if let detour, detour <= StationSceneLogic.alongSeconds {
            text += " · " + l10n.t("stationMap.detour", ["min": String(max(1, Int((detour * 2 / 60).rounded(.up))))])
        }
        return text
    }
}

struct PoiBadge: View {
    var category: PoiCategory?
    var icon: String?
    var tint: Color?

    var body: some View {
        LucideIcon(name: icon ?? StationSceneLogic.icon(category ?? .other), size: 16)
            .foregroundStyle(tint != nil ? Ink.onTint : Ink.text)
            .frame(width: 32, height: 32)
            .background(tint ?? Ink.surfaceRaised, in: Circle())
            .overlay(Circle().strokeBorder(tint ?? Ink.hairline, lineWidth: 1))
    }
}

// MARK: search

/// Search the station: tracks, entrances and amenities. Picking a start or an end also offers "My location".
private struct PlaceSearchSheet: View {
    enum Mode { case find, from, to }

    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let map: StationMap
    let mode: Mode
    let level: String
    let state: (StationPoi) -> OpenState
    let onPick: (String) -> Void
    let onPoi: (StationPoi) -> Void
    @State private var query = ""
    @State private var locating: Locating = .idle
    @FocusState private var focused: Bool

    private enum Locating { case idle, busy, far, denied }

    private func levelName(_ id: String) -> String { map.levels.first { $0.id == id }?.name ?? id }

    var body: some View {
        let q = StationSceneLogic.fold(query.trimmingCharacters(in: .whitespaces))
        let centre = StationSceneLogic.centre(of: map)
        let tracks = Array(Set(map.platforms.flatMap(\.tracks))).sorted { a, b in
            let (x, y) = (Double(a) ?? 0, Double(b) ?? 0)
            return x != y ? x < y : a < b
        }
        var seen = Set<String>()
        let entrances: [(node: StationNode, label: String)] = map.nodes.filter { $0.type == .entrance }.compactMap { n in
            let name: String
            if let given = n.name, !given.isEmpty { name = given } else {
                name = l10n.t("stationMap.entranceDir", ["dir": l10n.t("stationMap.compass.\(StationSceneLogic.compass(of: n, from: centre))"), "level": levelName(n.level)])
            }
            return seen.insert(name).inserted ? (n, name) : nil
        }
        func matches(_ texts: [String?]) -> Bool { q.isEmpty || texts.contains { $0.map { StationSceneLogic.fold($0).contains(q) } ?? false } }
        let shownTracks = tracks.filter { q.isEmpty || $0 == q || $0.hasPrefix(q) || StationSceneLogic.fold(l10n.t("stationMap.trackN", ["track": $0])).contains(q) }
        let shownEntrances = entrances.filter { matches([$0.label, l10n.t("stationMap.entrance")]) }
        let shownPois = map.pois.filter { matches([$0.name, l10n.t("stationMap.cat.\($0.category.rawValue)"), $0.icon?.replacingOccurrences(of: "_", with: " ")]) }
            .sorted { a, b in
                let (ra, rb) = (StationSceneLogic.stateRank(state(a)), StationSceneLogic.stateRank(state(b)))
                if ra != rb { return ra < rb }
                return (a.name.isEmpty ? a.category.rawValue : a.name).compare(b.name.isEmpty ? b.category.rawValue : b.name, locale: Locale(identifier: "sv")) == .orderedAscending
            }
        let title = mode == .from ? l10n.t("stationMap.pickFrom") : mode == .to ? l10n.t("stationMap.pickTo") : l10n.t("stationMap.searchTitle", ["station": map.name])
        return content(title: title, q: q, shownTracks: shownTracks, shownEntrances: shownEntrances, shownPois: shownPois)
    }

    @Environment(\.dismiss) private var dismiss

    private func content(title: String, q: String, shownTracks: [String], shownEntrances: [(node: StationNode, label: String)], shownPois: [StationPoi]) -> some View {
        SheetFrame(title: title, onClose: { dismiss() }) {
            SearchField(text: $query, prompt: l10n.t("stationMap.searchPlaceholder"), focus: $focused)
            if mode != .find && q.isEmpty {
                Button { Task { await locate() } } label: {
                    HStack(spacing: 12) {
                        PoiBadge(icon: "locate-fixed", tint: Ink.me)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(l10n.t("stationMap.myLocation")).clack(.rowTitle).foregroundStyle(Ink.text)
                            Text(locationHint).clack(.caption).foregroundStyle(Ink.text2).multilineTextAlignment(.leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain).disabled(locating == .busy)
            }
            if !shownTracks.isEmpty {
                group(l10n.t("stationMap.tracks")) {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(shownTracks, id: \.self) { track in ChipButton(text: track) { onPick(track) } }
                    }
                }
            }
            if !shownEntrances.isEmpty {
                group(l10n.t("stationMap.entrances")) {
                    VStack(spacing: 0) {
                        ForEach(shownEntrances, id: \.node.id) { e in
                            Button { onPick("n:\(e.node.id)") } label: {
                                HStack(spacing: 12) {
                                    PoiBadge(icon: "door-open")
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(e.label).clack(.rowTitle).foregroundStyle(Ink.text)
                                        Text(levelName(e.node.level)).clack(.caption).foregroundStyle(Ink.text2)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.vertical, 12).contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            if !shownPois.isEmpty {
                group(l10n.t("stationMap.places")) {
                    LazyVStack(spacing: 0) {
                        ForEach(shownPois) { p in
                            PoiRow(poi: p, state: state(p), level: levelName(p.level), detour: nil) { mode == .find ? onPoi(p) : onPick("p:\(p.id)") }
                        }
                    }
                }
            }
            if !q.isEmpty && shownTracks.isEmpty && shownEntrances.isEmpty && shownPois.isEmpty {
                Text(l10n.t("stationMap.noResults", ["q": query.trimmingCharacters(in: .whitespaces)])).clack(.body).foregroundStyle(Ink.text2)
            }
        }
        .onAppear { focused = true }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).clack(.captionUpper).foregroundStyle(Ink.text2)
            content()
        }
    }

    private var locationHint: String {
        switch locating {
        case .busy: l10n.t("stationMap.locating")
        case .far: l10n.t("stationMap.notHere", ["station": map.name])
        case .denied: l10n.t("stationMap.noLocation")
        case .idle: l10n.t("stationMap.myLocationHint", ["level": levelName(level)])
        }
    }

    /// Core Location is only asked when "My location" is tapped. Indoors the fix is rough, so the radius grows with
    /// the reported accuracy.
    private func locate() async {
        locating = .busy
        guard let fix = await LocationModel.shared.current() else { locating = .denied; return }
        let local = StationRouting.toLocal(map, lat: fix.coordinate.latitude, lon: fix.coordinate.longitude)
        guard let node = StationRouting.nearestNode(map, level: level, x: local.x, y: local.y, maxMeters: 120 + min(max(fix.horizontalAccuracy, 0), 150)) else {
            locating = .far
            return
        }
        locating = .idle
        onPick("me:\(node.id)")
    }
}

// MARK: an amenity's sheet

private struct PoiSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    let map: StationMap
    let poi: StationPoi
    let state: (state: OpenState, closesAt: Double?)
    let detour: Double?
    /// How tall the content is, so the sheet can be just that.
    var onHeight: (CGFloat) -> Void = { _ in }
    let onRoute: (_ end: StationMapEnd) -> Void

    var body: some View {
        let name = poi.name.isEmpty ? l10n.t("stationMap.cat.\(poi.category.rawValue)") : poi.name
        let level = map.levels.first { $0.id == poi.level }?.name ?? poi.level
        SheetFrame(title: name, onClose: { dismiss() }) {
            VStack(alignment: .leading, spacing: 12) { content(level: level) }
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { onHeight($0) }
        }
    }

    @ViewBuilder
    private func content(level: String) -> some View {
            FlowLayout(spacing: 12, lineSpacing: 8) {
                Chip(text: stateLabel, tint: state.state == .open ? Ink.onTimeInk : state.state == .closingSoon ? Ink.lateInk : Ink.text2)
                Chip(text: l10n.t("stationMap.cat.\(poi.category.rawValue)"))
                Chip(text: level)
                if let fee { Chip(text: fee) }
                if let detour, detour <= StationSceneLogic.alongSeconds {
                    Chip(text: l10n.t("stationMap.detour", ["min": String(max(1, Int((detour * 2 / 60).rounded(.up))))]))
                }
            }
            if let hours = poi.openingHours {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("stationMap.hours").uppercased()).clack(.captionUpper).foregroundStyle(Ink.text2)
                    Text(OpeningHours.parse(hours) != nil ? hours.replacingOccurrences(of: #";\s*"#, with: " · ", options: .regularExpression) : hours)
                        .clack(.body).monospacedDigit().foregroundStyle(Ink.text)
                }
                // Checked on the station owner's page: say so and when; else the general note.
                if poi.hoursSource == "website", let checked = poi.hoursVerified {
                    Text(l10n.t("stationMap.hoursWebsite", ["date": checked])).clack(.caption).foregroundStyle(Ink.text2)
                } else if let stale = StationSceneLogic.hoursStale(map) {
                    // From OpenStreetMap, and not re-read for a month: say when they were.
                    Text(l10n.t("stationMap.hoursStale", ["date": stale])).clack(.caption).foregroundStyle(Ink.text2)
                } else {
                    Text(l10n.t("stationMap.hoursNote")).clack(.caption).foregroundStyle(Ink.text2)
                }
            } else {
                // Said in words here; the pin no longer wears a "?" for it (designer, 2026-11-07).
                Text(l10n.t("stationMap.hoursUnknown")).clack(.caption).foregroundStyle(Ink.text2)
            }
            if poi.approximate == true {
                // Placed from a description, not located (owner, 2026-10-30): say so, and what the description is.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    LucideIcon(name: "info", size: 12).foregroundStyle(Ink.text3)
                    Text(poi.whereText.map { l10n.t("stationMap.approximateWhere", ["where": $0]) } ?? l10n.t("stationMap.approximate"))
                        .clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            HStack(spacing: 8) {
                Button { onRoute(.to) } label: { HStack(spacing: 8) { LucideIcon(name: "route", size: 14); Text(l10n.t("stationMap.routeHere")) } }
                    .buttonStyle(.clack(.primary, small: true))
                ChipButton(text: l10n.t("stationMap.startHere")) { onRoute(.from) }
            }
    }

    private var stateLabel: String {
        if state.state == .closingSoon, let closes = state.closesAt {
            return l10n.t("stationMap.closesAt", ["time": Format.time(closes, tz: "Europe/Stockholm", clock: app.settings.clock)])
        }
        return l10n.t("stationMap.state.\(state.state.rawValue)")
    }

    private var fee: String? {
        switch poi.fee {
        case .free: l10n.t("stationMap.free")
        case .amount(let amount, _): l10n.t("stationMap.fee", ["amount": String(format: "%g", amount)])
        case nil: nil
        }
    }
}
