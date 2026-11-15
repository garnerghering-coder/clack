//
//  ExploreModel.swift
//  Clack
//

import ClackCore
import Foundation
import MapLibre
import Observation
import os
import ClackDesign
import SwiftUI

/// Everything the live map screen holds (LiveMapPage.tsx): the trains from the stream, what's selected, the filters,
/// follows, the search, and the status of the stream. The map itself is `controller`.
@MainActor
@Observable
final class ExploreModel {
    enum StopsState: Equatable {
        case loading
        case none
        case list([LiveTrainStop])
    }

    struct StationSheetTarget: Equatable { var id: String; var name: String }
    struct NotRunningTarget: Equatable { var number: String; var date: String? }

    @ObservationIgnored let controller = LiveMapController()
    @ObservationIgnored private weak var app: AppModel?

    // The stream and its state.
    private(set) var ready = false
    private(set) var loaded = false
    private(set) var streamDown = false
    private(set) var mode: String?
    private(set) var upstreamAt = 0.0
    private(set) var total = 0
    private(set) var shown = 0
    private(set) var zoom = 4.2
    private(set) var bbox: String?
    private(set) var lastMessage = 0.0
    /// A change every time the set of trains changes, so views that list them (the operators filter) refresh.
    private(set) var trainsVersion = 0

    // What's showing.
    var filters = ExploreLogic.Filters() { didSet { scheduleRender() } }
    private(set) var follows: [Follow] = []
    /// Counts follows and unfollows the server confirmed, for the success haptic (loading the list doesn't count).
    private(set) var followsConfirmed = 0
    /// Something the person asked for that couldn't be done, for a toast (a train that wouldn't load, a follow refused).
    struct Failure: Equatable {
        let id = UUID()
        let key: String
    }
    var failure: Failure?
    private(set) var selected: LiveTrainDetail?
    private(set) var stops: StopsState = .loading
    private(set) var scheduled: TrainView?
    var notRunning: NotRunningTarget?
    var stationSheet: StationSheetTarget?
    /// The station sheet that stepped aside for its station map or board, to show again on the way back.
    var stationToRestore: StationSheetTarget?
    /// Your trains left to run today, as Network now loaded them (for a disruption's "your trains" lines).
    var mineToday: [Leg] = []
    /// The top of Explore's sheet on screen (global y), while one is open: the map's corner controls sit above it.
    var sheetTop: CGFloat?
    var legend = false
    var showFilters = false
    /// The network status panel (the button beside the filters), its answer, and whether asking failed.
    /// Network now is open: the map shows the status meanwhile, late trains in colour (designer, 2026-11-14).
    var showNetwork = false {
        didSet {
            guard showNetwork != oldValue else { return }
            needsFullRender = true
            scheduleRender()
            // Track work, closures and incidents show while Network now is open.
            controller.setDisruptions(showNetwork ? network?.disruptions : nil)
            if !showNetwork { closeDisruption() }
        }
    }
    /// One disruption opened (from Network now's list, its track on the map, or a train of yours it touches): its sheet
    /// over Network now and its track lit (owner, 2026-11-15: "tap on them … go to that spot and tell you what's wrong").
    private(set) var disruption: NetworkStatus.Disruption?
    /// A disruption asked for by id before Network now has it (from a trip page); opened when it arrives.
    private var wantedDisruption: String?
    /// What the dots are coloured by now: the person's choice, or late trains while Network now is open.
    private var colorBy: ExploreLogic.ColorBy { showNetwork ? .lateOnly : controller.display.colorBy }
    private(set) var network: NetworkStatus?
    private(set) var networkFailed = false
    /// The corridor on show (highlighted on the map, its sheet open) and whether it has since cleared.
    private(set) var corridor: NetworkStatus.Corridor?
    private(set) var corridorGone = false
    var query = ""
    var searching = false
    private(set) var stationHits: [StationHit] = []
    /// The Explore tab is showing. When it isn't, the markers stop gliding (the tab bar takes the map out of the window;
    /// hiding it as well could leave it blank on return). Back on the tab, the map repaints and the trains are drawn again.
    var active = true {
        didSet {
            if active {
                controller.repaint()
                needsFullRender = true
                scheduleRender()
            } else {
                // Away from the tab: nothing glides, and the tracks fetched for gliding are let go once there are many
                // (they are asked for again as trains run on them), so the memory doesn't only grow (run 2: 152 to
                // 163 MB in three idle minutes, none of it given back after leaving Explore).
                glides.removeAll()
                if segments.count > Self.keptSegments {
                    segments.removeAll()
                    segmentsAsked.removeAll()
                }
            }
        }
    }

    /// How many fetched tracks are kept when leaving the tab.
    nonisolated static let keptSegments = 300

    /// Your dot is on the map by default once iOS allows it. iOS is asked only when you ask for your position (the
    /// locate button, or "Help place trains" in Settings), not when Explore opens (user test 2026-11-07, run 2).
    func showMyDot() {
        controller.showUserDot()
    }

    /// Location is switched off for Clack: the screen says so, with a way to Settings.
    var locationOff = false

    /// The locate button: centre on you. Not asked yet: iOS asks, and the map comes to you once allowed (the screen
    /// watches for it). Switched off: a word about it first, instead of jumping to Settings.
    func centreOnMe() {
        Usage.shared.count(.feature, "explore.myLocation")
        let location = LocationModel.shared
        if location.denied { locationOff = true; return }
        if !location.allowed { location.askIfNeeded(); return }
        controller.centreOnUser()
    }

    @ObservationIgnored private var openedWhereItMatters = false

