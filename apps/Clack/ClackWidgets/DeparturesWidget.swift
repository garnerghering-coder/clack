//
//  DeparturesWidget.swift
//  ClackWidgets
//
//  A favourite station's departures as board rows. The station is chosen in the widget's settings (an App Intent), from the stations
//  the app has put in the snapshot.
//

import AppIntents
import ClackCore
import SwiftUI
import WidgetKit

struct StationOption: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Station")
    static let defaultQuery = StationQuery()
    var id: String
    var name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct StationQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [StationOption] {
        all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [StationOption] { all() }
    func defaultResult() async -> StationOption? { all().first }
    private func all() -> [StationOption] {
        WidgetContent.current().snapshot.boards.map { StationOption(id: $0.id, name: $0.name) }
    }
}

struct PickStationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Station"
    static let description = IntentDescription("The station whose departures to show.")
    @Parameter(title: "Station") var station: StationOption?
}

struct DeparturesEntry: TimelineEntry {
    var date: Date
    var board: WidgetSnapshot.StationBoard?
    var isSample: Bool
}

struct DeparturesProvider: AppIntentTimelineProvider {
    private func entry(_ configuration: PickStationIntent) -> DeparturesEntry {
        let c = WidgetContent.current()
        let board = c.snapshot.boards.first { $0.id == configuration.station?.id } ?? c.snapshot.boards.first
        return DeparturesEntry(date: .now, board: board, isSample: c.isSample)
    }
    func placeholder(in context: Context) -> DeparturesEntry { entry(PickStationIntent()) }
    func snapshot(for configuration: PickStationIntent, in context: Context) async -> DeparturesEntry { entry(configuration) }
    func timeline(for configuration: PickStationIntent, in context: Context) async -> Timeline<DeparturesEntry> {
        // A new entry each 5 minutes drops departures that have left.
        let base = entry(configuration)
        let entries = (0..<12).map { i in DeparturesEntry(date: .now.addingTimeInterval(Double(i) * 300), board: base.board, isSample: base.isSample) }
        return Timeline(entries: entries, policy: .after(.now.addingTimeInterval(3600)))
    }
}

struct DeparturesWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Departures", intent: PickStationIntent.self, provider: DeparturesProvider()) { entry in
            DeparturesView(entry: entry)
                .containerBackground(WB.bg, for: .widget)
                .widgetURL(URL(string: "clack://tab/explore"))
        }
        .configurationDisplayName(WW.t("Departures", "Avgångar"))
        .description(WW.t("The departure board of a station you follow.", "Avgångstavlan för en station du följer."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct DeparturesView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DeparturesEntry

    var body: some View {
        if let board = entry.board {
            let now = entry.date.timeIntervalSince1970 * 1000
            let rows = board.rows.filter { $0.time > now - 60_000 }.prefix(family == .systemLarge ? 8 : 4)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(board.name).font(WB.inter(14, .heavy)).foregroundStyle(WB.accent).lineLimit(1)
                    Spacer()
                    if entry.isSample { SampleTag() }
                }
                ForEach(Array(rows)) { row in
                    HStack(spacing: 8) {
                        FlapText(text: wTime(row.time, tz: "Europe/Stockholm"), size: 14, color: (row.delayMin ?? 0) >= 1 ? WB.accent : WB.text)
                        Text(row.to).font(WB.inter(13, .semibold)).foregroundStyle(row.canceled ? WB.cancelled : WB.text).lineLimit(1)
                            .strikethrough(row.canceled)
                        Spacer(minLength: 4)
                        if row.canceled { Text(WW.cancelled).font(WB.inter(10, .bold)).foregroundStyle(WB.cancelled) }
                        else if let n = row.delayMin, n >= 1 { Text("+\(n)").font(WB.digits(12)).foregroundStyle(WB.late) }
                        if let p = row.platform { Text(p).font(WB.digits(14)).foregroundStyle(WB.text2).frame(minWidth: 18, alignment: .trailing) }
                    }
                }
                if rows.isEmpty { Text(WW.noData).font(WB.inter(12)).foregroundStyle(WB.text2) }
                Spacer(minLength: 0)
            }
        } else {
            EmptyWidget(title: WW.noBoard, hint: WW.noData)
        }
    }
}
