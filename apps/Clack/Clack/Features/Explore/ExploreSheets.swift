//
//  ExploreSheets.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A train's sheet, live or from the timetable, inside Explore's system sheet (owner, 2026-11-15: every panel the
/// native way, as Network now): a header with the operator and train, one scrolling body (what's live, the stops,
/// what's on board) and the actions pinned below. The system sheet does the sizes and the dragging.
struct TrainSheet<Intro: View, Content: View, Actions: View>: View {
    @Environment(L10n.self) private var l10n
    let op: Operator?
    let title: String
    let onClose: () -> Void
    @ViewBuilder var intro: Intro
    @ViewBuilder var content: Content
    @ViewBuilder var actions: Actions

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                header
                intro
                content
            }
            .padding(.horizontal, Space.l).padding(.top, Space.l).padding(.bottom, Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: Space.m) { actions }
                .padding(.horizontal, Space.l).padding(.top, Space.m).padding(.bottom, Space.m)
                .background(.bar)
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: Space.m) {
            OperatorBadge(op: op, size: .medium)
            Text(title).clack(.sheetTitle).foregroundStyle(Ink.text).lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 0)
            IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
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
            VStack(alignment: .leading, spacing: Space.s) {
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

/// The body of Explore's system sheet for the panels without a pinned footer: padded content that scrolls when it
/// doesn't fit the sheet's size.
struct LiveSheetCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                content
            }
            .padding(.horizontal, Space.l).padding(.vertical, Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
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
            HStack(alignment: .top, spacing: Space.s) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(corridor.stations.joined(separator: " – ")).clack(.sheetTitle).foregroundStyle(Ink.text).lineLimit(3)
                    Text(NetworkWording.corridorLine(corridor, l10n: l10n)).clack(.caption).monospacedDigit().foregroundStyle(Ink.lateInk)
                    if gone { Text(l10n.t("network.corridorGone")).clack(.caption).foregroundStyle(Ink.onTimeInk) }
                }
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            reasons
            trains
            Text(l10n.t("network.corridorHint")).clack(.micro).foregroundStyle(Ink.text3)
            if let updatedAt {
                Text(l10n.t("network.updated", ["time": Format.time(updatedAt, tz: TimeZone.current.identifier, clock: app.settings.clock)]))
                    .clack(.micro).foregroundStyle(Ink.text3)
            }
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
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(l10n.t("network.reasonCount", count: r.count, ["reason": r.text, "count": String(r.count)])).clack(.body).foregroundStyle(Ink.text)
                    Text(l10n.t("notice.source", ["source": DelayCauses.sourceName(r.src)])).clack(.micro).foregroundStyle(Ink.text3)
                }
            }
        }
    }

    @ViewBuilder
    private var trains: some View {
        Text(l10n.t("network.corridorTrains")).clack(.captionUpper).foregroundStyle(Ink.text2).padding(.top, Space.xs)
        let list = corridor.lateTrains ?? []
        if list.isEmpty {
            Text(l10n.t("network.corridorNoneLate")).clack(.body).foregroundStyle(Ink.onTimeInk)
        } else {
            ForEach(list) { t in
                Button { onTrain(t.id) } label: {
                    HStack(alignment: .top, spacing: Space.m) {
                        OperatorBadge(op: t.operatorId.flatMap { app.operatorsById[$0] }, size: .small)
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            HStack(spacing: Space.s) {
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

/// One problem on the network (owner, 2026-11-15: "tap on them … it should go to that spot, and go into a view of
/// telling you what's wrong with it"): what it is, where, when, the source's own words translated on the phone when
/// they're in another language, your trains today it touches, and where it comes from. The map behind has gone to it
/// with its track lit; back returns to Network now. Status is written, never boxed.
struct DisruptionSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let disruption: NetworkStatus.Disruption
    /// Your trains left to run today (Network now loaded them).
    let mine: [Leg]
    let onBack: () -> Void
    let onClose: () -> Void
    let onTrip: (String) -> Void

    private var d: NetworkStatus.Disruption { disruption }
    private var kind: String { l10n.t("network.kind.\(d.kind.rawValue)") }
    private var ink: Color { d.kind == .works ? Ink.lateInk : Ink.veryLateInk }

    var body: some View {
        LiveSheetCard {
            HStack(alignment: .top, spacing: Space.s) {
                IconButton(icon: "chevron-left", label: l10n.t("common.back"), size: .overMap, action: onBack)
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(d.places.isEmpty ? kind : d.places.joined(separator: " – ")).clack(.sheetTitle).foregroundStyle(Ink.text).lineLimit(3)
                    HStack(spacing: Space.xs) {
                        LucideIcon(name: d.kind == .works ? "construction" : d.kind == .closure ? "ban" : "triangle-alert", size: 14).foregroundStyle(ink)
                        Text(kind).clack(.caption).foregroundStyle(ink)
                        Flag(country: d.country, size: 14, decorative: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            Text(when).clack(.rowTitle).monospacedDigit().foregroundStyle(Ink.text)
            words
            yours
            Text(l10n.t("notice.source", ["source": DelayCauses.sourceName(d.source)])).clack(.micro).foregroundStyle(Ink.text3)
        }
        .accessibilityElement(children: .contain)
    }

    /// "From Mon 16 Nov 22:00 until Tue 17 Nov 05:00", "Until 15:00", or that the source gives no end.
    private var when: String {
        let tz = Format.zone(country: d.country)
        let now = Date.now.timeIntervalSince1970 * 1000
        func at(_ ms: Double) -> String {
            let time = Format.time(ms, tz: tz, clock: app.settings.clock)
            return Format.localDate(ms, tz: tz) == Format.localDate(now, tz: tz) ? time : "\(Format.day(ms, tz: tz, now: now, language: app.settings.language)) \(time)"
        }
        switch (d.from, d.to) {
        case let (from?, to?) where from > now: return l10n.t("network.fromUntil", ["from": at(from), "to": at(to)])
        case let (from?, nil) where from > now: return l10n.t("network.fromOn", ["from": at(from)])
        case let (_, to?): return l10n.t("network.untilLong", ["to": at(to)])
        default: return l10n.t("network.noEnd")
        }
    }

    /// The source's short words and its longer text, each in the app's language where the phone could translate it.
    @ViewBuilder
    private var words: some View {
        let short = d.text(l10n.language).map { l10n.shownWhole($0) }
        let long = d.detailText(l10n.language).map { l10n.shownWhole($0) }
        if short == nil && long == nil {
            Text(l10n.t("network.noText")).clack(.body).foregroundStyle(Ink.text2)
        } else {
            VStack(alignment: .leading, spacing: Space.s) {
                if let short, short.text != long?.text { Text(short.text).clack(.headline).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true) }
                if let long { Text(long.text).clack(.body).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true) }
                if short?.translated == true || long?.translated == true {
                    Text(l10n.t("network.translatedOnPhone")).clack(.micro).foregroundStyle(Ink.text3)
                }
            }
            .textSelection(.enabled)
        }
    }

    /// Your trains today that start or end at one of its places.
    @ViewBuilder
    private var yours: some View {
        let places = Set(d.places)
        let hit = mine.filter { leg in [leg.origin?.name, leg.destination?.name].contains { $0.map(places.contains) ?? false } }
        if !hit.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                Text(l10n.t("network.yourTrainsHere")).clack(.captionUpper).foregroundStyle(Ink.text2)
                ForEach(hit) { leg in
                    Button { onTrip(leg.id) } label: {
                        HStack(spacing: Space.m) {
                            LucideIcon(name: "train-front", size: 18).foregroundStyle(ink).frame(width: 24)
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text(verbatim: "\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")").clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2)
                                let service = Format.join([leg.operator?.name, leg.trainNumber], separator: " ")
                                if !service.isEmpty { Text(service).clack(.caption).foregroundStyle(Ink.text2) }
                            }
                            Spacer(minLength: 0)
                            LucideIcon(name: "chevron-right", size: 16).foregroundStyle(Ink.text3)
                        }
                        .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.pressRow)
                }
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
            HStack(spacing: Space.m) {
                ServiceHeader(op: op, number: op == nil ? nil : number, size: .medium, fallback: l10n.t("liveMap.train", ["number": number]))
                Spacer(minLength: 0)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            if let label = follow?.label { Text(label).clack(.rowTitle).foregroundStyle(Ink.text) }
            Text(l10n.t("liveMap.notRunningTitle")).clack(.body).foregroundStyle(Ink.text)
            Text(l10n.t("liveMap.notRunningBody")).clack(.caption).foregroundStyle(Ink.text2)
            HStack(spacing: Space.m) {
                if let follow {
                    Button { onUnfollow(follow) } label: { HStack(spacing: Space.s) { LucideIcon(name: "eye-off", size: 16); Text(l10n.t("liveMap.unfollow")) }.frame(maxWidth: .infinity) }
                        .buttonStyle(.clack(wide: true))
                }
                Button(l10n.t("common.close"), action: onClose).buttonStyle(.clack(.primary, wide: true))
            }
        }
    }
}

/// A station tapped on the live map: its map and full board first, then its next departures. Opening the map or the
/// board puts the sheet aside until you come back (`ExploreModel.stepAside`).
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
    /// Taps on the star (the haptic follows the finger, not the favourite loading).
    @State private var favoriteTaps = 0
    @Environment(Toaster.self) private var toaster
    @Environment(PassportStore.self) private var passport
    @State private var boardFailed = false

    private func boardRow(_ row: BoardRow, now: Double) -> some View {
        let time = row.estimated ?? row.advertised
        let minutes = Int(((time - now) / 60_000).rounded(.down))
        let countdown: String? = minutes <= 0 ? l10n.t("board.now") : minutes < 60 ? l10n.t("board.minutes", ["min": String(minutes)]) : nil
        return Button { onTrain(row) } label: {
            BoardRowView(
                .init(
                    time: time, sched: row.advertised, tz: info?.tz ?? Format.zone(stationId: id),
                    destination: row.endpoints.joined(separator: ", "), platform: row.platform,
                    delay: row.estimated != nil || row.actual != nil ? row.delayMin : nil,
                    // Cancelled trains read as running here before (2026-11-07).
                    canceled: row.canceled,
                    replacedByBus: row.canceled && row.allCauses.contains(where: \.isBusReplacement),
                    countdown: countdown
                ),
                clock: app.settings.clock, compact: true
            ) {
                OperatorBadge(op: row.operatorId.flatMap { app.operatorsById[$0] }, size: .small)
            }
        }
        .buttonStyle(.pressRow)
    }

    private func loadBoard() async {
        boardFailed = false
        do {
            let board = try await app.client.board(id, arrivals: false)
            rows = Array(board.rows.filter { !$0.done }.sorted { ($0.estimated ?? $0.advertised) < ($1.estimated ?? $1.advertised) }.prefix(6))
        } catch {
            boardFailed = true
        }
    }

    private func toggleFavorite() async {
        Usage.shared.count(.feature, "station.favorite")
        // The star changes at once; the server is asked after, and a refusal puts it back and says so.
        let want = !favorite
        favorite = want
        favoriteTaps += 1
        if let on = try? await app.client.setFavorite(id, want) {
            favorite = on
            await app.stations.setFavorite(id, on)
        } else {
            favorite = !want
            toaster.show(l10n.t("stations.favoriteFailed"), isError: true)
        }
    }

    var body: some View {
        LiveSheetCard {
            HStack(spacing: Space.s) {
                Text(name).clack(.sheetTitle).foregroundStyle(Ink.text).lineLimit(2)
                Spacer(minLength: 0)
                IconButton(
                    icon: "star", label: l10n.t(favorite ? "stations.unfavorite" : "stations.favorite"), size: .overMap, selected: favorite
                ) { Task { await toggleFavorite() } }
                    .haptic(.selection, trigger: favoriteTaps)
                IconButton(icon: "x", label: l10n.t("common.close"), size: .overMap, action: onClose)
            }
            if let county = info?.county { Text(county).clack(.caption).foregroundStyle(Ink.text2) }
            // Yours: how often you've been here, from your Passport (designer, 2026-11-14: "make it personal").
            if let visits = passport.data?.stations.first(where: { $0.id == id })?.count, visits > 0 {
                Text(visits == 1 ? l10n.t("station.visitedOne") : l10n.t("station.visited", ["count": String(visits)])).clack(.caption).foregroundStyle(Ink.text2)
            }
            // The way on first, under the name (owner, 2026-11-15: the buttons sat under the whole list): the station
            // map and the full board, then the next few trains.
            HStack(spacing: Space.m) {
                if info?.hasMap == true {
                    // The station map as a tile, not a second button (designer, 2026-11-14).
                    Button(action: onMap) {
                        HStack(spacing: Space.s) {
                            LucideIcon(name: "map", size: 18)
                            Text(l10n.t("stationMap.open")).clack(.rowTitle).lineLimit(2)
                        }
                        .foregroundStyle(Ink.text)
                        .padding(Space.m)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    }
                    .buttonStyle(.press(radius: Radius.input))
                }
                if info?.hasBoard == true {
                    // Arrivals and earlier or later trains: the full board, still one tap away.
                    Button(action: onBoard) {
                        HStack(spacing: Space.s) {
                            LucideIcon(name: "list", size: 18)
                            Text(l10n.t("board.fullBoard")).clack(.rowTitle).lineLimit(2)
                        }
                        .foregroundStyle(Ink.text)
                        .padding(Space.m)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    }
                    .buttonStyle(.press(radius: Radius.input))
                }
            }
            if boardFailed {
                // Not reached is said as such, not as "no trains" (polish pass 1).
                ErrorStateView(message: l10n.t("board.loadFailed"), retry: { await loadBoard() })
            } else if let rows {
                if rows.isEmpty {
                    if info?.hasBoard == true { Text(l10n.t("board.empty")).clack(.caption).foregroundStyle(Ink.text2) }
                } else {
                    // The board itself, here (designer, 2026-11-14: the card was a signpost to another screen): the next
                    // six; the full board has the rest.
                    TimelineView(.everyMinute) { context in
                        let now = context.date.timeIntervalSince1970 * 1000
                        VStack(spacing: 0) {
                            ForEach(rows) { row in boardRow(row, now: now) }
                        }
                    }
                }
            } else {
                // The rows' place, held.
                ForEach(0..<4, id: \.self) { _ in Skeleton(height: 44, radius: Radius.tag).padding(.vertical, Space.xxs) }
            }
        }
        .task(id: id) {
            info = nil
            rows = nil
            guard let station = await app.stations.info(id) else { return }
            info = station
            favorite = station.favorite
            guard station.hasBoard else { rows = []; return }
            await loadBoard()
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

/// A train's actions (owner, 2026-11-14): one primary action, the full width (Add to trips, In your trips, or adding a
/// train from live data), and Following in a `…` menu beside it, under one line that says what following does. Shared
/// by Explore's train sheets and the train sheet opened from anywhere else (they each had their own copy).
struct TrainActions<Primary: View>: View {
    @Environment(L10n.self) private var l10n
    let following: Bool
    var busy = false
    let onFollow: () -> Void
    @ViewBuilder var primary: Primary

    var body: some View {
        HStack(spacing: Space.m) {
            primary.frame(maxWidth: .infinity)
            Menu {
                Section(l10n.t("liveMap.followExplain")) {
                    Button(action: onFollow) {
                        Label(l10n.t(following ? "liveMap.unfollow" : "liveMap.follow"), systemImage: following ? "eye.slash" : "eye")
                    }
                    .disabled(busy)
                }
            } label: {
                // Following shows on the button itself, filled in the selection ink.
                MapButtonFace(icon: following ? "eye" : "", pressed: following, symbol: following ? nil : "ellipsis")
            }
            .clackMenu()
            .accessibilityLabel(l10n.t(following ? "liveMap.following" : "liveMap.moreActions"))
        }
    }
}