    /// Once, when the map is first ready (designer, 2026-11-14: "open on the user's region or their next route, not
    /// all four countries with most of the screen empty"): your trip's route if one runs or leaves within 24 hours,
    /// else where you are if location is already allowed (never asked for here), else the four countries as before.
    /// Never over something you've opened or moved to already.
    func openWhereItMatters() async {
        guard !openedWhereItMatters, let client = app?.client else { return }
        openedWhereItMatters = true
        #if DEBUG
        let args = CommandLine.arguments
        if ["-exploreAt", "-train", "-station", "-exploreSearch", "-exploreSelect", "-exploreCorridor"].contains(where: args.contains) { return }
        #endif
        let now = Date.now.timeIntervalSince1970 * 1000
        var legs: [Leg] = await client.saved(["legs"]) ?? []
        if legs.isEmpty { legs = (try? await client.legs()) ?? [] }
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        if let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now), hero.state != .arrived,
           let dep = hero.leg.schedDep?.ms, dep - now < 24 * 3_600_000,
           let detail = try? await client.leg(hero.leg.id) {
            let route = detail.mapRoute().route
            if route.count > 1, untouched {
                controller.fit(route, padding: UIEdgeInsets(top: 140, left: 60, bottom: 200, right: 60))
                return
            }
        }
        if LocationModel.shared.allowed, untouched { controller.centreOnUser() }
    }

    /// Nothing opened on the map yet: a train, a station, a search.
    private var untouched: Bool { selected == nil && scheduled == nil && stationSheet == nil && !searching }

    /// The theme the map is drawn in (colours of markers and routes).
    var dark = true

    // Data behind the map.
    @ObservationIgnored private var trains: [String: LiveTrain] = [:]
    @ObservationIgnored private var glides: [String: ExploreLogic.Glide] = [:]
    /// The track between two stops, by "from>to"; nil once asked and not found. Fetched when a train first runs on it.
    @ObservationIgnored private var segments: [String: ExploreLogic.TrackPath?] = [:]
    @ObservationIgnored private var segmentsAsked: Set<String> = []
    @ObservationIgnored private var renderTask: Task<Void, Never>?
    @ObservationIgnored private var needsFullRender = true
    @ObservationIgnored private var route: (id: String, line: [LatLon], from: Int)?
    @ObservationIgnored private var stopsTask: Task<Void, Never>?
    @ObservationIgnored private var scheduledTask: Task<Void, Never>?
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var focused = false
    /// Counts every pick and every close. A pick that is still waiting for the server when the sheet is closed (or another
    /// train picked) finds its number changed and drops what it fetched, so it can't open the sheet again or draw a route
    /// that nothing owns.
    @ObservationIgnored private var selection = 0

    func attach(_ app: AppModel) {
        self.app = app
        controller.onReady = { [weak self] in
            self?.ready = true
            self?.needsFullRender = true
            self?.scheduleRender()
            Task { await self?.openWhereItMatters() }
        }
        // A new map (the theme changed): not ready until its style loads, so the stream starts again once it is.
        controller.onRebuild = { [weak self] in
            self?.ready = false
            // The new map starts flat: the tilt rule decides again from there.
            self?.tilted = false
        }
        controller.onViewChange = { [weak self] bbox, zoom in
            self?.bbox = bbox
            self?.zoom = zoom
            self?.viewChangedForDetail()
        }
        // Dragging the map lets go of a followed train.
        controller.onUserGesture = { [weak self] in self?.followingSelected = false }
        controller.onTapTrain = { [weak self] id in
            self?.searching = false
            Task { await self?.select(id) }
        }
        controller.onTapDisruption = { [weak self] id in
            self?.searching = false
            self?.openDisruption(id: id)
        }
        controller.onTapStation = { [weak self] id, name in
            guard let self else { return }
            self.searching = false
            self.stationSheet = StationSheetTarget(id: id, name: name)
        }
    }

    private var followKeys: Set<String> { Set(follows.map { ExploreLogic.followKey(number: $0.trainNumber, date: $0.serviceDate) }) }

    var filteredCount: Int { filters.count }

    private func color(_ operatorId: String?) -> String {
        MapStyle.opColor(operatorId.flatMap { app?.operatorsById[$0]?.brandColor }, dark: dark)
    }

    /// The latest from the stream, not the copy from when it was tapped.
    var selectedTrain: LiveTrain? { selected.map { trains[$0.train.id] ?? $0.train } }

    /// How many trains of each kind and each operator are in view (the filter sheet's counts).
    var countsInView: (products: [String: Int], operators: [String: Int]) {
        _ = trainsVersion
        var products: [String: Int] = [:], operators: [String: Int] = [:]
        for t in trains.values where controller.contains(t.lat, t.lon) {
            if let p = t.product { products[p, default: 0] += 1 }
            if let o = t.operatorId { operators[o, default: 0] += 1 }
        }
        return (products, operators)
    }

    /// The colour mode changed: every dot is drawn again.
    func colorByChanged() { scheduleRender() }

    /// The operators with a train in view, A to Z by name (owner, 2026-10-27).
    var operatorsShown: [String] {
        _ = trainsVersion
        let inView = trains.values.filter { controller.contains($0.lat, $0.lon) }
        let ids = Set(inView.compactMap(\.operatorId)).union(filters.operators)
        let name = { (id: String) in self.app?.operatorsById[id]?.name ?? id }
        return ids.sorted { name($0).localizedCaseInsensitiveCompare(name($1)) == .orderedAscending }
    }

    func trainHits() -> [LiveTrain] { ExploreLogic.trainHits(Array(trains.values), query: query) }

    func liveTrain(number: String, date: String) -> LiveTrain? { trains.values.first { $0.number == number && $0.date == date } }

    func isFollowed(number: String, date: String) -> Bool { followKeys.contains(ExploreLogic.followKey(number: number, date: date)) }

    // MARK: the stream

    /// Subscribes to the trains in view; re-subscribes (debounced 400 ms) when you pan or zoom.
    func runStream(bbox: String) async {
        // Panning waits 400 ms for the map to settle; the first picture doesn't wait at all.
        if loaded { try? await Task.sleep(for: .milliseconds(400)) }
        guard !Task.isCancelled, let client = app?.client else { return }
        while !Task.isCancelled {
            // The server sends something every two seconds (the data's age too), so a stream that goes quiet has
            // stalled without failing: the watchdog cancels it and the loop connects again.
            lastEvent = now
            let consumer = Task { try await consume(client.liveTrainStream(bbox: bbox)) }
            let watchdog = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(5))
                    guard let self else { return }
                    if self.now - self.lastEvent > Self.silenceMs { consumer.cancel(); return }
                }
            }
            do {
                try await withTaskCancellationHandler { try await consumer.value } onCancel: { consumer.cancel() }
            } catch {
                // Down until it comes back.
            }
            watchdog.cancel()
            if Task.isCancelled { return }
            streamDown = true
            try? await Task.sleep(for: .seconds(5))
        }
    }

    /// The quiet after which a stream is taken for stalled.
    nonisolated static let silenceMs = 15_000.0
    private var lastEvent = 0.0

    private func consume(_ stream: AsyncThrowingStream<SSEEvent, Error>) async throws {
        for try await event in stream {
            lastEvent = now
            streamDown = false
            if event.name == "snapshot", let snapshot = await EventStream.decode(LiveSnapshot.self, from: event) {
                loaded = true
                lastMessage = now
                mode = snapshot.mode
                apply(snapshot.trains, removed: [], replace: true)
                total = snapshot.total
                upstreamAt = snapshot.upstreamAt
            } else if event.name == "delta", let delta = await EventStream.decode(LiveDelta.self, from: event) {
                lastMessage = now
                // A moved train only changed position: lay that over what we already have.
                let moved = (delta.moved ?? []).compactMap { m in trains[m.id].map { ExploreLogic.applying(m, to: $0) } }
                apply(delta.changed + moved, removed: delta.removed, replace: false)
                total = delta.total
                upstreamAt = delta.upstreamAt
                if let m = delta.mode { mode = m }
            }
        }
    }

    private var now: Double { Date().timeIntervalSince1970 * 1000 }

    private func apply(_ list: [LiveTrain], removed: [String], replace: Bool) {
        let start = CACurrentMediaTime() * 1000
        if replace {
            let keep = Set(list.map(\.id))
            for id in trains.keys where !keep.contains(id) { trains[id] = nil }
        }
        for id in removed { trains[id] = nil }
        // Only trains on screen, close enough in to see them move, glide; the rest jump.
        let close = controller.zoom >= 7
        for train in list {
            if let old = trains[train.id], close, old.lat != train.lat || old.lon != train.lon, controller.contains(train.lat, train.lon) {
                // Where it is drawn now, so a train that is mid-glide does not jump back.
                let shown = glides[train.id].map { $0.step(now: start).position } ?? LatLon(old.lat, old.lon)
                glides[train.id] = ExploreLogic.makeGlide(track: track(of: train), from: shown, to: LatLon(train.lat, train.lon), standing: train.isStanding, speedKmh: train.speedKmh, start: start)
            } else {
                glides[train.id] = nil
            }
            trains[train.id] = train
        }
        if let r = route, list.contains(where: { $0.id == r.id }), let train = trains[r.id] { drawSplit(train) }
        trainsVersion += 1
        // Zoomed out (every train a small dot, no detail to see), the map is redrawn at most every 10 s instead of with
        // each 2-second update; a snapshot, or zooming in, draws at once.
        if !close && !replace {
            let wait = 10_000 - (start - lastFarRender)
            if wait > 0 {
                if farRender == nil {
                    farRender = Task { [weak self] in
                        try? await Task.sleep(for: .milliseconds(Int(wait)))
                        guard let self, !Task.isCancelled else { return }
                        self.farRender = nil
                        self.lastFarRender = CACurrentMediaTime() * 1000
                        self.scheduleRender()
                    }
                }
                return
            }
            lastFarRender = start
        }
        scheduleRender()
    }

    /// The track a running train is on, once fetched; asks for it the first time and answers nil until it is there.
    private func track(of train: LiveTrain) -> ExploreLogic.TrackPath? {
        guard !train.isStanding, let from = train.prevId, let to = train.nextId, let client = app?.client else { return nil }
        let key = "\(from)>\(to)"
        if let known = segments[key] { return known }
        if segmentsAsked.insert(key).inserted {
            Task { [weak self] in
                let segment = try? await client.liveSegment(from: from, to: to)
                let points = segment.map { Polyline.decode($0.polyline) } ?? []
                self?.segments[key] = .some(points.count >= 2 ? ExploreLogic.TrackPath(points: points) : nil)
            }
        }
        return nil
    }

    /// When the zoomed-out map was last redrawn, and the redraw waiting for its turn.
    private var lastFarRender: Double = 0
    private var farRender: Task<Void, Never>?

    // MARK: drawing the trains

    func scheduleRender() {
        // Whatever asked for a render changed the trains, the filters or the follows: the next frame is a full one.
        needsFullRender = true
        guard renderTask == nil, active else { return }
        renderTask = Task { [weak self] in
            // Stops when the map is hidden (`active` off) as well as when nothing is gliding any more.
            while let self, !Task.isCancelled, self.active {
                let moving = self.needsFullRender || self.zoom >= Self.carsZoom ? self.render() : self.glideFrame()
                if !moving { break }
                // Smoother only while a train eases to its new fix; carrying on at its speed until the next
                // one, 10 a second is enough, and always so in Low Power Mode (review E4).
                let nowMs = CACurrentMediaTime() * 1000
                // 20 a second while easing (was 30: the map idled at ~17 % CPU zoomed in, run 2), and at the cars'
                // zoom, where every frame redraws the whole picture, 10 a second throughout.
                let easing = self.glides.values.contains { nowMs - $0.start < ExploreLogic.glideMs }
                let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
                let smooth = easing && !lowPower && self.zoom < Self.carsZoom
                try? await Task.sleep(for: .milliseconds(smooth ? 50 : 100))
            }
            self?.renderTask = nil
        }
    }

    /// A frame of a glide with nothing else changed: only the moving trains get new coordinates (no new colours,
    /// labels or points for the ones standing still). Returns whether anything is still gliding.
    private func glideFrame() -> Bool {
        let nowMs = CACurrentMediaTime() * 1000
        var positions: [String: LatLon] = [:]
        for (id, g) in glides {
            let step = g.step(now: nowMs)
            positions[id] = step.position
            if step.done { glides[id] = nil }
        }
        controller.moveTrains(positions)
        return !glides.isEmpty
    }

    /// Pushes every train, at the position it is drawn at now, into the map. Returns whether anything is still gliding.
    private func render() -> Bool {
        needsFullRender = false
        let nowMs = CACurrentMediaTime() * 1000
        let followed = followKeys
        var moving = false
        var points: [TrainPoint] = []
        var cars: [[String: Any]] = []
        let close = zoom >= Self.carsZoom
        for train in trains.values where ExploreLogic.visible(train, filters, followed: followed) {
            var position = LatLon(train.lat, train.lon)
            var bearing = train.bearing
            if let g = glides[train.id] {
                let step = g.step(now: nowMs)
                position = step.position
                if let b = step.bearing { bearing = b }
                if step.done { glides[train.id] = nil } else { moving = true }
            }
            // Your own train where your phone is on its track (RiderReporter; nothing leaves the phone for this).
            if train.mine, let here = RiderReporter.shared.position(of: train) {
                position = here.position
                bearing = here.bearing
            }
            if close, controller.contains(position.lat, position.lon) {
                cars += carFeatures(train, at: position, bearing: bearing, color: ExploreLogic.color(of: train, by: colorBy) ?? color(train.operatorId))
            }
            points.append(TrainPoint(
                id: train.id, number: train.number, label: train.destination.map { "\(train.number) · \($0)" } ?? train.number, dest: train.destination,
                color: ExploreLogic.color(of: train, by: colorBy) ?? color(train.operatorId), mine: train.mine, followed: followed.contains(ExploreLogic.followKey(number: train.number, date: train.date)),
                bearing: bearing, lat: position.lat, lon: position.lon
            ))
        }
        controller.setTrains(points)
        controller.setTrainCars(["type": "FeatureCollection", "features": cars])
        // The selected train: an outline round its cars, and the camera on it while it is followed (owner,
        // 2026-10-30: "it should lock onto it ... it seems to just drive out of frame").
        let selectedId = selected?.train.id
        let halo: [[String: Any]] = cars.compactMap { f in
            guard let props = f["properties"] as? [String: Any], props["id"] as? String == selectedId,
                  let coords = (f["geometry"] as? [String: Any])?["coordinates"] as? [[Double]], coords.count == 2 else { return nil }
            return ["type": "Feature", "properties": [String: Any](), "geometry": ["type": "Polygon", "coordinates": [LiveMapController.carFootprint(back: coords[0], front: coords[1], widthM: 6)]]]
        }
        controller.setSelectedCars(halo)
        if followingSelected, let id = selectedId, let p = points.first(where: { $0.id == id }) {
            controller.keepInView(CLLocationCoordinate2D(latitude: p.lat, longitude: p.lon))
        }
        if shown != points.count { shown = points.count }
        return moving
    }

    // MARK: station detail at close zoom (plan 2026-10-29, step 2)

    /// From this zoom the view asks for every track and the platforms; from `carsZoom` trains are their cars.
    static let detailZoom = 13.0
    static let carsZoom = 14.0
    @ObservationIgnored private var detailTask: Task<Void, Never>?
    @ObservationIgnored private var detailCache: [String: (json: [String: Any], tracks: [StationDetailLogic.Track])] = [:]
    @ObservationIgnored private var detailTracks: [StationDetailLogic.Track] = []
    @ObservationIgnored private var detailShownKey: String?
    @ObservationIgnored private var detailShownJSON: [String: Any]?

    /// The view moved: at close zoom fetch the detail for it (debounced, cached by the rounded box); below, clear.
    private func viewChangedForDetail() {
        detailTask?.cancel()
        updateTilt()
        guard zoom >= Self.detailZoom, let bbox else {
            if detailShownKey != nil {
                detailHasStructures = false
                if laserCredit3D != nil { laserCredit3D = nil }
                updateTilt()
                detailShownKey = nil
                detailShownJSON = nil
                detailTracks = []
                controller.clearStationDetail()
                controller.setTrainCars(["type": "FeatureCollection", "features": [Any]()])
            }
            return
        }
        let parts = bbox.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 4 else { return }
        // Tilted, a box round the centre (the visible one reaches the horizon; ExploreLogic.detailBox).
        let centre = controller.centre.map { (lat: $0.latitude, lon: $0.longitude) } ?? (lat: (parts[1] + parts[3]) / 2, lon: (parts[0] + parts[2]) / 2)
        let box = ExploreLogic.detailBox(visible: (parts[0], parts[1], parts[2], parts[3]), centre: centre, tilted: tilted)
        // A little wider than the screen, rounded to about 100 m, so a nudge doesn't ask again.
        let r = { (v: Double) in (v / 0.001).rounded() * 0.001 }
        let w = r(box.w - 0.002), s = r(box.s - 0.001), e = r(box.e + 0.002), n = r(box.n + 0.001)
        guard e - w <= 0.06, n - s <= 0.03 else { return }
        let key = String(format: "%.3f,%.3f,%.3f,%.3f", w, s, e, n)
        if key == detailShownKey { return }
        if let hit = detailCache[key] { return show(hit.json, tracks: hit.tracks, key: key) }
        detailTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            var comps = URLComponents(url: Config.apiBase.appendingPathComponent("api/map/station-detail"), resolvingAgainstBaseURL: false)
            comps?.queryItems = [URLQueryItem(name: "bbox", value: key)]
            guard let url = comps?.url else { return }
            let answer = try? await URLSession.shared.data(from: url)
            guard let (data, _) = answer, !Task.isCancelled, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // No answer for this place: nothing measured is known here, so the map doesn't stay tilted on the
                // strength of the last station.
                if !Task.isCancelled, self.detailHasStructures {
                    self.detailHasStructures = false
                    self.updateTilt()
                }
                return
            }
            let tracks = Self.tracks(in: json)
            self.detailCache[key] = (json, tracks)
            // Over 40: drop another one (a dictionary has no order, so not "the oldest", but never the one just added).
            if self.detailCache.count > 40, let old = self.detailCache.keys.first(where: { $0 != key }) {
                self.detailCache.removeValue(forKey: old)
            }
            self.show(json, tracks: tracks, key: key)
        }
    }

    private func show(_ json: [String: Any], tracks: [StationDetailLogic.Track], key: String) {
        detailShownKey = key
        detailShownJSON = json
        detailTracks = tracks
        let structures = ((json["features"] as? [[String: Any]]) ?? []).compactMap { $0["properties"] as? [String: Any] }.filter { $0["kind"] as? String == "structure" }
        detailHasStructures = !structures.isEmpty
        // The laser the heights on screen come from (older servers only say whether it is Lantmäteriet's).
        let credit = structures.compactMap { ($0["credit"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? ($0["lantmateriet"] as? Bool == true ? "lantmateriet" : nil) }.first
        if laserCredit3D != credit { laserCredit3D = credit }
        controller.setStationDetail(json)
        updateTilt()
        needsFullRender = true
        scheduleRender()
    }

    /// Close in on a station with measured structures, the map tilts into 3D (owner, 2026-10-30: "when a user zooms in
    /// close enough to the station, it switches into the 3d view"); out again, or away from it, it flattens. In at
    /// `model3DZoom`, out a whole zoom below, so it doesn't flip at the edge.
    static let model3DZoom = ExploreLogic.tiltInZoom
    static let tiltDegrees = ExploreLogic.tiltDegrees
    @ObservationIgnored private var detailHasStructures = false
    /// The camera stays on the selected train until the map is dragged.
    @ObservationIgnored private var followingSelected = false
    @ObservationIgnored private var tilted = false
    /// Whose laser data the heights on screen come from: the attribution line credits it.
    private(set) var laserCredit3D: String?

    private func updateTilt() {
        let want = ExploreLogic.wantTilt(zoom: zoom, tilted: tilted, hasStructures: detailHasStructures)
        if want != tilted {
            tilted = want
            controller.setTilt(want ? Self.tiltDegrees : 0)
        } else if ExploreLogic.pitchNeedsFix(pitch: controller.pitch, tilted: tilted) {
            // A gesture cut the last tilt or flatten short: ask again (polish pass 1).
            controller.setTilt(tilted ? Self.tiltDegrees : 0)
        }
    }

    /// The track lines of a detail answer, for laying trains on.
    nonisolated static func tracks(in json: [String: Any]) -> [StationDetailLogic.Track] {
        guard let features = json["features"] as? [[String: Any]] else { return [] }
        return features.compactMap { f in
            guard let props = f["properties"] as? [String: Any], props["kind"] as? String == "track",
                  let geometry = f["geometry"] as? [String: Any], let coords = geometry["coordinates"] as? [[Double]] else { return nil }
            let pts = coords.compactMap { c in c.count >= 2 ? LatLon(c[1], c[0]) : nil }
            return pts.count >= 2 ? StationDetailLogic.Track(points: pts, service: (props["service"] as? Bool ?? false) || (props["minor"] as? Bool ?? false)) : nil
        }
    }

    /// A train as its cars (TrainKit: the feed's count, else the type's, else the design's default) along the
    /// nearest detail track; one line feature per car.
    private func carFeatures(_ train: LiveTrain, at p: LatLon, bearing: Double?, color: String) -> [[String: Any]] {
        let type = train.trainType.flatMap { id in app?.trainTypes.first { $0.id == id } }
        let template = TrainKit.template(forArt: type?.art)
        let count = TrainKit.carCount(live: train.cars, typical: type?.cars, template: template).count
        let cars = StationDetailLogic.cars(at: p, bearing: bearing, count: count, carLength: TrainKit.carLength(template), tracks: detailTracks)
        return cars.map { car in
            [
                "type": "Feature",
                "properties": ["id": train.id, "color": color, "front": car.isFront, "h": StationScene3D.carSize(template).height],
                "geometry": ["type": "LineString", "coordinates": [[car.back.lon, car.back.lat], [car.front.lon, car.front.lat]]],
            ]
        }
    }

    // MARK: follows

    func loadFollows() async {
        if let list = try? await app?.client.follows() { follows = list }
    }

    /// The follows again, and the map drawn with them (a ring on a train that is no longer followed must go).
    func refreshFollows() async {
        await loadFollows()
        scheduleRender()
    }

    func toggleFollow(number: String, date: String, operatorId: String?, label: String?) async {
        Usage.shared.count(.feature, "explore.follow")
        guard let client = app?.client else { return }
        do {
            if isFollowed(number: number, date: date) {
                try await client.unfollow(number: number, date: date)
            } else {
                try await client.follow(FollowBody(trainNumber: number, serviceDate: date, operatorId: operatorId, label: label))
            }
            follows = try await client.follows()
            followsConfirmed += 1
            scheduleRender()
        } catch {
            // Unchanged, and said (it used to look like a dead tap).
            failure = Failure(key: "liveMap.followFailed")
        }
    }

    // MARK: search

    /// The text in the field changed. Typing opens the search; the text being cleared (by a pick, or the field's
    /// clear) doesn't, or picking a result would open the list again over what it opened.
    func queryChanged() {
        if !query.trimmingCharacters(in: .whitespaces).isEmpty { startSearch() }
        searchChanged()
    }

    /// The search panel opens; the filters close, as the two share the space under the field, and so does the legend,
    /// which would stand in the panel's lower part.
    func startSearch() {
        searching = true
        showFilters = false
        legend = false
    }

    /// The search is done with (a result picked): the panel closes and the text and its station hits go.
    func endSearch() {
        searching = false
        query = ""
        searchTask?.cancel()
        stationHits = []
    }

    /// A station search is out (the list says "Searching…" rather than "nothing matches" meanwhile).
    private(set) var stationSearchPending = false
    /// The last station search didn't get an answer (said as such, not as no match).
    private(set) var stationSearchFailed = false

    func searchChanged() {
        searchTask?.cancel()
        stationSearchFailed = false
        // Composed form: "ö" typed as o + a combining mark (some keyboards, pasted text) must match the station's name.
        let text = query.trimmingCharacters(in: .whitespaces).precomposedStringWithCanonicalMapping
        guard ExploreLogic.searchesStations(text) else {
            stationHits = []
            stationSearchPending = false
            return
        }
        // Offline is known: say so at once rather than wait for a request to fail (designer, 2026-11-07).
        if app?.isOffline == true {
            stationHits = []
            stationSearchPending = false
            stationSearchFailed = true
            return
        }
        stationSearchPending = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self, let client = self.app?.client else { return }
            // Asked twice: a dropped request on the first try is not "no match" (user test 2026-11-07: "Uppsala",
            // which the planner knew, got "Inget matchar" here).
            var hits: [StationHit]?
            for _ in 0..<2 {
                hits = try? await client.searchStations(text)
                if hits != nil || Task.isCancelled { break }
            }
            guard !Task.isCancelled else { return }
            if let hits { self.stationHits = Array(hits.prefix(5)) } else { self.stationSearchFailed = true }
            self.stationSearchPending = false
        }
    }

    func openStation(_ hit: StationHit) async {
        endSearch()
        deselect()
        // Close in on it (owner, 2026-10-30): a mapped station to its 3D (the tilt follows at that zoom), others to
        // its tracks, in the space above the station's sheet.
        var name = hit.name
        if let info = await app?.stations.info(hit.id) {
            controller.ease(to: CLLocationCoordinate2D(latitude: info.lat, longitude: info.lon), minZoom: info.hasMap ? Self.model3DZoom + 0.5 : 15, offset: min(260, controller.height * 0.29), topClearance: 72)
            if name.isEmpty { name = info.name }
        }
        stationSheet = StationSheetTarget(id: hit.id, name: name)
    }

    // MARK: selecting a train

    /// Asks for the network status now and every 30 s while the panel is open.
    func watchNetwork() async {
        guard let client = app?.client else { return }
        while showNetwork && !Task.isCancelled {
            #if DEBUG
            if CommandLine.arguments.contains("-networkSample") { return }
            #endif
            if let answer = try? await client.networkStatus() {
                network = answer
                networkFailed = false
                if showNetwork { controller.setDisruptions(answer.disruptions) }
                // The open one kept fresh (the last copy stays when it has dropped out); one asked for opens now.
                if let open = disruption, let fresh = answer.disruptions?.first(where: { $0.id == open.id }) {
                    disruption = fresh
                    controller.setSelectedDisruption(fresh)
                }
                if let id = wantedDisruption, let d = answer.disruptions?.first(where: { $0.id == id }) {
                    wantedDisruption = nil
                    openDisruption(d)
                }
            } else if network == nil {
                networkFailed = true
            }
            // Asked again soon while the map is still filling (no trains counted yet), else every 30 s.
            let filling = network?.countries.isEmpty ?? true
            try? await Task.sleep(for: .seconds(filling ? 4 : 30))
        }
    }

    #if DEBUG
    /// The sample's Skåne corridor, with straight stretches between the stations' real positions (the track itself
    /// comes from the server) and two late trains, to look at the corridor sheet.
    private var sampleCorridor: NetworkStatus.Corridor {
        let signal = NetworkStatus.Cause(src: "trv", code: nil, text: "Signalfel", trains: 5)
        let points = NetworkStatus.Cause(src: "trv", code: nil, text: "Växelfel", trains: 1)
        var c = NetworkStatus.Corridor(stations: ["Hässleholm C", "Lund C", "Malmö C"], country: "SE", trains: 7, late: 6, medianDelay: 18, maxDelay: 34, lat: 55.8, lon: 13.4, causes: [signal, points], trainIds: [])
        let h = LatLon(56.1585, 13.7636), l = LatLon(55.7068, 13.1870), m = LatLon(55.6090, 12.9999)
        c.stretches = [
            .init(a: "Hässleholm C", b: "Lund C", aId: "740000008", bId: "740000006", polyline: Polyline.encode([h, LatLon(55.93, 13.55), l])),
            .init(a: "Lund C", b: "Malmö C", aId: "740000006", bId: "740000003", polyline: Polyline.encode([l, m])),
        ]
        c.lateTrains = [
            .init(id: "s1", number: "1084", operatorId: "oresundstag", delayMin: 34, next: "Lund C", destination: "Helsingør", causes: [.init(src: "trv", code: nil, text: "Signalfel")]),
            .init(id: "s2", number: "533", operatorId: "sj", delayMin: 18, next: "Malmö C", destination: "Malmö C", causes: []),
        ]
        return c
    }

    /// Made-up numbers in the server's shape, to look at the panel on a calm day. Never in a release build.
    func useSampleNetwork() {
        network = NetworkStatus(
            at: Date().timeIntervalSince1970 * 1000, lateMin: 10,
            countries: ["SE": .init(trains: 341, known: 336, late: 41), "NO": .init(trains: 118, known: 106, late: 9), "DK": .init(trains: 170, known: 170, late: 12), "FI": .init(trains: 104, known: 104, late: 4)],
            corridors: [sampleCorridor, .init(stations: ["Oslo S", "Lillestrøm"], country: "NO", trains: 3, late: 2, medianDelay: 12, maxDelay: 15, lat: 59.95, lon: 10.95, causes: [], trainIds: [])],
            late: [
                .init(id: "x1", number: "547", operatorId: "sj", delayMin: 42, prev: "Norrköping C", next: "Linköping C", destination: "Malmö C", causes: [.init(src: "trv", code: nil, text: "Olycka")]),
                .init(id: "x2", number: "1072", operatorId: "oresundstag", delayMin: 16, prev: "Kastrup", next: "København H", destination: "Helsingør", causes: []),
            ]
        )
        networkFailed = false
    }
    #endif

    /// A corridor was tapped: its track is drawn in orange, its late trains ringed, the map fits them, and its sheet
    /// opens (closing a train's or a station's).
    func showCorridor(_ c: NetworkStatus.Corridor) {
        showNetwork = false
        deselect()
        stationSheet = nil
        notRunning = nil
        corridor = c
        corridorGone = false
        controller.setCorridor(lines: c.lines, trainIds: c.trainIds)
        let points = c.lines.flatMap { $0 } + c.trainIds.compactMap { trains[$0] }.map { LatLon($0.lat, $0.lon) }
        if points.count >= 2 {
            controller.fit(points, padding: UIEdgeInsets(top: 140, left: 60, bottom: 320, right: 60))
        } else {
            controller.ease(to: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon), minZoom: 9, offset: 0)
        }
    }

    /// Something shows in Explore's one system sheet: a train, a station, a corridor, Network now.
    var panelOpen: Bool {
        selected != nil || notRunning != nil || scheduled != nil || corridor != nil || stationSheet != nil || showNetwork
    }

    /// The sheet was swiped away: everything in it closes.
    func closePanels() {
        if selected != nil { deselect() }
        if scheduled != nil { closeScheduled() }
        if corridor != nil { closeCorridor() }
        notRunning = nil
        stationSheet = nil
        showNetwork = false
        sheetTop = nil
    }

    /// A disruption opened: Network now underneath (so back returns to it), its sheet on top, its track lit and the
    /// map gone to it.
    func openDisruption(_ d: NetworkStatus.Disruption) {
        deselect()
        stationSheet = nil
        notRunning = nil
        if corridor != nil { closeCorridor() }
        showNetwork = true
        disruption = d
        controller.setSelectedDisruption(d)
        focus(d)
    }

    /// By id: from the map, or from a trip page (opening Network now and waiting for it when it isn't loaded yet).
    func openDisruption(id: String) {
        if let d = network?.disruptions?.first(where: { $0.id == id }) {
            openDisruption(d)
        } else {
            wantedDisruption = id
            showNetwork = true
        }
    }

    /// The station sheet closes for a screen it opened over the map, remembered to come back.
    func stepAside(for station: StationSheetTarget) {
        stationToRestore = station
        stationSheet = nil
    }

    /// Back to Network now's list.
    func closeDisruption() {
        guard disruption != nil || wantedDisruption != nil else { return }
        disruption = nil
        wantedDisruption = nil
        controller.setSelectedDisruption(nil)
    }

    /// The map goes to a disruption (its track, or its pin), in the space above the sheet.
    func focus(_ d: NetworkStatus.Disruption) {
        let points = d.tracks.flatMap { $0 }
        if points.count >= 2 {
            controller.fit(points, padding: UIEdgeInsets(top: 140, left: 60, bottom: min(420, controller.height * 0.5), right: 60))
        } else {
            controller.ease(to: CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon), minZoom: 10, offset: 0)
        }
    }

    func closeCorridor() {
        corridor = nil
        corridorGone = false
        controller.clearCorridor()
    }

    /// Keeps the open corridor fresh: the network status again every 30 s, the same stretch (by its stations) read
    /// from it; when the stretch has dropped out, the sheet says so and keeps the last figures.
    func watchCorridor() async {
        guard let client = app?.client else { return }
        while corridor != nil && !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard let open = corridor, !Task.isCancelled else { return }
            guard let answer = try? await client.networkStatus() else { continue }
            network = answer
            if let fresh = answer.corridors.first(where: { $0.id == open.id }) {
                corridor = fresh
                corridorGone = false
                controller.setCorridor(lines: fresh.lines, trainIds: fresh.trainIds)
            } else {
                corridorGone = true
                controller.setCorridor(lines: open.lines, trainIds: [])
            }
        }
    }

    func select(_ id: String) async {
        guard let client = app?.client else { return }
        selection += 1
        let mine = selection
        // The ring shows at once, so the tap is seen before the details arrive.
        controller.setSelected(id)
        // A tap that doesn't answer is worse than a slow one: one more try before giving up.
        var fetched = try? await client.liveTrain(id)
        if fetched == nil {
            try? await Task.sleep(for: .milliseconds(400))
            fetched = try? await client.liveTrain(id)
        }
        guard mine == selection else { return }
        guard let detail = fetched else {
            // The ring goes back to what is really selected (nothing, or the train that still is), and the tap is
            // answered in words (polish pass 1: it just went away, a dead tap).
            controller.setSelected(selected?.train.id)
            failure = Failure(key: "liveMap.trainFailed")
            return
        }
        selected = detail
        followingSelected = true
        scheduled = nil
        stops = detail.trip == nil ? .none : .loading
        stationSheet = nil
        controller.setSelected(id)
        // Up into the free space above the train's sheet (between the search bar and the sheet's top), so the train and
        // its route aren't under either.
        controller.ease(to: CLLocationCoordinate2D(latitude: detail.train.lat, longitude: detail.train.lon), minZoom: 8, offset: min(260, controller.height * 0.29))
        clearRoute()
        guard let trip = detail.trip else { return }
        startStops(id)
        // The train's whole route along the tracks: travelled part solid, the rest dashed (DESIGN §2.4).
        guard let geometry = try? await client.timetableTripGeometry(trip.key, date: trip.serviceDate), mine == selection, selected?.train.id == id else { return }
        let line = Self.line(geometry)
        guard line.count > 1 else { return }
        controller.setRouteColor(color(detail.train.operatorId))
        route = (id, line, 0)
        drawSplit(trains[id] ?? detail.train)
    }

    private static func line(_ geometry: TripGeometry) -> [LatLon] {
        geometry.segments.enumerated().flatMap { i, segment -> [LatLon] in
            let points = Polyline.decode(segment.polyline)
            return i == 0 ? points : Array(points.dropFirst())
        }
    }

    /// Solid up to where the selected train is now, dashed from there to the end.
    private func drawSplit(_ train: LiveTrain) {
        guard let r = route else { return }
        let cut = ExploreLogic.split(r.line, at: LatLon(train.lat, train.lon), from: r.from)
        route = (r.id, r.line, cut.next)
        controller.setRoute(done: cut.done, ahead: cut.ahead)
    }

    private func clearRoute() {
        route = nil
        controller.clearRoute()
    }

    /// The selected train's stops, kept fresh while its sheet is open.
    private func startStops(_ id: String) {
        stopsTask?.cancel()
        stopsTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let client = self.app?.client else { return }
                var soon = false
                do {
                    self.stops = .list(try await client.liveTrainStops(id))
                } catch let error as APIError where error.status == 503 {
                    // Rejseplanen knows the train but couldn't answer just now: still loading, ask again in 5 s.
                    if case .list = self.stops {} else { self.stops = .loading }
                    soon = true
                } catch {
                    if case .list = self.stops {} else { self.stops = .none }
                }
                try? await Task.sleep(for: .seconds(soon ? 5 : 30))
            }
        }
    }

    func deselect() {
        selection += 1
        selected = nil
        followingSelected = false
        stopsTask?.cancel()
        clearRoute()
        controller.setSelected(nil)
        controller.setSelectedCars([])
        controller.clearInset()
    }

    // MARK: a train with no position

    /// A train with no position: its timetable route drawn as "ahead", its stops with whatever live data exists.
    func openScheduled(number: String, date: String, key: String?) async {
        guard let client = app?.client else { return }
        let view: TrainView
        do {
            view = try await client.train(number: number, date: date, key: key)
        } catch let error as APIError where error.status == 404 {
            // Only the server saying so means the train isn't running.
            notRunning = NotRunningTarget(number: number, date: date)
            return
        } catch {
            // Not reached is said as such, not as "this train isn't running" (polish pass 1).
            failure = Failure(key: "liveMap.trainFailed")
            return
        }
        if let live = view.live, trains[live.id] != nil {
            await select(live.id)
            return
        }
        selection += 1
        scheduled = view
        selected = nil
        // The ring and the stops of the train that was selected go with it.
        stopsTask?.cancel()
        controller.setSelected(nil)
        stationSheet = nil
        startScheduledRefresh(number: number, date: date, key: key)
        clearRoute()
        guard let trip = view.trip else { return }
        let geometry = try? await client.timetableTripGeometry(trip.key, date: trip.serviceDate)
        let line = geometry.map(Self.line) ?? []
        guard line.count > 1, scheduled?.number == number else { return }
        controller.setRouteColor(color(view.operatorId))
        controller.setRoute(done: [], ahead: line)
        controller.fit(line, padding: UIEdgeInsets(top: 90, left: 40, bottom: min(420, controller.height * 0.5), right: 40))
    }

    private func startScheduledRefresh(number: String, date: String, key: String?) {
        scheduledTask?.cancel()
        scheduledTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, let client = self.app?.client else { return }
                if let v = try? await client.train(number: number, date: date, key: key), self.scheduled?.number == v.number { self.scheduled = v }
            }
        }
    }

    func closeScheduled() {
        selection += 1
        scheduled = nil
        scheduledTask?.cancel()
        clearRoute()
    }

    // MARK: opened from elsewhere

    /// Opened from a board row or a followed train: select it once it's on the map; if the first full picture of the map
    /// doesn't have it, show it from the timetable (done once).
    func focus(_ target: Router.PendingTrain) async {
        guard !focused else { return }
        focused = true
        defer { focused = false }
        let started = Date()
        while !Task.isCancelled {
            if ready, let train = trains.values.first(where: { $0.number == target.number && $0.date == target.date }) {
                await select(train.id)
                return
            }
            // Without a first full picture of the map (live data down), stop waiting after 4 s.
            if ready, loaded || Date().timeIntervalSince(started) > 4 {
                await openScheduled(number: target.number, date: target.date, key: target.key)
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
        }
    }

    func stop() {
        stopsTask?.cancel()
        scheduledTask?.cancel()
        searchTask?.cancel()
        renderTask?.cancel()
        renderTask = nil
    }
}
