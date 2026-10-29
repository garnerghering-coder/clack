//
//  ExploreSheets.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A train's sheet, live or from the timetable: a header with just the operator and train (it tightens once you scroll),
/// one scrolling body (the journey, its stops, what's on board, tickets) and the actions pinned below. The handle on top
/// drags it between three sizes (just the train, the usual half, nearly the whole screen) and it settles on the nearest
/// one when let go; a flick goes one size further. A tap folds it like the title does (LiveMapPage.tsx `TrainSheet`).
struct TrainSheet<Intro: View, Content: View, Actions: View>: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let op: Operator?
    let title: String
    @Binding var collapsed: Bool
    let onClose: () -> Void
    @ViewBuilder var intro: Intro
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    @State private var full = false
    @State private var scrolled = false
    /// The height while dragging or settling; nil when the sheet sizes itself.
    @State private var dragHeight: Double?
    @State private var dragStart: DragStart?
    @State private var room = 700.0
    @State private var headHeight = 60.0
    @State private var bodyHeight = 200.0
    @State private var footHeight = 74.0

    private struct DragStart {
        var height: Double
        var size: ExploreLogic.SheetSize
        var lastY: Double
        var lastTime: Date
        var velocity = 0.0
        var moved = false
    }

    private var size: ExploreLogic.SheetSize { collapsed ? .small : full ? .full : .mid }

    private var targets: ExploreLogic.SheetTargets {
        ExploreLogic.sheetTargets(room: room, content: headHeight + bodyHeight + footHeight + 14, head: headHeight, foot: footHeight)
    }

    var body: some View {
        let height = dragHeight ?? targets[size]
        VStack(spacing: 0) {
            grabber
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    intro
                    if !collapsed { content }
                }
                .padding(.horizontal, 16).padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: Double.self) { $0.size.height } action: { bodyHeight = $0 }
                .onGeometryChange(for: Double.self) { $0.frame(in: .named("sheet-scroll")).minY } action: { scrolled = $0 < -6 }
            }
            .coordinateSpace(name: "sheet-scroll")
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .frame(height: height)
        .background(Ink.glass)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, 12).padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onGeometryChange(for: Double.self) { $0.size.height } action: { room = $0 }
        .animation(reduceMotion ? nil : .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.22), value: height)
        .accessibilityElement(children: .contain)
    }

    private var grabber: some View {
        RoundedRectangle(cornerRadius: Radius.bar, style: .continuous)
            .fill(Ink.text3.opacity(0.6))
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity).frame(height: 28)
            .contentShape(Rectangle())
            .gesture(drag)
            .accessibilityElement()
            .accessibilityLabel(l10n.t(collapsed ? "liveMap.expandSheet" : "liveMap.collapseSheet"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { collapsed.toggle() }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: settle(size == .small ? .mid : .full)
                case .decrement: settle(size == .full ? .mid : .small)
                @unknown default: break
                }
            }
    }

    private var header: some View {
        HStack(spacing: 12) {
            OperatorBadge(op: op, size: .medium)
                .scaleEffect(scrolled && !collapsed ? 0.8 : 1, anchor: .leading)
            Button { collapsed.toggle() } label: {
                HStack(spacing: 8) {
                    Text(title).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
                    LucideIcon(name: collapsed ? "chevron-up" : "chevron-down", size: 18).foregroundStyle(Ink.text)
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
        }
        .padding(.horizontal, 16).padding(.top, scrolled && !collapsed ? 4 : 0).padding(.bottom, scrolled && !collapsed ? 6 : 10)
        .overlay(alignment: .bottom) { Rectangle().fill(scrolled && !collapsed ? Ink.hairline : .clear).frame(height: 1) }
        .onGeometryChange(for: Double.self) { $0.size.height } action: { headHeight = $0 }
    }

    private var footer: some View {
        HStack(spacing: 12) { actions }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 16)
            .overlay(alignment: .top) { Rectangle().fill(Ink.hairline).frame(height: 1) }
            .onGeometryChange(for: Double.self) { $0.size.height } action: { footHeight = $0 }
    }

    // MARK: dragging between sizes

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                var start = dragStart ?? DragStart(height: dragHeight ?? targets[size], size: size, lastY: value.location.y, lastTime: value.time)
                let dy = value.location.y - value.startLocation.y
                if abs(dy) > 4 { start.moved = true }
                guard start.moved else { dragStart = start; return }
                let dt = max(1, value.time.timeIntervalSince(start.lastTime) * 1000)
                start.velocity = 0.7 * start.velocity + 0.3 * ((value.location.y - start.lastY) / dt)
                start.lastY = value.location.y
                start.lastTime = value.time
                dragStart = start
                // Dragging up from the small size shows the rest of the sheet straight away.
                if collapsed && dy < -24 { collapsed = false }
                dragHeight = max(96, min(targets.full, start.height - dy))
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                guard start.moved else { collapsed.toggle(); return }
                let h = max(96, start.height - (value.location.y - value.startLocation.y))
                settle(ExploreLogic.settle(height: h, velocity: start.velocity, from: start.size, targets: targets))
            }
    }

    private func settle(_ to: ExploreLogic.SheetSize) {
        dragHeight = targets[to]
        collapsed = to == .small
        full = to == .full
        // The height follows the size from here; the animation carries it there.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(230))
            dragHeight = nil
        }
    }
}

