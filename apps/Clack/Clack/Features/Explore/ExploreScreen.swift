//
//  ExploreScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The Explore tab: a calm radar of every train running in Sweden, Norway and Finland; tap a train or station for details,
/// follow trains, plan a trip from one (pages/LiveMapPage.tsx).
struct ExploreScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var scheme
    @State private var model = ExploreModel()
    @State private var basemap: Bool?
    @State private var now = Date().timeIntervalSince1970 * 1000
    @FocusState private var searchFocused: Bool
    /// Settings → Map engine (BUILDOUT O3): the Clack map, or Apple Maps as a test.
    @AppStorage(MapEngine.key) private var mapEngine = MapEngine.clack.rawValue
    @State private var frameStats: (median: Double, p90: Double, trains: Int)?

    /// This tab is the one showing (the screen stays built while another is).
    private var active: Bool { router.tab == .explore }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            top
            if model.searching {
                if model.query.trimmingCharacters(in: .whitespaces).isEmpty { stations } else { results }
            }
            if model.showNetwork {
                NetworkPanel(
                    status: model.network, failed: model.networkFailed,
                    onCorridor: { model.showCorridor($0) },
                    onTrain: { t in
                        model.showNetwork = false
                        Task { await model.select(t.id) }
                    },
                    onClose: { model.showNetwork = false }
                )
                .task { await model.watchNetwork() }
            }
            bottomLeft
            // A station's or train's sheet waits under an open search (it comes back on Close); a pick replaces it.
            if !model.searching { sheets }
        }
        .clipped()
        // The map runs edge to edge, under the status bar and the glass tab bar; the controls stay in the safe area.
        .background {
            ZStack {
                Ink.mapBg
                if mapEngine == MapEngine.apple.rawValue {
                    AppleLiveMapView(controller: model.controller, base: Config.apiBase, dark: scheme == .dark)
                        .id("apple-\(scheme == .dark)")
                } else if let basemap {
                    LiveMapView(controller: model.controller, base: Config.apiBase, withBasemap: basemap, dark: scheme == .dark)
                        // Re-created when the theme changes: the basemap and every layer take their colours from it.
                        .id("\(scheme == .dark)-\(basemap)")
                }
            }
            .ignoresSafeArea()
        }
        .environment(model)
        // Filters and map settings in a sheet (owner, 2026-10-28): the map stays in view above it.
        .sheet(isPresented: Binding(get: { model.showFilters }, set: { model.showFilters = $0 })) {
            ExploreFilterSheet { model.showFilters = false }
                .environment(model)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .task {
            model.attach(app)
            model.controller.onFrameStats = { median, p90, trains in frameStats = (median, p90, trains) }
            model.active = active
            model.dark = scheme == .dark
            basemap = await app.mapHasBasemap()
            await model.loadFollows()
        }
        .onChange(of: scheme) { model.dark = scheme == .dark }
        // The stream follows what's in view. While another tab is showing it is closed (after the first full picture has
        // arrived), and it opens again, with a fresh snapshot, when you come back.
        .task(id: "\(model.ready)|\(model.bbox ?? "")|\(active || !model.loaded)") {
            guard model.ready, let bbox = model.bbox, active || !model.loaded else { return }
            await model.runStream(bbox: bbox)
        }
        .onChange(of: active) {
            model.active = active
            // Back on the tab without a basemap (the first ask failed): ask again.
            if active, basemap != true { Task { basemap = await app.mapHasBasemap() } }
            // Follows change elsewhere (a followed journey stopped on Trips): the rings follow the real list.
            if active { Task { await model.refreshFollows() } }
        }
        .task(id: app.followed.journeys.map(\.token)) { await model.refreshFollows() }
        // Your dot, from the moment the map is up (and again when the map is made again for the other theme).
        .task(id: model.ready) { if model.ready { model.showMyDot() } }
        // "Stations" from elsewhere (old links): the search, open, with your stations under it.
        .task(id: router.stationSearchRequest) {
            guard router.stationSearchRequest != nil else { return }
            router.stationSearchRequest = nil
            model.deselect()
            model.stationSheet = nil
            model.query = ""
            model.startSearch()
            searchFocused = true
        }
        // A train opened from a board row, a follow or a link.
        .task(id: router.pendingTrain) {
            guard let target = router.pendingTrain else { return }
            router.pendingTrain = nil
            model.searching = false
            // Not awaited here: clearing the request restarts this task, which would cancel the wait.
            Task { await model.focus(target) }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                now = Date().timeIntervalSince1970 * 1000
            }
        }
        .sensoryFeedback(.selection, trigger: model.follows.count)
        #if DEBUG
        .task { await debugSearch() }
        // `-exploreNetwork` opens the network status; with `-networkSample`, filled with made-up data (a preview of a bad
        // day); `-exploreCorridor` goes on to the first corridor's sheet and highlight.
        .task {
            let args = CommandLine.arguments
            guard args.contains("-exploreNetwork") else { return }
            try? await Task.sleep(for: .seconds(3))
            if args.contains("-networkSample") { model.useSampleNetwork() }
            model.showNetwork = true
            if args.contains("-exploreCorridor") {
                try? await Task.sleep(for: .seconds(2))
                if let c = model.network?.corridors.first { model.showCorridor(c) }
            }
        }
        #endif
        // Full-bleed: the map runs under where the bar would be; its own buttons float over it.
        .toolbar(.hidden, for: .navigationBar)
    }

    #if DEBUG
    /// Launch arguments for checking the search without tapping: `-exploreFilters` opens the filters, `-exploreSearch <text>` types it (an empty string
    /// opens the station list), `-exploreFocus` puts the caret in the field, and `-explorePick station|train` then
    /// picks the first station or train found, as a tap on the result does.
    private func debugSearch() async {
        let args = CommandLine.arguments
        if args.contains("-exploreFilters") {
            try? await Task.sleep(for: .seconds(3))
            model.showFilters = true
        }
        guard let at = args.firstIndex(of: "-exploreSearch") else { return }
        let text = args.indices.contains(at + 1) ? args[at + 1] : ""
        try? await Task.sleep(for: .seconds(3))
        model.startSearch()
        model.query = text
        if args.contains("-exploreFocus") { searchFocused = true }
        guard let pick = args.firstIndex(of: "-explorePick").flatMap({ args.indices.contains($0 + 1) ? args[$0 + 1] : nil }) else { return }
        try? await Task.sleep(for: .seconds(4))
        if pick == "station", let hit = model.stationHits.first {
            model.searching = false
            await model.openStation(hit)
        } else if pick == "train", let train = model.trainHits().first {
            model.endSearch()
            await model.select(train.id)
        }
    }
    #endif

    // MARK: top bar

    private var top: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            SearchField(text: $model.query, prompt: l10n.t("liveMap.searchPlaceholder"), overMap: true, focus: $searchFocused)
                .onChange(of: model.query) { model.queryChanged() }
                .onChange(of: searchFocused) {
                    if searchFocused {
                        model.showNetwork = false
                        model.startSearch()
                    }
                }
                // However the search closes (a pick, Close, a tap on the map), the keyboard goes with it.
                .onChange(of: model.searching) { if !model.searching { searchFocused = false } }
            Button {
                // The filters and the search share the space under the field: one at a time.
                if !model.showFilters { model.searching = false }
                model.showNetwork = false
                model.showFilters.toggle()
            } label: {
                // The same glass circle as the map's buttons (yellow while filters are on).
                MapButtonFace(icon: "sliders-horizontal", pressed: model.filteredCount > 0)
                    .overlay(alignment: .topTrailing) {
                        if model.filteredCount > 0 {
                            Text("\(model.filteredCount)").clack(.micro).fontWeight(.heavy).foregroundStyle(Ink.bg)
                                .frame(minWidth: 18, minHeight: 18).padding(.horizontal, 2)
                                .background(Ink.text, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.t("liveMap.filters"))
            .accessibilityAddTraits(model.showFilters ? .isSelected : [])
            // Network status, beside the filters (owner, 2026-10-28); the search field gives up the room.
            Button {
                if !model.showNetwork { model.searching = false }
                model.showFilters = false
                model.showNetwork.toggle()
            } label: {
                MapButtonFace(icon: "activity", pressed: model.showNetwork)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.t("network.button"))
            .accessibilityAddTraits(model.showNetwork ? .isSelected : [])
        }
        .padding(.horizontal, 12).padding(.top, 12)
    }

    // MARK: search results

    private var results: some View {
        let q = model.query.trimmingCharacters(in: .whitespaces)
        let trainHits = model.trainHits()
        return SearchPanel(maxHeight: 420) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(trainHits) { train in
                    let op = train.operatorId.flatMap { app.operatorsById[$0] }
                    resultRow {
                        OperatorBadge(op: op, size: .small)
                    } title: {
                        [train.productName ?? op?.name, train.number].compactMap { $0 }.joined(separator: " ")
                    } caption: {
                        [train.origin, train.destination].compactMap { $0 }.joined(separator: " → ")
                    } action: {
                        model.endSearch()
                        Task { await model.select(train.id) }
                    }
                }
                ForEach(model.stationHits) { hit in
                    resultRow {
                        RoundedRectangle(cornerRadius: Radius.bar).fill(Ink.bg).overlay(RoundedRectangle(cornerRadius: Radius.bar).strokeBorder(Ink.text, lineWidth: 1.6)).frame(width: 9, height: 9)
                    } title: {
                        hit.name
                    } caption: {
                        l10n.t("liveMap.station")
                    } action: {
                        model.searching = false
                        Task { await model.openStation(hit) }
                    }
                }
                if trainHits.isEmpty && model.stationHits.isEmpty {
                    Text(q.allSatisfy(\.isNumber) ? l10n.t("liveMap.noTrainMatch", ["q": q]) : l10n.t("liveMap.noMatch", ["q": q]))
                        .clack(.caption).foregroundStyle(Ink.text2).padding(.vertical, 8)
                }
                Button(l10n.t("common.close")) { model.searching = false }.buttonStyle(LinkButtonStyle()).padding(.top, 8)
            }
        }
    }

    /// The search with nothing typed: your favourite and recent stations and the big ones (what the Stations screen on
    /// Trips used to list). A station opens its sheet on the map, with its departures.
    private var stations: some View {
        StationDirectoryList { hit in
            model.searching = false
            Task { await model.openStation(hit) }
        } onClose: {
            model.searching = false
        }
    }

    private func resultRow<Lead: View>(@ViewBuilder lead: () -> Lead, title: () -> String, caption: () -> String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                lead().frame(width: 26)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title()).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
                    Text(caption()).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    // MARK: status and legend

    private var bottomLeft: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            // While typing, the keyboard lifts the tab bar and this corner into the search panel: they wait below it.
            if !searchFocused {
                if model.legend { legendCard }
                HStack(spacing: 8) {
                    statusChip
                    MapButton(icon: "info", label: l10n.t("liveMap.legend"), pressed: model.legend) { model.legend.toggle() }
                    // Your position: iOS asks the first time; then your dot, and the map goes to it.
                    MapButton(icon: "locate-fixed", label: l10n.t("liveMap.myLocation")) { model.centreOnMe() }
                }
            }
            if mapEngine == MapEngine.apple.rawValue {
                // The test engine's readout: how long frames take (Garner judges smoothness with ~700 trains on his phone).
                if let f = frameStats {
                    Text(l10n.t("liveMap.appleTest", ["ms": String(format: "%.1f", f.median), "p90": String(format: "%.1f", f.p90), "n": String(f.trains)]))
                        .clack(.micro).monospacedDigit().foregroundStyle(Ink.text2).allowsHitTesting(false)
                        .padding(.vertical, 4).padding(.horizontal, 8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                }
                Text("Trafikverket · Entur (NLOD) · Digitraffic (Fintraffic) · Rejseplanen")
                    .clack(.mapAttribution).foregroundStyle(Ink.text3).allowsHitTesting(false).padding(.bottom, 20)
            } else {
                Text("© OpenStreetMap contributors · Protomaps · Trafikverket · Entur (NLOD) · Digitraffic (Fintraffic) · Rejseplanen")
                    .clack(.mapAttribution).foregroundStyle(Ink.text3).allowsHitTesting(false)
            }
        }
        .padding(.leading, 12).padding(.bottom, 8)
    }

    /// Map states (brief §6.3): loading, live data down, delayed data, nothing in view, or trains running.
    private var statusChip: some View {
        let status = ExploreLogic.status(
            loaded: model.loaded, streamDown: model.streamDown, lastMessageAt: model.lastMessage, mode: model.mode, upstreamAt: model.upstreamAt,
            shown: model.shown, total: model.total, zoom: model.zoom, filtered: model.filteredCount > 0, now: now
        )
        return Group {
            switch status {
            case .loading: StatusLine(.arrived, l10n.t("liveMap.loading"))
            case .unavailable: StatusLine(.stale, l10n.t("liveMap.unavailable"))
            case .delayed(let at): StatusLine(.stale, l10n.t("liveMap.delayedData", ["ago": LiveRules.ago(l10n, then: at, now: now)]))
            case .none(let filtered): StatusLine(.arrived, l10n.t(filtered ? "liveMap.noneMatch" : "liveMap.noneHere"))
            case .running(let total, let simulated):
                StatusLine(simulated ? .estimated : .live, l10n.t(simulated ? "liveMap.simulated" : "liveMap.trainsRunning", count: total, ["count": String(total)]))
            }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
        .hairlineBorder(radius: Radius.controlSm)
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            legendRow(l10n.t("liveMap.legendTrain")) { Circle().fill(Ink.text2).overlay(Circle().strokeBorder(Ink.markerRing, lineWidth: 1)).frame(width: 10, height: 10) }
            legendRow(l10n.t("liveMap.legendStation")) {
                RoundedRectangle(cornerRadius: Radius.bar).fill(Ink.bg).overlay(RoundedRectangle(cornerRadius: Radius.bar).strokeBorder(Ink.text, lineWidth: 1.6)).frame(width: 9, height: 9)
            }
            legendRow(l10n.t("liveMap.legendDone")) { RoundedRectangle(cornerRadius: Radius.bar).fill(Ink.accent).frame(width: 22, height: 4) }
            legendRow(l10n.t("liveMap.legendAhead")) {
                Rectangle().stroke(Ink.accent, style: StrokeStyle(lineWidth: 4, dash: [4, 3])).frame(width: 22, height: 4)
            }
            InfoNote(l10n.t("liveMap.legendNote"), more: l10n.t("liveMap.legendNoteMore"))
        }
        .clack(.caption).foregroundStyle(Ink.text2)
        .padding(.vertical, 16).padding(.horizontal, 16)
        .frame(maxWidth: 280, alignment: .leading)
        .background(Ink.glass).background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    private func legendRow<Mark: View>(_ text: String, @ViewBuilder mark: () -> Mark) -> some View {
        HStack(spacing: 8) {
            mark().frame(width: 22)
            Text(text)
        }
    }

    // MARK: sheets (one at a time; a selected train hides the others)

    @ViewBuilder
    private var sheets: some View {
        @Bindable var model = model
        if let train = model.selectedTrain, let detail = model.selected {
            liveTrainSheet(train, detail: detail, collapsed: $model.collapsed)
        } else if let notRunning = model.notRunning {
            NotRunningSheet(
                follow: model.follows.first { $0.trainNumber == notRunning.number && (notRunning.date == nil || $0.serviceDate == notRunning.date) },
                number: notRunning.number,
                onUnfollow: { follow in
                    Task {
                        await model.toggleFollow(number: follow.trainNumber, date: follow.serviceDate, operatorId: follow.operatorId, label: follow.label)
                        model.notRunning = nil
                    }
                },
                onClose: { model.notRunning = nil }
            )
        } else if let view = model.scheduled {
            scheduledSheet(view, collapsed: $model.collapsed)
        } else if let corridor = model.corridor {
            CorridorSheet(corridor: corridor, gone: model.corridorGone, updatedAt: model.network?.at, onClose: { model.closeCorridor() }) { id in
                model.closeCorridor()
                Task { await model.select(id) }
            }
            .task(id: corridor.id) { await model.watchCorridor() }
        } else if let station = model.stationSheet {
            LiveStationSheet(
                id: station.id, name: station.name, onClose: { model.stationSheet = nil },
                onTrain: { row in
                    model.stationSheet = nil
                    let date = row.trip?.serviceDate ?? Format.localDate(Date().timeIntervalSince1970 * 1000, tz: Format.zone(stationId: station.id))
                    if let train = model.liveTrain(number: row.trainNumber, date: date) {
                        Task { await model.select(train.id) }
                    } else {
                        Task { await model.openScheduled(number: row.trainNumber, date: date, key: row.trip?.key) }
                    }
                },
                onBoard: { router.push(.board(stationId: station.id, arrivals: false)) },
                onArrivals: { router.push(.board(stationId: station.id, arrivals: true)) },
                onMap: { router.push(.stationMap(StationMapLink(stationId: station.id))) }
            )
        }
    }

    private func liveTrainSheet(_ train: LiveTrain, detail: LiveTrainDetail, collapsed: Binding<Bool>) -> some View {
        let op = train.operatorId.flatMap { app.operatorsById[$0] }
        let type = train.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        let title = (train.productName != nil || op != nil) ? [train.productName ?? op?.name, train.number].compactMap { $0 }.joined(separator: " ") : l10n.t("liveMap.train", ["number": train.number])
        let followed = model.isFollowed(number: train.number, date: train.date)
        let position = ExploreLogic.position(of: train, now: now)
        return TrainSheet(op: op, title: title, collapsed: collapsed, onClose: { model.deselect() }) {
            if !collapsed.wrappedValue { art(type: type, operatorId: train.operatorId) }
            if train.origin != nil || train.destination != nil {
                Text("\(train.origin ?? "…") → \(train.destination ?? "…")").clack(.rowTitle).foregroundStyle(Ink.text)
            }
            if train.origin == nil && train.destination == nil && train.next == nil {
                Text(l10n.t("liveMap.detailsLoading")).clack(.caption).foregroundStyle(Ink.text2)
            }
            if let next = train.next {
                HStack(spacing: 8) {
                    Text(l10n.t("live.nextStopName", ["name": next])).clack(.body).foregroundStyle(Ink.text)
                    FlapTime(time: train.nextEta?.ms, tz: Format.zone(country: train.operatorId.flatMap { app.operatorsById[$0]?.country }), clock: app.settings.clock, style: .text)
                }
            }
            FlowLayout(spacing: 12, lineSpacing: 8) {
                if let delay = train.delayMin { DelayText(delay: delay) }
                switch position {
                case .estimated: StatusLine(.estimated, l10n.t("liveMap.posEstimated"))
                case .old(let minutes): StatusLine(.stale, l10n.t("liveMap.posOld", ["min": String(minutes)]))
                case .gps: StatusLine(.live, l10n.t("liveMap.posGps"))
                }
                if !collapsed.wrappedValue, !train.estimated { Speedometer(kmh: train.speedKmh, at: train.at.ms, now: now) }
            }
            Text(l10n.t("live.updated", ["ago": LiveRules.ago(l10n, then: train.at.ms, now: now)])).clack(.caption).foregroundStyle(Ink.text2)
            if case .list(let list) = model.stops { LateReasons(stops: list) }
        } content: {
            StopList(stops: model.stops, color: operatorColor(op?.brandColor, scheme: scheme), now: now)
            OnboardView(facts: nil, operatorId: train.operatorId, trainType: train.trainType, compact: true)
            if detail.trip == nil { Text(l10n.t("board.notInTimetable")).clack(.caption).foregroundStyle(Ink.text2) }
        } actions: {
            HStack(spacing: 12) {
                followButton(following: followed) {
                    Task {
                        await model.toggleFollow(
                            number: train.number, date: train.date, operatorId: train.operatorId,
                            label: train.origin != nil && train.destination != nil ? "\(train.origin!) → \(train.destination!)" : nil
                        )
                    }
                }
                planButton(legId: detail.legId, trip: detail.trip)
            }
            Button { router.push(.ride(.live(id: train.id))) } label: {
                HStack(spacing: 8) {
                    LucideIcon(name: "train-track", size: 16)
                    Text(l10n.t("ride.open"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.clack(wide: true))
        }
    }

    private func scheduledSheet(_ view: TrainView, collapsed: Binding<Bool>) -> some View {
        let op = view.operatorId.flatMap { app.operatorsById[$0] }
        let type = view.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        let stops = view.stops ?? []
        let first = stops.first
        let last = stops.last
        let anyLive = stops.contains { $0.actualArr != nil || $0.actualDep != nil || $0.estimatedArr != nil || $0.estimatedDep != nil }
        let allCanceled = !stops.isEmpty && stops.allSatisfy(\.canceled)
        let departs = first.map { $0.actualDep ?? $0.estimatedDep ?? $0.dep } ?? nil
        let status: String
        if allCanceled { status = l10n.t("train.statusCanceled") }
        else if last?.passed == true { status = l10n.t("train.statusArrived") }
        else if let departs, departs > now { status = l10n.t("train.statusDeparts", ["time": Format.time(departs, tz: Format.zone(stationId: first?.stationId), clock: app.settings.clock)]) }
        else { status = l10n.t("train.statusNoPosition") }
        let followed = model.isFollowed(number: view.number, date: view.date)
        return TrainSheet(op: op, title: [view.productName ?? op?.name, view.number].compactMap { $0 }.joined(separator: " "), collapsed: collapsed, onClose: { model.closeScheduled() }) {
            if !collapsed.wrappedValue { art(type: type, operatorId: view.operatorId) }
            if let first, let last { Text("\(first.name) → \(last.name)").clack(.rowTitle).foregroundStyle(Ink.text) }
            StatusLine(allCanceled ? .cancelled : .arrived, status)
            // Live times need no note; timetable ones say so.
            if !anyLive { Text(l10n.t("train.timetableOnly")).clack(.caption).foregroundStyle(Ink.text2) }
            LateReasons(stops: view.stops ?? [])
        } content: {
            StopList(stops: view.stops.map { .list($0) } ?? .none, color: operatorColor(op?.brandColor, scheme: scheme), now: now)
            OnboardView(facts: nil, operatorId: view.operatorId, trainType: view.trainType, compact: true)
        } actions: {
            HStack(spacing: 12) {
                followButton(following: followed) {
                    Task {
                        await model.toggleFollow(number: view.number, date: view.date, operatorId: view.operatorId, label: first.flatMap { f in last.map { "\(f.name) → \($0.name)" } })
                    }
                }
                planButton(legId: view.legId, trip: view.trip)
            }
        }
    }

    /// The train's picture and name, or that its type isn't known.
    private func art(type: TrainType?, operatorId: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            TrainPicture(type: type, operatorId: operatorId, height: 54)
            Text(type?.name ?? l10n.t("liveMap.typeUnknown")).clack(.caption).foregroundStyle(Ink.text2)
        }
    }

    /// Two separate things (brief §6.2): watching a train, and planning to travel on it.
    private func followButton(following: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                LucideIcon(name: following ? "check" : "eye", size: 16)
                Text(l10n.t(following ? "liveMap.following" : "liveMap.follow"))
            }
        }
        // As wide as its word, so the button beside it keeps the room (Plan a journey in one line).
        .buttonStyle(.clack())
        .fixedSize()
        .accessibilityAddTraits(following ? .isSelected : [])
    }

    @ViewBuilder
    private func planButton(legId: String?, trip: TrainTrip?) -> some View {
        if let legId {
            Button { router.push(.trip(legId)) } label: {
                HStack(spacing: 8) {
                    LucideIcon(name: "train-front", size: 16)
                    Text(l10n.t("liveMap.inYourTrips")).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .buttonStyle(.clack(.primary, wide: true))
        } else {
            Button {
                if let trip { router.openAdd(AddTrainLink(tripKey: trip.key, date: trip.serviceDate)) }
            } label: {
                HStack(spacing: 8) {
                    LucideIcon(name: "plus", size: 16)
                    Text(l10n.t("liveMap.plan")).lineLimit(1).minimumScaleFactor(0.85)
                }
            }
            .buttonStyle(.clack(.primary, wide: true))
                .disabled(trip == nil)
        }
    }
}
