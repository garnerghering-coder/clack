//
//  DeparturesWidget.swift
//  ClackWidgets
//
//  A station's departures as board rows. The station is chosen in the widget's settings (an App Intent): with nothing
//  typed, your favourites, the stations you looked at lately and the big stations; typing searches every station by
//  name (the Stations screen's search). Each list comes from the server, else from the copy the app keeps in the App
//  Group (`WidgetStations`). The widget fetches the board itself, drops each train as it leaves, and fetches again after
//  15 minutes. The view is `DeparturesWidgetView` (ClackDesign, shared with the app's debug gallery).
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

    init(id: String, name: String) {
        self.id = id
        self.name = name
    }

    init(_ station: WidgetStations.Station) { self.init(id: station.id, name: station.name) }
}

struct StationQuery: EntityStringQuery {
    /// Favourites, recent and big stations, each under its heading (in the app's language).
    func suggestedEntities() async throws -> IntentItemCollection<StationOption> {
        let lists = await WidgetData.stationLists()
        var sections: [IntentItemSection<StationOption>] = []
        for (kind, stations) in lists.sections {
            let title = await MainActor.run { WidgetWords.t(kind.titleKey) }
            sections.append(IntentItemSection(LocalizedStringResource(stringLiteral: title), items: stations.map(StationOption.init)))
        }
        return IntentItemCollection(sections: sections)
    }

    /// Search as you type; with nothing typed, the lists.
    func entities(matching string: String) async throws -> IntentItemCollection<StationOption> {
        let text = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return try await suggestedEntities() }
        return IntentItemCollection(items: await WidgetData.searchStations(text).map(StationOption.init))
    }

    func entities(for identifiers: [String]) async throws -> [StationOption] {
        var out: [StationOption] = []
        for id in identifiers {
            if let station = await WidgetData.station(id) { out.append(StationOption(station)) }
        }
        return out
    }

    /// Before one is chosen: the first favourite.
    func defaultResult() async -> StationOption? {
        let lists = WidgetStations.load() ?? WidgetStations()
        if let first = lists.favourites.first { return StationOption(first) }
        return await WidgetData.stationLists().favourites.first.map(StationOption.init)
    }
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
                .widgetPadding()
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(entry.stationId.flatMap { WidgetLinks.board($0) })
        }
        .configurationDisplayName(WidgetWords.t("widgets.departures.name"))
        .description(WidgetWords.t("widgets.departures.description"))
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
        .freshnessPushHandler()
    }
}

private struct DeparturesView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DeparturesEntry

    var body: some View {
        DeparturesWidgetView(
            date: entry.date, size: family.homeSize ?? .medium, stationId: entry.stationId, stationName: entry.stationName,
            board: entry.board, language: entry.language, clock: entry.clock, isPlaceholder: entry.isPlaceholder
        )
    }
}
