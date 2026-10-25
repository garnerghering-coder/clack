//
//  StatsWidget.swift
//  ClackWidgets
//
//  The Passport tab's rankings as pages (`StatsWidgetView`, ClackDesign). A widget can't scroll, so a button flips the
//  page (an App Intent). The page is kept in the widget's own UserDefaults, which needs no App Group.
//

import AppIntents
import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

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
            StatsView(entry: entry)
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
    var entry: PassportEntry

    var body: some View {
        StatsWidgetView(
            snapshot: entry.snapshot, date: entry.date, size: family.homeSize ?? .medium, page: .current, isPlaceholder: entry.isPlaceholder
        ) {
            Button(intent: NextStatsPageIntent()) { StatsWidgetView<EmptyView>.buttonFace }
                .buttonStyle(.plain)
                .accessibilityLabel(WidgetWords.l10n(entry.snapshot.language).t("widgets.nextPage"))
        }
    }
}
