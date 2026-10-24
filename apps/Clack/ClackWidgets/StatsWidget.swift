//
//  StatsWidget.swift
//  ClackWidgets
//
//  The Passport tab's rankings as pages: operators, train types, stations, countries. A widget can't scroll, so a button flips the
//  page (an App Intent). The page is kept in the widget's own UserDefaults, which needs no App Group.
//

import AppIntents
import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

enum StatsPage: Int, CaseIterable {
    case operators, trainTypes, stations, countries

    var titleKey: String {
        switch self {
        case .operators: "passport.operators"
        case .trainTypes: "passport.trainTypes"
        case .stations: "passport.stationsVisited"
        case .countries: "passport.countries"
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

struct StatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.stats, provider: PassportProvider()) { entry in
            StatsView(entry: entry, page: .current)
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(WidgetLinks.passport)
        }
        .configurationDisplayName(WidgetWords.t("widgets.stats.name"))
        .description(WidgetWords.t("widgets.stats.description"))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

private struct StatsView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    var entry: PassportEntry
    var page: StatsPage

    private var l10n: L10n { WidgetWords.l10n(entry.snapshot.language) }

    var body: some View {
        Group {
            if let stats = entry.snapshot.stats {
                content(stats)
            } else {
                EmptyWidget(title: l10n.t("passport.emptyTitle"), hint: l10n.t("widgets.openApp"))
            }
        }
        .environment(l10n)
        .placeholder(entry.isPlaceholder)
    }

    private func content(_ stats: WidgetSnapshot.StatsBits) -> some View {
        let rows = Array(page.rows(stats).prefix(family == .systemLarge ? 8 : 3))
        let top = max(1, rows.map(\.count).max() ?? 1)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(l10n.t(page.titleKey)).clack(.sectionHeader).foregroundStyle(Ink.text)
                Spacer()
                UpdatedLine(updatedAt: entry.snapshot.passportUpdatedAt, now: entry.date, l10n: l10n, clock: entry.snapshot.clock)
                HStack(spacing: 4) {
                    ForEach(StatsPage.allCases, id: \.rawValue) { p in
                        Circle().fill(p == page ? Ink.accentInk : Ink.text3).frame(width: 5, height: 5)
                    }
                }
                Button(intent: NextStatsPageIntent()) {
                    LucideIcon(name: "chevron-right", size: 14).foregroundStyle(Ink.text)
                        .frame(width: 30, height: 24)
                        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("widgets.nextPage"))
            }
            ForEach(rows) { row in
                HStack(spacing: 8) {
                    Text(row.name).clack(.chip).foregroundStyle(Ink.text).lineLimit(1).frame(width: 104, alignment: .leading)
                    GeometryReader { p in
                        RoundedRectangle(cornerRadius: Radius.bar)
                            .fill(operatorColor(row.color, scheme: scheme))
                            .frame(width: max(3, p.size.width * Double(row.count) / Double(top)))
                    }
                    .frame(height: 10)
                    Text(String(row.count)).clack(.delay).monospacedDigit().foregroundStyle(Ink.text).frame(minWidth: 26, alignment: .trailing)
                }
            }
            if rows.isEmpty { Text(l10n.t("passport.empty")).clack(.caption).foregroundStyle(Ink.text2) }
            Spacer(minLength: 0)
        }
    }
}
