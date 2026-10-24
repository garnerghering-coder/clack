//
//  DeparturesWidget.swift
//  ClackWidgets
//
//  A station's departures as board rows. The station is chosen in the widget's settings (an App Intent): your favourite
//  stations, or any station found by name (the Stations screen's search). The widget fetches the board itself, drops each
//  train as it leaves, and fetches again after 15 minutes.
//

import AppIntents
import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

struct StationOption: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Station")
    static let defaultQuery = StationQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct StationQuery: EntityStringQuery {
    /// Your favourite stations (`GET /api/stations/favorites`); offline, the stations whose boards are kept.
    private func favourites() async -> [StationOption] {
        if let client = WidgetData.client(), let hits = try? await client.favoriteStations() {
            return hits.map { StationOption(id: $0.id, name: $0.name) }
        }
        return (WidgetSnapshot.load()?.boards ?? []).map { StationOption(id: $0.id, name: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [StationOption] {
        let known = await favourites() + (WidgetSnapshot.load()?.boards ?? []).map { StationOption(id: $0.id, name: $0.name) }
        var out: [StationOption] = []
        for id in identifiers {
            if let hit = known.first(where: { $0.id == id }) {
                out.append(hit)
            } else if let client = WidgetData.client(), let info = try? await client.station(id) {
                out.append(StationOption(id: info.id, name: info.name))
            }
        }
        return out
    }

    func entities(matching string: String) async throws -> [StationOption] {
        let text = string.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let client = WidgetData.client() else { return await favourites() }
        return ((try? await client.searchStations(text)) ?? []).map { StationOption(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [StationOption] { await favourites() }
    func defaultResult() async -> StationOption? { await favourites().first }
}

struct PickStationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Station"
    static let description = IntentDescription("The station whose departures to show.")
    @Parameter(title: "Station") var station: StationOption?
}

struct DeparturesEntry: TimelineEntry {
    var date: Date
    var stationId: String?
    var stationName: String?
    var board: WidgetSnapshot.StationBoard?
    var language: Language
    var clock: ClockFormat
    var isPlaceholder = false
}

struct DeparturesProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> DeparturesEntry {
        let s = WidgetSnapshot.placeholder(now: .now)
        return DeparturesEntry(date: .now, stationId: nil, board: s.boards.first, language: WidgetWords.language, clock: .h24, isPlaceholder: true)
    }

    private func cached(_ configuration: PickStationIntent) -> DeparturesEntry? {
        guard let s = WidgetSnapshot.load() else { return nil }
        let board = configuration.station.flatMap { option in s.boards.first { $0.id == option.id } } ?? s.boards.first
        guard let board else { return nil }
        return DeparturesEntry(date: .now, stationId: board.id, stationName: configuration.station?.name, board: board, language: s.language, clock: s.clock)
    }

    func snapshot(for configuration: PickStationIntent, in context: Context) async -> DeparturesEntry {
        cached(configuration) ?? placeholder(in: context)
    }

    func timeline(for configuration: PickStationIntent, in context: Context) async -> Timeline<DeparturesEntry> {
        let now = Date.now
        var station = configuration.station
        if station == nil { station = await StationQuery().defaultResult() }
        guard let station else {
            let s = WidgetSnapshot.load() ?? WidgetSnapshot()
            let empty = DeparturesEntry(date: now, stationId: nil, board: nil, language: s.language, clock: s.clock)
            return Timeline(entries: [empty], policy: .after(now.addingTimeInterval(WidgetTimeline.departuresReloadMs / 1000)))
        }
        let snapshot = await WidgetData.load(.boards, boards: [station.id], maxAge: 60_000)
        let board = snapshot.boards.first { $0.id == station.id }
        let entries = WidgetTimeline.departureEntries(now: wMs(now)).map { at in
            DeparturesEntry(
                date: wDate(at), stationId: station.id, stationName: station.name, board: board, language: snapshot.language, clock: snapshot.clock
            )
        }
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(WidgetTimeline.departuresReloadMs / 1000)))
    }
}

struct DeparturesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.departures, intent: PickStationIntent.self, provider: DeparturesProvider()) { entry in
            DeparturesView(entry: entry)
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(entry.stationId.flatMap { WidgetLinks.board($0) })
        }
        .configurationDisplayName(WidgetWords.t("widgets.departures.name"))
        .description(WidgetWords.t("widgets.departures.description"))
        .supportedFamilies([.systemMedium, .systemLarge])
        .freshnessPushHandler()
    }
}

private struct DeparturesView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DeparturesEntry

    private var l10n: L10n { WidgetWords.l10n(entry.language) }

    var body: some View {
        Group {
            if let board = entry.board {
                let rows = WidgetTimeline.departures(board.rows, at: wMs(entry.date), limit: family == .systemLarge ? 8 : 4)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.stationName ?? board.name).clack(.boardDestination).foregroundStyle(Ink.text).lineLimit(1)
                        Spacer(minLength: 6)
                        UpdatedLine(updatedAt: board.updatedAt, now: entry.date, l10n: l10n, clock: entry.clock)
                    }
                    ForEach(rows) { row in
                        HStack(spacing: 8) {
                            FlapText(text: Format.time(row.time, tz: board.tz ?? TimeZone.current.identifier, clock: entry.clock))
                            Text(row.to).clack(.stopName).fontWeight(.semibold).foregroundStyle(Ink.text).lineLimit(1)
                                .strikethrough(row.canceled)
                            Spacer(minLength: 4)
                            DelayText(delay: row.delayMin, canceled: row.canceled)
                            if let p = row.platform {
                                Text(p).clack(.delay).monospacedDigit().foregroundStyle(Ink.text2).frame(minWidth: 20, alignment: .trailing)
                            }
                        }
                    }
                    if rows.isEmpty { Text(l10n.t("board.empty")).clack(.caption).foregroundStyle(Ink.text2) }
                    Spacer(minLength: 0)
                }
            } else if entry.stationId != nil {
                EmptyWidget(title: entry.stationName ?? l10n.t("board.departures"), hint: l10n.t("board.error"))
            } else {
                EmptyWidget(title: l10n.t("widgets.pickStation"), hint: l10n.t("widgets.pickStationHint"))
            }
        }
        .environment(l10n)
        .placeholder(entry.isPlaceholder)
    }
}
