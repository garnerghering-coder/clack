//
//  YearWidget.swift
//  ClackWidgets
//
//  The year in rail: totals, top route, busiest month and every ride drawn on one map (`YearWidgetView`, ClackDesign).
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.year, provider: PassportProvider()) { entry in
            YearWidgetView(snapshot: entry.snapshot, date: entry.date, isPlaceholder: entry.isPlaceholder)
                .widgetPadding()
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(WidgetLinks.passport)
        }
        .configurationDisplayName(WidgetWords.t("widgets.year.name"))
        .description(WidgetWords.t("widgets.year.description"))
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}