/// The train's whole route: passed stops dimmed with a filled dot, the next one marked, later ones ahead.
struct StopList: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let stops: ExploreModel.StopsState
    /// The operator's colour: the rail is filled with it where the train has been.
    var color: Color = Ink.accent
    var now: Double = Date.now.timeIntervalSince1970 * 1000

    var body: some View {
        switch stops {
        case .none:
            Text(l10n.t("liveMap.stopsNone")).clack(.caption).foregroundStyle(Ink.text2)
        case .loading:
            Text(l10n.t("liveMap.stopsLoading")).clack(.caption).foregroundStyle(Ink.text2)
        case .list(let list):
            let next = ExploreLogic.nextStopIndex(list)
            // The train is drawn between the stops it has left and the one it is heading for, as on a trip's page.
            let halves = TripDetailLogic.railHalves(count: list.count, fills: ExploreLogic.railFills(list, now: now), showTrain: true) { _ in true }
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t("liveMap.stops")).clack(.captionUpper).foregroundStyle(Ink.text2)
                VStack(spacing: 0) {
                    ForEach(Array(list.enumerated()), id: \.element.seq) { i, stop in
                        row(stop, index: i, count: list.count, isNext: i == next, above: halves[i].above, below: halves[i].below)
                    }
                }
            }
        }
    }

    private func row(_ stop: LiveTrainStop, index i: Int, count: Int, isNext: Bool, above: TripDetailLogic.RailHalf, below: TripDetailLogic.RailHalf) -> some View {
        let times = ExploreLogic.stopTimes(stop, isLast: i == count - 1)
        let dwell = ExploreLogic.dwell(stop, isEnd: i == 0 || i == count - 1)
        // Why it's late or changed here, under the station (as on a trip's page and a board).
        let causes = l10n.shownNotes(stop.causes ?? [])
        var notes: [StopRow.Note] = stop.canceled ? [.init(l10n.t("liveMap.canceledStop"))] : []
        if !causes.isEmpty { notes.append(.init(Format.join(causes))) }
        // The shared stop row, compact (no flaps in a sheet): passed stops dimmed, the next one in 600.
        return StopRow(
            name: stop.name, emphasis: stop.passed ? .dim : isNext ? .next : .plain, canceled: stop.canceled,
            notes: notes,
            rail: StopRail(color: color, big: i == 0 || i == count - 1, startsHere: i == 0, endsHere: i == count - 1, above: above, below: below),
            time: dwell != nil ? (stop.actualArr ?? stop.estimatedArr ?? stop.arr) : (times.real ?? times.planned),
            sched: dwell != nil ? stop.arr : times.planned,
            live: dwell != nil ? (stop.actualArr ?? stop.estimatedArr) != nil : times.real != nil,
            delay: dwell != nil ? arrivalDelay(stop) : (times.real != nil ? times.lateMinutes : nil),
            tz: Format.zone(stationId: stop.stationId), clock: app.settings.clock, platform: stop.platform, compact: true,
            dwell: dwell.map { StopRow.Dwell(arr: $0.arr, dep: $0.dep) }
        )
    }
}

/// Minutes late at arrival, when a real or estimated arrival is known.
private func arrivalDelay(_ stop: LiveTrainStop) -> Int? {
    guard let planned = stop.arr, let real = stop.actualArr ?? stop.estimatedArr else { return nil }
    return Int(((real - planned) / 60_000).rounded())
}

// MARK: the other sheets

