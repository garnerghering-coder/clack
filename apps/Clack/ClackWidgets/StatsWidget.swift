//
//  StatsWidget.swift
//  ClackWidgets
//
//  The Passport tab's rankings as pages: operators, train types, stations, countries. A widget can't scroll, so a button flips the
//  page (an App Intent). The page is kept in the widget's own UserDefaults, which needs no App Group.
//

import AppIntents
import SwiftUI
import WidgetKit

enum StatsPage: Int, CaseIterable {
    case operators, trainTypes, stations, countries
    var title: String {
        switch self {
        case .operators: WW.operators
        case .trainTypes: WW.trainTypes
        case .stations: WW.topStations
        case .countries: WW.countries
        }
    }
    func rows(_ s: WidgetSnapshot.StatsBits) -> [WidgetSnapshot.Row] {
        switch self {
        case .operators: s.operators
        case .trainTypes: s.trainTypes
        case .stations: s.stations
        case .countries: s.countries
        }
    }
    static var current: StatsPage {
        get { StatsPage(rawValue: UserDefaults.standard.integer(forKey: "statsPage")) ?? .operators }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "statsPage") }
    }
}

struct NextStatsPageIntent: AppIntent {
    static let title: LocalizedStringResource = "Next page"
    func perform() async throws -> some IntentResult {
        StatsPage.current = StatsPage(rawValue: (StatsPage.current.rawValue + 1) % StatsPage.allCases.count) ?? .operators
        return .result()
    }
}

struct StatsEntry: TimelineEntry {
    var date: Date
    var stats: WidgetSnapshot.StatsBits
    var page: StatsPage
    var isSample: Bool
}

struct StatsProvider: TimelineProvider {
    private func entry() -> StatsEntry {
        let c = WidgetContent.current()
        return StatsEntry(date: .now, stats: c.snapshot.stats ?? SampleData.snapshot(now: .now).stats!, page: .current, isSample: c.isSample || c.snapshot.stats == nil)
    }
    func placeholder(in context: Context) -> StatsEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct StatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Stats", provider: StatsProvider()) { entry in
            StatsView(entry: entry)
                .containerBackground(WB.bg, for: .widget)
        }
        .configurationDisplayName(WW.t("Stats", "Statistik"))
        .description(WW.t("Operators, train types, stations and countries. Tap the arrow for the next page.", "Operatörer, tågtyper, stationer och länder. Tryck på pilen för nästa sida."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct StatsView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StatsEntry

    var body: some View {
        let rows = Array(entry.page.rows(entry.stats).prefix(family == .systemLarge ? 8 : 3))
        let top = max(1, rows.map(\.count).max() ?? 1)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.page.title).font(WB.inter(14, .heavy)).foregroundStyle(WB.accent)
                if entry.isSample { SampleTag() }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(StatsPage.allCases, id: \.rawValue) { p in
                        Circle().fill(p == entry.page ? WB.accent : WB.text2.opacity(0.4)).frame(width: 5, height: 5)
                    }
                }
                Button(intent: NextStatsPageIntent()) {
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(WB.text)
                        .frame(width: 28, height: 24).background(WB.tile, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.name).font(WB.inter(12, .semibold)).foregroundStyle(WB.text).lineLimit(1).frame(width: 96, alignment: .leading)
                    GeometryReader { p in
                        Rectangle().fill(Color(hex: row.color) ?? WB.accent)
                            .frame(width: max(3, p.size.width * Double(row.count) / Double(top)))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                    .frame(height: 12)
                    Text(String(row.count)).font(WB.digits(13)).foregroundStyle(WB.text).frame(minWidth: 26, alignment: .trailing)
                }
            }
            if rows.isEmpty { Text(WW.noData).font(WB.inter(12)).foregroundStyle(WB.text2) }
            Spacer(minLength: 0)
        }
    }
}
