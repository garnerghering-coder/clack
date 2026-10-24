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
                .padding(.horizontal, 16).padding(.bottom, 14)
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
        RoundedRectangle(cornerRadius: 3, style: .continuous)
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
        HStack(spacing: 10) {
            OperatorBadge(op: op, size: .medium)
                .scaleEffect(scrolled && !collapsed ? 0.8 : 1, anchor: .leading)
            Button { collapsed.toggle() } label: {
                HStack(spacing: 6) {
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
        HStack(spacing: 10) { actions }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 14)
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
            VStack(alignment: .leading, spacing: 6) {
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
        // The shared stop row, compact (no flaps in a sheet): passed stops dimmed, the next one in 600.
        return StopRow(
            name: stop.name, emphasis: stop.passed ? .dim : isNext ? .next : .plain, canceled: stop.canceled,
            notes: stop.canceled ? [.init(l10n.t("liveMap.canceledStop"))] : [],
            rail: StopRail(color: color, big: i == 0 || i == count - 1, startsHere: i == 0, endsHere: i == count - 1, above: above, below: below),
            time: times.real ?? times.planned, sched: times.planned, live: times.real != nil, delay: times.real != nil ? times.lateMinutes : nil,
            tz: "Europe/Stockholm", clock: app.settings.clock, platform: stop.platform, compact: true
        )
    }
}

// MARK: the other sheets

/// A plain bottom card for the sheets without drag sizes (`.live-sheet`).
struct LiveSheetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
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
            HStack(spacing: 10) {
                OperatorBadge(op: op, size: .medium)
                Text([op?.name, number].compactMap { $0 }.joined(separator: " ").isEmpty ? l10n.t("liveMap.train", ["number": number]) : [op?.name, number].compactMap { $0 }.joined(separator: " "))
                    .clack(.rowTitle).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            if let label = follow?.label { Text(label).clack(.rowTitle).foregroundStyle(Ink.text) }
            Text(l10n.t("liveMap.notRunningTitle")).clack(.body).foregroundStyle(Ink.text)
            Text(l10n.t("liveMap.notRunningBody")).clack(.caption).foregroundStyle(Ink.text2)
            HStack(spacing: 10) {
                if let follow {
                    Button { onUnfollow(follow) } label: { HStack(spacing: 6) { LucideIcon(name: "eye-off", size: 16); Text(l10n.t("liveMap.unfollow")) }.frame(maxWidth: .infinity) }
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
    let onMap: () -> Void
    @State private var info: StationInfo?
    @State private var rows: [BoardRow]?

    var body: some View {
        LiveSheetCard {
            HStack {
                Text(name).clack(.rowTitle).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
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
                                        time: row.estimated ?? row.advertised, sched: row.advertised, tz: "Europe/Stockholm",
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
            HStack(spacing: 10) {
                if info?.hasBoard == true {
                    Button(l10n.t("liveMap.allDepartures"), action: onBoard).buttonStyle(.clack(wide: true))
                }
                if info?.hasMap == true {
                    Button(l10n.t("stationMap.open"), action: onMap).buttonStyle(.clack(.primary, wide: true))
                }
            }
        }
        .task(id: id) {
            info = nil
            rows = nil
            guard let station = await app.stations.info(id) else { return }
            info = station
            guard station.hasBoard else { rows = []; return }
            if let board = try? await app.client.board(id, arrivals: false) {
                rows = Array(board.rows.filter { !$0.done && !$0.canceled }.sorted { ($0.estimated ?? $0.advertised) < ($1.estimated ?? $1.advertised) }.prefix(4))
            } else {
                rows = []
            }
        }
    }
}
