//
//  ExploreScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The Explore tab: a calm radar of every train running in Sweden and Norway; tap a train or station for details,
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

    /// This tab is the one showing (the screen stays built while another is).
    private var active: Bool { router.tab == .explore }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Ink.mapBg
            if let basemap {
                LiveMapView(controller: model.controller, base: Config.apiBase, withBasemap: basemap, dark: scheme == .dark)
                    // Re-created when the theme changes: the basemap and every layer take their colours from it.
                    .id("\(scheme == .dark)-\(basemap)")
            }
            top
            if model.searching && !model.query.trimmingCharacters(in: .whitespaces).isEmpty { results }
            if model.showFilters { filters }
            bottomLeft
            sheets
        }
        .clipped()
        .environment(model)
        .task {
            model.attach(app)
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
        .onChange(of: active) { model.active = active }
        // A train opened from a board row, a follow or a link.
        .task(id: router.pendingTrain) {
            guard let target = router.pendingTrain else { return }
            router.pendingTrain = nil
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
    }

    // MARK: top bar

    private var top: some View {
        @Bindable var model = model
        return HStack(spacing: 8) {
            HStack(spacing: 8) {
                LucideIcon(name: "search", size: 16).foregroundStyle(Ink.text2)
                TextField("", text: $model.query, prompt: Text(l10n.t("liveMap.searchPlaceholder")).foregroundStyle(Ink.text3))
                    .focused($searchFocused)
                    .font(ClackFont.inter(16)).foregroundStyle(Ink.text).tint(Ink.accentLine)
                    .textInputAutocapitalization(.never).autocorrectionDisabled().submitLabel(.search)
                    .accessibilityLabel(l10n.t("liveMap.search"))
                    .onChange(of: model.query) {
                        model.searching = true
                        model.searchChanged()
                    }
                    .onChange(of: searchFocused) { if searchFocused { model.searching = true } }
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .hairlineBorder(radius: Radius.input)
            Button { model.showFilters.toggle() } label: {
                LucideIcon(name: "sliders-horizontal", size: 18)
                    .foregroundStyle(model.filteredCount > 0 ? Ink.onAccent : Ink.text)
                    .frame(width: 40, height: 40)
                    .background(model.filteredCount > 0 ? Ink.accent : Ink.glass, in: Circle())
                    .overlay(Circle().strokeBorder(model.filteredCount > 0 ? Ink.accent : Ink.hairline, lineWidth: 1))
                    .overlay(alignment: .topTrailing) {
                        if model.filteredCount > 0 {
                            Text("\(model.filteredCount)").font(ClackFont.inter(11, .heavy)).foregroundStyle(Ink.bg)
                                .frame(minWidth: 18, minHeight: 18).padding(.horizontal, 2)
                                .background(Ink.text, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                .offset(x: 4, y: -4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.t("liveMap.filters"))
            .accessibilityAddTraits(model.showFilters ? .isSelected : [])
        }
        .padding(.horizontal, 12).padding(.top, 12)
    }

    // MARK: search results

    private var results: some View {
        let q = model.query.trimmingCharacters(in: .whitespaces)
        let trainHits = model.trainHits()
        return ScrollView {
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
                        model.searching = false
                        model.query = ""
                        searchFocused = false
                        Task { await model.select(train.id) }
                    }
                }
                ForEach(model.stationHits) { hit in
                    resultRow {
                        RoundedRectangle(cornerRadius: 2).fill(Ink.bg).overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Ink.text, lineWidth: 1.6)).frame(width: 9, height: 9)
                    } title: {
                        hit.name
                    } caption: {
                        l10n.t("liveMap.station")
                    } action: {
                        searchFocused = false
                        Task { await model.openStation(hit) }
                    }
                }
                if trainHits.isEmpty && model.stationHits.isEmpty {
                    Text(q.allSatisfy(\.isNumber) ? l10n.t("liveMap.noTrainMatch", ["q": q]) : l10n.t("liveMap.noMatch", ["q": q]))
                        .clack(.caption).foregroundStyle(Ink.text2).padding(.vertical, 8)
                }
                Button(l10n.t("common.close")) { model.searching = false; searchFocused = false }.buttonStyle(LinkButtonStyle()).padding(.top, 6)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: 460).fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: 420)
        .background(Surface.Lit(op: Ink.accent))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, 12).padding(.top, 64)
    }

    private func resultRow<Lead: View>(@ViewBuilder lead: () -> Lead, title: () -> String, caption: () -> String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
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

    // MARK: filters

    /// The card hugs its content up to 440 pt, then scrolls inside that height, so nothing lies outside what's drawn
    /// (a clipped overflow still takes taps and covered the filter button).
    private var filters: some View {
        ViewThatFits(in: .vertical) {
            filtersContent
            ScrollView { filtersContent }.scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxWidth: 460)
        .frame(maxHeight: 440)
        .background(Surface.Lit(op: Ink.accent))
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, 16).padding(.top, 64)
    }

    private var filtersContent: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 8) {
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(ExploreLogic.products, id: \.self) { p in
                        ChipButton(text: l10n.t("products.\(p)"), active: model.filters.products.contains(p)) { toggle(&model.filters.products, p) }
                    }
                }
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ChipButton(text: l10n.t("liveMap.onlyDelayed"), active: model.filters.onlyDelayed) { model.filters.onlyDelayed.toggle() }
                    ChipButton(text: l10n.t("liveMap.onlyMine"), active: model.filters.onlyMine) { model.filters.onlyMine.toggle() }
                    ChipButton(text: l10n.t("liveMap.onlyFollowed"), active: model.filters.onlyFollowed) { model.filters.onlyFollowed.toggle() }
                }
                Text(l10n.t("liveMap.operators").uppercased()).clack(.captionUpper).foregroundStyle(Ink.text2).padding(.top, 4)
                ForEach(model.operatorsShown, id: \.self) { id in
                    let on = model.filters.operators.contains(id)
                    Button { toggle(&model.filters.operators, id) } label: {
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous).fill(on ? Ink.accent : Ink.surfaceRaised)
                                .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).strokeBorder(on ? Ink.accent : Ink.hairline, lineWidth: 1))
                                .overlay { if on { LucideIcon(name: "check", size: 14).foregroundStyle(Ink.onAccent) } }
                                .frame(width: 22, height: 22)
                            OperatorBadge(op: app.operatorsById[id], size: .small)
                            Text(app.operatorsById[id]?.name ?? id).font(ClackFont.inter(16)).foregroundStyle(Ink.text)
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 40).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(on ? .isSelected : [])
                }
                HStack(spacing: 8) {
                    if model.filteredCount > 0 { ChipButton(text: l10n.t("liveMap.clearFilters")) { model.filters = .init() } }
                    ChipButton(text: l10n.t("common.done")) { model.showFilters = false }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func toggle(_ set: inout Set<String>, _ value: String) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    // MARK: status and legend

    private var bottomLeft: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()
            if model.legend { legendCard }
            HStack(spacing: 8) {
                statusChip
                MapButton(icon: "info", label: l10n.t("liveMap.legend"), pressed: model.legend) { model.legend.toggle() }
            }
            Text("© OpenStreetMap contributors · Protomaps · Trafikverket · Entur (NLOD)")
                .clack(.mapAttribution).foregroundStyle(Ink.text3).allowsHitTesting(false)
        }
        .padding(.leading, 12).padding(.bottom, 6)
    }

    /// Map states (brief §6.3): loading, live data down, delayed data, nothing in view, or trains running.
    private var statusChip: some View {
        let status = ExploreLogic.status(
            loaded: model.loaded, streamDown: model.streamDown, lastMessageAt: model.lastMessage, mode: model.mode, upstreamAt: model.upstreamAt,
            shown: model.shown, total: model.total, zoom: model.zoom, filtered: model.filteredCount > 0, now: now
        )
        return Group {
            switch status {
            case .loading: Chip(text: l10n.t("liveMap.loading"))
            case .unavailable: Chip(text: l10n.t("liveMap.unavailable"), tint: Ink.text3)
            case .delayed(let at): Chip(text: l10n.t("liveMap.delayedData", ["ago": LiveRules.ago(l10n, then: at, now: now)]), tint: Ink.text3)
            case .none(let filtered): Chip(text: l10n.t(filtered ? "liveMap.noneMatch" : "liveMap.noneHere"))
            case .running(let total, let simulated):
                Chip(text: l10n.t(simulated ? "liveMap.simulated" : "liveMap.trainsRunning", count: total, ["count": String(total)]), accent: true)
            }
        }
        .padding(.vertical, 6).padding(.horizontal, 10)
        .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
        .hairlineBorder(radius: Radius.controlSm)
    }

    private var legendCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            legendRow(l10n.t("liveMap.legendTrain")) { Circle().fill(Ink.text2).overlay(Circle().strokeBorder(Ink.markerRing, lineWidth: 1)).frame(width: 10, height: 10) }
            legendRow(l10n.t("liveMap.legendStation")) {
                RoundedRectangle(cornerRadius: 2).fill(Ink.bg).overlay(RoundedRectangle(cornerRadius: 2).strokeBorder(Ink.text, lineWidth: 1.6)).frame(width: 9, height: 9)
            }
            legendRow(l10n.t("liveMap.legendDone")) { Capsule().fill(Ink.accent).frame(width: 22, height: 4) }
            legendRow(l10n.t("liveMap.legendAhead")) {
                Rectangle().stroke(Ink.accent, style: StrokeStyle(lineWidth: 4, dash: [4, 3])).frame(width: 22, height: 4)
            }
            Text(l10n.t("liveMap.legendNote")).clack(.caption).foregroundStyle(Ink.text2)
        }
        .clack(.caption).foregroundStyle(Ink.text2)
        .padding(.vertical, 14).padding(.horizontal, 16)
        .frame(maxWidth: 280, alignment: .leading)
        .background(Surface.Lit(op: Ink.accent))
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
        } else if let station = model.stationSheet {
            LiveStationSheet(
                id: station.id, name: station.name, onClose: { model.stationSheet = nil },
                onTrain: { row in
                    model.stationSheet = nil
                    let date = row.trip?.serviceDate ?? Format.localDate(Date().timeIntervalSince1970 * 1000, tz: "Europe/Stockholm")
                    if let train = model.liveTrain(number: row.trainNumber, date: date) {
                        Task { await model.select(train.id) }
                    } else {
                        Task { await model.openScheduled(number: row.trainNumber, date: date, key: row.trip?.key) }
                    }
                },
                onBoard: { router.push(.board(stationId: station.id, arrivals: false)) },
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
                    FlapTime(time: train.nextEta?.ms, tz: "Europe/Stockholm", clock: app.settings.clock, style: .text)
                }
            }
            FlowLayout(spacing: 10, lineSpacing: 6) {
                if let delay = train.delayMin { DelayText(delay: delay) }
                switch position {
                case .estimated: Chip(text: l10n.t("liveMap.posEstimated"))
                case .old(let minutes): Chip(text: l10n.t("liveMap.posOld", ["min": String(minutes)]))
                case .gps: Chip(text: l10n.t("liveMap.posGps"), tint: Ink.onTimeInk)
                }
                if !collapsed.wrappedValue, !train.estimated { Speedometer(kmh: train.speedKmh, at: train.at.ms, now: now) }
            }
            Text(l10n.t("live.updated", ["ago": LiveRules.ago(l10n, then: train.at.ms, now: now)])).clack(.caption).foregroundStyle(Ink.text2)
        } content: {
            StopList(stops: model.stops, color: operatorColor(op?.brandColor, scheme: scheme), now: now)
            OnboardView(facts: nil, operatorId: train.operatorId, trainType: train.trainType, compact: true)
            if case .list(let stops) = model.stops, let from = ExploreLogic.catchableFrom(stops), let last = stops.last {
                BuyTicket(trip: ExploreLogic.ticketTrip(operatorId: train.operatorId, number: train.number, from: from, to: last, trip: detail.trip), inTrips: detail.legId != nil)
            }
            if detail.trip == nil { Text(l10n.t("board.notInTimetable")).clack(.caption).foregroundStyle(Ink.text2) }
        } actions: {
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
        else if let departs, departs > now { status = l10n.t("train.statusDeparts", ["time": Format.time(departs, tz: "Europe/Stockholm", clock: app.settings.clock)]) }
        else { status = l10n.t("train.statusNoPosition") }
        let followed = model.isFollowed(number: view.number, date: view.date)
        return TrainSheet(op: op, title: [view.productName ?? op?.name, view.number].compactMap { $0 }.joined(separator: " "), collapsed: collapsed, onClose: { model.closeScheduled() }) {
            if !collapsed.wrappedValue { art(type: type, operatorId: view.operatorId) }
            if let first, let last { Text("\(first.name) → \(last.name)").clack(.rowTitle).foregroundStyle(Ink.text) }
            Chip(text: status, tint: allCanceled ? Ink.veryLateInk : nil)
            Text(l10n.t(anyLive ? "train.liveTimes" : "train.timetableOnly")).clack(.caption).foregroundStyle(Ink.text2)
        } content: {
            StopList(stops: view.stops.map { .list($0) } ?? .none, color: operatorColor(op?.brandColor, scheme: scheme), now: now)
            OnboardView(facts: nil, operatorId: view.operatorId, trainType: view.trainType, compact: true)
            if let first, let last {
                BuyTicket(trip: ExploreLogic.ticketTrip(operatorId: view.operatorId, number: view.number, from: first, to: last, trip: view.trip), inTrips: view.legId != nil)
            }
        } actions: {
            followButton(following: followed) {
                Task {
                    await model.toggleFollow(number: view.number, date: view.date, operatorId: view.operatorId, label: first.flatMap { f in last.map { "\(f.name) → \($0.name)" } })
                }
            }
            planButton(legId: view.legId, trip: view.trip)
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
            HStack(spacing: 6) {
                LucideIcon(name: following ? "check" : "eye", size: 16)
                Text(l10n.t(following ? "liveMap.following" : "liveMap.follow"))
            }
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(.clack(wide: true))
        .overlay(RoundedRectangle(cornerRadius: Radius.input, style: .continuous).strokeBorder(Ink.accent, lineWidth: following ? 1 : 0))
        .accessibilityAddTraits(following ? .isSelected : [])
    }

    @ViewBuilder
    private func planButton(legId: String?, trip: TrainTrip?) -> some View {
        if let legId {
            Button { router.push(.trip(legId)) } label: { Text(l10n.t("liveMap.inYourTrips")).frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(.clack(.primary, wide: true))
        } else {
            Button {
                if let trip { router.openAdd(AddTrainLink(tripKey: trip.key, date: trip.serviceDate)) }
            } label: { Text(l10n.t("liveMap.plan")).frame(maxWidth: .infinity, minHeight: 48) }
                .buttonStyle(.clack(.primary, wide: true))
                .disabled(trip == nil)
        }
    }
}
