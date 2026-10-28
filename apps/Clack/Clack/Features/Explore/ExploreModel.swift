//
//  ExploreModel.swift
//  Clack
//

import ClackCore
import Foundation
import MapLibre
import Observation
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
    private(set) var selected: LiveTrainDetail?
    private(set) var stops: StopsState = .loading
    private(set) var scheduled: TrainView?
    var notRunning: NotRunningTarget?
    var stationSheet: StationSheetTarget?
    var collapsed = false
    var legend = false
    var showFilters = false
    /// The network status panel (the button beside the filters), its answer, and whether asking failed.
    var showNetwork = false
    private(set) var network: NetworkStatus?
    private(set) var networkFailed = false
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
            }
        }
    }

    /// Your dot is on the map by default once iOS allows it; asked the first time the map is up (Settings > Clack >
    /// Location only appears once iOS has been asked).
    func showMyDot() {
        LocationModel.shared.askIfNeeded()
        controller.showUserDot()
    }

    /// The locate button: centre on you. Where location is switched off, it opens Settings, where you can switch it on.
    func centreOnMe() {
        Usage.shared.count(.feature, "explore.myLocation")
        let location = LocationModel.shared
        location.askIfNeeded()
        if location.denied, let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            return
        }
        controller.centreOnUser()
    }

    /// The theme the map is drawn in (colours of markers and routes).
    var dark = true

    // Data behind the map.
    @ObservationIgnored private var trains: [String: LiveTrain] = [:]
    @ObservationIgnored private var glides: [String: (from: LatLon, to: LatLon, start: Double)] = [:]
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
        }
        // A new map (the theme changed): not ready until its style loads, so the stream starts again once it is.
        controller.onRebuild = { [weak self] in self?.ready = false }
        controller.onViewChange = { [weak self] bbox, zoom in
            self?.bbox = bbox
            self?.zoom = zoom
        }
        controller.onTapTrain = { [weak self] id in
            self?.searching = false
            Task { await self?.select(id) }
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
                glides[train.id] = (LatLon(old.lat, old.lon), LatLon(train.lat, train.lon), start)
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
                let moving = self.needsFullRender ? self.render() : self.glideFrame()
                if !moving { break }
                try? await Task.sleep(for: .milliseconds(33))
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
            let step = ExploreLogic.glide(from: g.from, to: g.to, startedAt: g.start, now: nowMs)
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
        for train in trains.values where ExploreLogic.visible(train, filters, followed: followed) {
            var position = LatLon(train.lat, train.lon)
            if let g = glides[train.id] {
                let step = ExploreLogic.glide(from: g.from, to: g.to, startedAt: g.start, now: nowMs)
                position = step.position
                if step.done { glides[train.id] = nil } else { moving = true }
            }
            points.append(TrainPoint(
                id: train.id, number: train.number, label: train.destination.map { "\(train.number) · \($0)" } ?? train.number, dest: train.destination,
                color: color(train.operatorId), mine: train.mine, followed: followed.contains(ExploreLogic.followKey(number: train.number, date: train.date)),
                bearing: train.bearing, lat: position.lat, lon: position.lon
            ))
        }
        controller.setTrains(points)
        if shown != points.count { shown = points.count }
        return moving
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
            scheduleRender()
        } catch {
            // Unchanged; the button shows the real state.
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

    func searchChanged() {
        searchTask?.cancel()
        let text = query.trimmingCharacters(in: .whitespaces)
        guard ExploreLogic.searchesStations(text) else { stationHits = []; return }
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self, let client = self.app?.client else { return }
            if let hits = try? await client.searchStations(text) { self.stationHits = Array(hits.prefix(5)) }
        }
    }

    func openStation(_ hit: StationHit) async {
        endSearch()
        deselect()
        if let info = await app?.stations.info(hit.id) {
            controller.ease(to: CLLocationCoordinate2D(latitude: info.lat, longitude: info.lon), minZoom: 10, offset: 0)
        }
        stationSheet = StationSheetTarget(id: hit.id, name: hit.name)
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
            } else if network == nil {
                networkFailed = true
            }
            // Asked again soon while the map is still filling (no trains counted yet), else every 30 s.
            let filling = network?.countries.isEmpty ?? true
            try? await Task.sleep(for: .seconds(filling ? 4 : 30))
        }
    }

    #if DEBUG
    /// Made-up numbers in the server's shape, to look at the panel on a calm day. Never in a release build.
    func useSampleNetwork() {
        let signal = NetworkStatus.Cause(src: "trv", code: nil, text: "Signalfel", trains: 5)
        let points = NetworkStatus.Cause(src: "trv", code: nil, text: "Växelfel", trains: 1)
        network = NetworkStatus(
            at: Date().timeIntervalSince1970 * 1000, lateMin: 10,
            countries: ["SE": .init(trains: 341, known: 336, late: 41), "NO": .init(trains: 118, known: 106, late: 9), "DK": .init(trains: 170, known: 170, late: 12), "FI": .init(trains: 104, known: 104, late: 4)],
            corridors: [
                .init(stations: ["Hässleholm C", "Lund C", "Malmö C"], country: "SE", trains: 7, late: 6, medianDelay: 18, maxDelay: 34, lat: 55.8, lon: 13.4, causes: [signal, points], trainIds: []),
                .init(stations: ["Oslo S", "Lillestrøm"], country: "NO", trains: 3, late: 2, medianDelay: 12, maxDelay: 15, lat: 59.95, lon: 10.95, causes: [], trainIds: []),
            ],
            late: [
                .init(id: "x1", number: "547", operatorId: "sj", delayMin: 42, prev: "Norrköping C", next: "Linköping C", destination: "Malmö C", causes: [.init(src: "trv", code: nil, text: "Olycka")]),
                .init(id: "x2", number: "1072", operatorId: "oresundstag", delayMin: 16, prev: "Kastrup", next: "København H", destination: "Helsingør", causes: []),
            ]
        )
        networkFailed = false
    }
    #endif

    /// A corridor was tapped: the map fits its late trains (where they are now).
    func showCorridor(_ c: NetworkStatus.Corridor) {
        showNetwork = false
        let points = c.trainIds.compactMap { trains[$0] }.map { LatLon($0.lat, $0.lon) }
        if points.count >= 2 {
            controller.fit(points, padding: UIEdgeInsets(top: 140, left: 60, bottom: 200, right: 60))
        } else {
            controller.ease(to: CLLocationCoordinate2D(latitude: c.lat, longitude: c.lon), minZoom: 9, offset: 0)
        }
    }

    func select(_ id: String) async {
        guard let client = app?.client else { return }
        selection += 1
        let mine = selection
        // The ring shows at once, so the tap is seen before the details arrive.
        controller.setSelected(id)
        UISelectionFeedbackGenerator().selectionChanged()
        // A tap that doesn't answer is worse than a slow one: one more try before giving up.
        var fetched = try? await client.liveTrain(id)
        if fetched == nil {
            try? await Task.sleep(for: .milliseconds(400))
            fetched = try? await client.liveTrain(id)
        }
        guard mine == selection else { return }
        guard let detail = fetched else {
            // The ring goes back to what is really selected (nothing, or the train that still is).
            controller.setSelected(selected?.train.id)
            return
        }
        selected = detail
        scheduled = nil
        collapsed = false
        stops = detail.trip == nil ? .none : .loading
        stationSheet = nil
        controller.setSelected(id)
        // Up into the free space above the train's sheet, so the train and its route aren't under it.
        controller.ease(to: CLLocationCoordinate2D(latitude: detail.train.lat, longitude: detail.train.lon), minZoom: 8, offset: min(320, controller.height * 0.34))
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
                if let list = try? await client.liveTrainStops(id) {
                    self.stops = .list(list)
                } else if case .list = self.stops {
                    // Keep what we have.
                } else {
                    self.stops = .none
                }
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    func deselect() {
        selection += 1
        selected = nil
        stopsTask?.cancel()
        clearRoute()
        controller.setSelected(nil)
    }

    // MARK: a train with no position

    /// A train with no position: its timetable route drawn as "ahead", its stops with whatever live data exists.
    func openScheduled(number: String, date: String, key: String?) async {
        guard let client = app?.client else { return }
        guard let view = try? await client.train(number: number, date: date, key: key) else {
            notRunning = NotRunningTarget(number: number, date: date)
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
        collapsed = false
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
