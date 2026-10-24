//
//  BoardScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A station's departure and arrival board (BoardPage.tsx). Live while open: the server polls Trafikverket once for
/// everyone watching this station and pushes the board over a stream.
struct BoardScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let stationId: String
    @State var arrivals: Bool

    @State private var station: StationInfo?
    @State private var missing = false
    @State private var board: Board?
    @State private var earlier: [BoardRow]?
    @State private var error = false
    @State private var filter = BoardLogic.Filter()
    /// How many rows are showing: 20 to start with, 20 more each time "Show later" is pressed.
    @State private var limit = Self.page
    /// Departures from 12 to 24 hours ahead, fetched the first time "Show later" needs them.
    @State private var later: [BoardRow]?
    @State private var loadingLater = false
    private static let page = 20
    /// The furthest ahead the board looks.
    private static let reachMs = 24.0 * 3_600_000

    private var tz: String { station?.tz ?? "Europe/Stockholm" }

    var body: some View {
        Page {
            BackLink(label: l10n.t("stations.title"))
            if missing {
                Text(l10n.t("board.notFound")).clack(.body).foregroundStyle(Ink.text2)
            } else {
                head
                if let board { status(board) }
                SegmentedControl(
                    selection: $arrivals,
                    options: [(false, l10n.t("board.departures")), (true, l10n.t("board.arrivals"))]
                )
                content
            }
        }
        .refreshable {
            if let station, station.hasBoard, let fresh = try? await app.client.board(stationId, arrivals: arrivals) { board = fresh }
        }
        .task {
            filter.commuter = app.settings.includeCommuter
            // The page limit and the 24 h reach decide what shows, not a window chip.
            filter.window = .day
            station = await app.stations.info(stationId)
            if station == nil { missing = true; return }
            try? await app.client.stationViewed(stationId)
            if let station { favoriteOverride = station.favorite }
        }
        .task(id: StreamKey(arrivals: arrivals, hasBoard: station?.hasBoard ?? false)) { await follow() }
    }

    @State private var favoriteOverride = false

    private struct StreamKey: Hashable { var arrivals: Bool; var hasBoard: Bool }

    /// The live board: the stream sends the current board straight away, then after every poll; it reconnects after a drop.
    private func follow() async {
        guard station?.hasBoard == true else { return }
        board = nil
        earlier = nil
        later = nil
        limit = Self.page
        filter.showEarlier = false
        error = false
        while !Task.isCancelled {
            do {
                for try await event in app.client.boardStream(stationId, arrivals: arrivals) where event.name == "board" {
                    if let decoded = await EventStream.decode(Board.self, from: event) {
                        board = decoded
                        error = false
                    }
                }
            } catch {
                self.error = true
            }
            try? await Task.sleep(for: .seconds(5))
        }
    }

    /// "Show later": 20 more rows. When all that's loaded is showing, the hours from 12 to 24 ahead are fetched first.
    private func showLater(more: Bool) async {
        if !more, later == nil, let board {
            loadingLater = true
            defer { loadingLater = false }
            let to = Date().timeIntervalSince1970 * 1000 + Self.reachMs
            if to > board.to, let fetched = try? await app.client.board(stationId, arrivals: arrivals, from: board.to, to: to) {
                later = fetched.rows
            } else {
                return
            }
        }
        limit += Self.page
    }

    private func loadEarlier() async {
        filter.showEarlier = true
        guard let board, earlier == nil else { return }
        let to = board.from
        earlier = (try? await app.client.board(stationId, arrivals: arrivals, from: to - 3 * 3_600_000, to: to))?.rows ?? []
    }

    private func toggleFavorite() async {
        guard let station else { return }
        if let on = try? await app.client.setFavorite(station.id, !favoriteOverride) {
            favoriteOverride = on
            await app.stations.setFavorite(station.id, on)
        }
    }

    // MARK: pieces

    private var head: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(station?.name ?? " ").clack(.pageTitle).foregroundStyle(Ink.text).lineLimit(2).minimumScaleFactor(0.7)
                    .accessibilityAddTraits(.isHeader)
                if let county = station?.county { Text(county).clack(.caption).foregroundStyle(Ink.text2) }
            }
            Spacer(minLength: 0)
            if let station {
                if station.hasMap {
                    IconActionButton(icon: "map", label: l10n.t("stationMap.open")) {
                        router.push(.stationMap(StationMapLink(stationId: station.id)))
                    }
                }
                // Just the star fills in, in the accent colour; the button around it stays as it is.
                Button { Task { await toggleFavorite() } } label: {
                    Group {
                        if favoriteOverride {
                            Image(systemName: "star.fill").font(.system(size: 20)).foregroundStyle(Ink.accent)
                        } else {
                            LucideIcon(name: "star", size: 20).foregroundStyle(Ink.text)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .background(Ink.surfaceRaised, in: Circle())
                    .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: favoriteOverride)
                .accessibilityLabel(l10n.t(favoriteOverride ? "stations.unfavorite" : "stations.favorite"))
                .accessibilityAddTraits(favoriteOverride ? .isSelected : [])
            }
        }
        .padding(.top, 12)
    }

    private func status(_ board: Board) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = context.date.timeIntervalSince1970 * 1000
            let fresh = now - board.updatedAt < 120_000
            let ago = LiveRules.ago(l10n, then: board.updatedAt, now: now)
            HStack(spacing: 6) {
                if fresh {
                    Chip(text: l10n.t("live.chip"), accent: true)
                } else {
                    Chip(text: l10n.t("live.stale", ["ago": ago]), tint: Ink.text3)
                }
                Text(l10n.t("live.updated", ["ago": ago])).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let station, !station.hasBoard {
            Text(l10n.t("board.noBoard")).clack(.body).foregroundStyle(Ink.text2)
        } else if station != nil {
            if let board {
                if !filter.showEarlier {
                    Button(l10n.t("board.showEarlier")) { Task { await loadEarlier() } }.buttonStyle(LinkButtonStyle())
                }
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let now = context.date.timeIntervalSince1970 * 1000
                    let source = (filter.showEarlier ? earlier ?? [] : []) + board.rows + (later ?? [])
                    let page = BoardLogic.page(source, now: now, filter: filter, limit: limit, reach: Self.reachMs)
                    VStack(spacing: 0) {
                        if page.shown.isEmpty {
                            Text(l10n.t("board.empty")).clack(.body).foregroundStyle(Ink.text2)
                                .frame(maxWidth: .infinity).padding(.vertical, 24)
                        }
                        ForEach(page.shown) { row in
                            BoardRowView(row: row, arrivals: arrivals, now: now, tz: tz) { open(row) }
                            Divider().overlay(Ink.hairline)
                        }
                        // More to show: from what's loaded, else (once) the hours from 12 to 24 ahead. Nothing past 24 h.
                        if page.more || (later == nil && !loadingLater) {
                            Button(l10n.t("board.showLater")) { Task { await showLater(more: page.more) } }
                                .buttonStyle(LinkButtonStyle())
                                .frame(maxWidth: .infinity).padding(.top, 14)
                        } else if loadingLater {
                            Skeleton(height: 48).padding(.top, 14)
                        }
                    }
                }
            } else if error {
                Banner(kind: .error) { Text(l10n.t("board.error")) }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Skeleton(height: 64)
                    Skeleton(height: 64)
                    Text(l10n.t("board.loading")).clack(.caption).foregroundStyle(Ink.text2)
                }
            }
        }
    }

    /// A row opens the train in Explore, the same view as tapping it on the map (looking, not following).
    private func open(_ row: BoardRow) {
        router.openTrain(number: row.trainNumber, date: row.trip?.serviceDate ?? Format.localDate(row.advertised, tz: "Europe/Stockholm"), key: row.trip?.key)
    }
}