/// A plain bottom card for the sheets without drag sizes (`.live-sheet`).
struct LiveSheetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(.horizontal, 16).padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.glass)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, 12).padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// A corridor from the network status: the stretch, how late its trains are, the reasons the feeds give (each with
/// its source) and the late trains themselves, which open on a tap. The map behind shows the track in orange and
/// rings the trains; the model refreshes it every 30 s (`watchCorridor`). Status is written, never boxed.
struct CorridorSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let corridor: NetworkStatus.Corridor
    /// The stretch has dropped out of the latest status: the figures shown are the last ones.
    let gone: Bool
    let updatedAt: Double?
    let onClose: () -> Void
    let onTrain: (String) -> Void

    var body: some View {
        LiveSheetCard {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(corridor.stations.joined(separator: " – ")).clack(.sheetTitle).foregroundStyle(Ink.text).lineLimit(3)
                    Text(NetworkWording.corridorLine(corridor, l10n: l10n)).clack(.caption).monospacedDigit().foregroundStyle(Ink.lateInk)
                    if gone { Text(l10n.t("network.corridorGone")).clack(.caption).foregroundStyle(Ink.onTimeInk) }
                }
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    reasons
                    trains
                    Text(l10n.t("network.corridorHint")).clack(.micro).foregroundStyle(Ink.text3)
                    if let updatedAt {
                        Text(l10n.t("network.updated", ["time": Format.time(updatedAt, tz: TimeZone.current.identifier, clock: app.settings.clock)]))
                            .clack(.micro).foregroundStyle(Ink.text3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: 300)
        }
        .accessibilityElement(children: .contain)
    }

    /// Each reason once, with how many trains give it and which feed it comes from.
    @ViewBuilder
    private var reasons: some View {
        Text(l10n.t("network.corridorReasons")).clack(.captionUpper).foregroundStyle(Ink.text2)
        let named = corridor.causes.compactMap { c -> (text: String, count: Int, src: String)? in
            DelayCauses.text(c.cause, translate: { l10n.t($0) }).map { ($0, c.trains, c.src) }
        }
        if named.isEmpty {
            Text(l10n.t("network.noReason")).clack(.body).foregroundStyle(Ink.text2)
        } else {
            ForEach(Array(named.enumerated()), id: \.offset) { _, r in
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("network.reasonCount", count: r.count, ["reason": r.text, "count": String(r.count)])).clack(.body).foregroundStyle(Ink.text)
                    Text(l10n.t("notice.source", ["source": DelayCauses.sourceName(r.src)])).clack(.micro).foregroundStyle(Ink.text3)
                }
            }
        }
    }

    @ViewBuilder
    private var trains: some View {
        Text(l10n.t("network.corridorTrains")).clack(.captionUpper).foregroundStyle(Ink.text2).padding(.top, 4)
        let list = corridor.lateTrains ?? []
        if list.isEmpty {
            Text(l10n.t("network.corridorNoneLate")).clack(.body).foregroundStyle(Ink.onTimeInk)
        } else {
            ForEach(list) { t in
                Button { onTrain(t.id) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        OperatorBadge(op: t.operatorId.flatMap { app.operatorsById[$0] }, size: .small)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text([t.operatorId.flatMap { app.operatorsById[$0]?.name }, t.number].compactMap { $0 }.joined(separator: " "))
                                    .clack(.rowTitle).foregroundStyle(Ink.text)
                                Text(l10n.t("network.minLate", ["min": String(t.delayMin)])).clack(.delay).monospacedDigit()
                                    .foregroundStyle(t.delayMin >= 30 ? Ink.veryLateInk : Ink.lateInk)
                            }
                            if let towards = t.next ?? t.destination {
                                Text(l10n.t("network.towards", ["b": towards])).clack(.caption).foregroundStyle(Ink.text2)
                            }
                            if !t.causes.isEmpty {
                                Text(NetworkWording.reasons(t.causes.map { .init(src: $0.src, code: $0.code, text: $0.text, trains: 1) }, l10n: l10n, counted: false))
                                    .clack(.caption).foregroundStyle(Ink.text2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A train you asked for that isn't on the map: not started yet, finished, or not running today.
struct NotRunningSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let follow: Follow?
    let number: String
    let onUnfollow: (Follow) -> Void
    let onClose: () -> Void

    var body: some View {
        let op = follow?.operatorId.flatMap { app.operatorsById[$0] }
        LiveSheetCard {
            HStack(spacing: 12) {
                ServiceHeader(op: op, number: op == nil ? nil : number, size: .medium, fallback: l10n.t("liveMap.train", ["number": number]))
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            if let label = follow?.label { Text(label).clack(.rowTitle).foregroundStyle(Ink.text) }
            Text(l10n.t("liveMap.notRunningTitle")).clack(.body).foregroundStyle(Ink.text)
            Text(l10n.t("liveMap.notRunningBody")).clack(.caption).foregroundStyle(Ink.text2)
            HStack(spacing: 12) {
                if let follow {
                    Button { onUnfollow(follow) } label: { HStack(spacing: 8) { LucideIcon(name: "eye-off", size: 16); Text(l10n.t("liveMap.unfollow")) }.frame(maxWidth: .infinity) }
                        .buttonStyle(.clack(wide: true))
                }
                Button(l10n.t("common.close"), action: onClose).buttonStyle(.clack(.primary, wide: true))
            }
        }
    }
}

/// A station tapped on the live map: its next departures, the board and its map.
struct LiveStationSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let id: String
    let name: String
    let onClose: () -> Void
    let onTrain: (BoardRow) -> Void
    let onBoard: () -> Void
    let onArrivals: () -> Void
    let onMap: () -> Void
    @State private var info: StationInfo?
    @State private var rows: [BoardRow]?
    @State private var favorite = false

    private func toggleFavorite() async {
        Usage.shared.count(.feature, "station.favorite")
        if let on = try? await app.client.setFavorite(id, !favorite) {
            favorite = on
            await app.stations.setFavorite(id, on)
        }
    }

    var body: some View {
        LiveSheetCard {
            HStack(spacing: 8) {
                Text(name).clack(.sheetTitle).foregroundStyle(Ink.text).lineLimit(2)
                Spacer(minLength: 0)
                IconButton(
                    icon: "star", label: l10n.t(favorite ? "stations.unfavorite" : "stations.favorite"), size: .overMap, selected: favorite
                ) { Task { await toggleFavorite() } }
                    .sensoryFeedback(.selection, trigger: favorite)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            if let county = info?.county { Text(county).clack(.caption).foregroundStyle(Ink.text2) }
            if let rows {
                if rows.isEmpty {
                    if info?.hasBoard == true { Text(l10n.t("board.empty")).clack(.caption).foregroundStyle(Ink.text2) }
                } else {
                    VStack(spacing: 0) {
                        ForEach(rows) { row in
                            Button { onTrain(row) } label: {
                                BoardRowView(
                                    .init(
                                        time: row.estimated ?? row.advertised, sched: row.advertised, tz: info?.tz ?? Format.zone(stationId: id),
                                        destination: row.endpoints.joined(separator: ", "), platform: row.platform,
                                        delay: row.estimated != nil || row.actual != nil ? row.delayMin : nil
                                    ),
                                    clock: app.settings.clock, compact: true
                                ) {
                                    OperatorBadge(op: row.operatorId.flatMap { app.operatorsById[$0] }, size: .small)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                Text(l10n.t("common.loading")).clack(.caption).foregroundStyle(Ink.text2)
            }
            // The station's board, pushed on Explore (the Stations screen's job, now here).
            // One way in: the board has the departures / arrivals switch.
            if info?.hasBoard == true {
                Button(l10n.t("board.openBoard", ["station": name]), action: onBoard).buttonStyle(.clack(.primary, wide: true))
            }
            if info?.hasMap == true {
                Button(l10n.t("stationMap.open"), action: onMap).buttonStyle(.clack(wide: true))
            }
        }
        .task(id: id) {
            info = nil
            rows = nil
            guard let station = await app.stations.info(id) else { return }
            info = station
            favorite = station.favorite
            guard station.hasBoard else { rows = []; return }
            if let board = try? await app.client.board(id, arrivals: false) {
                rows = Array(board.rows.filter { !$0.done && !$0.canceled }.sorted { ($0.estimated ?? $0.advertised) < ($1.estimated ?? $1.advertised) }.prefix(4))
            } else {
                rows = []
            }
        }
    }
}

/// The reasons a train is late, from its stops' causes, as one written line at the top of its sheet ("Late because of
/// an accident"). Only reasons the cause table knows (so they read in the app's language); nothing when there are none.
struct LateReasons: View {
    @Environment(L10n.self) private var l10n
    let stops: [LiveTrainStop]

    var body: some View {
        let reasons = DelayCauses.reasons(stops.flatMap { $0.causes ?? [] }) { l10n.t($0) }.map(\.text)
        if !reasons.isEmpty {
            Text(l10n.t("liveMap.lateBecause", ["reasons": reasons.formatted(.list(type: .and))]))
                .clack(.rowTitle).foregroundStyle(Ink.text)
        }
    }
}