private struct BoardRowView: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let row: BoardRow
    let arrivals: Bool
    let now: Double
    let tz: String
    let action: () -> Void

    var body: some View {
        let op = row.operatorId.flatMap { app.operatorsById[$0] }
        let type = row.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        let changed = BoardLogic.platformChanged(row, now: now)
        let moved = floor(row.shown / 60_000) != floor(row.advertised / 60_000)
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    SplitFlap(value: Format.time(row.shown, tz: tz, clock: app.settings.clock), size: .sm)
                    if moved {
                        Text(Format.time(row.advertised, tz: tz, clock: app.settings.clock)).strikethrough().clack(.caption).monospacedDigit().foregroundStyle(Ink.text3)
                    }
                }
                .frame(minWidth: 62, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.endpoints.isEmpty ? "—" : row.endpoints.joined(separator: ", ")).clack(.rowTitle).foregroundStyle(Ink.text)
                        .strikethrough(row.canceled)
                    if !row.via.isEmpty {
                        Text(l10n.t(arrivals ? "board.from" : "board.via", ["stops": row.via.joined(separator: ", ")])).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    HStack(spacing: 6) {
                        OperatorBadge(op: op, size: 18)
                        Text(([row.productName ?? op?.name, row.trainNumber].compactMap { $0 }).joined(separator: " ") + (type.map { " · \($0.name)" } ?? ""))
                            .clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
                    }
                    if !row.deviations.isEmpty {
                        Text(row.deviations.prefix(2).joined(separator: " · ")).clack(.caption).foregroundStyle(Ink.accentInk)
                    }
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    if let platform = row.platform {
                        PlatformChip(platform: platform, changedFrom: changed ? (row.platformChange?.from ?? "") : nil)
                    }
                    if changed { Text(l10n.t("board.changed")).clack(.caption).foregroundStyle(Ink.late) }
                    if row.canceled {
                        DelayText(delay: nil, canceled: true)
                    } else if let delay = row.delayMin, row.estimated != nil || row.actual != nil {
                        DelayText(delay: delay)
                    }
                    if row.done { Text(l10n.t(arrivals ? "board.arrived" : "board.departed")).clack(.caption).foregroundStyle(Ink.text2) }
                }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .opacity(BoardLogic.isPast(row, now: now) ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }
}
