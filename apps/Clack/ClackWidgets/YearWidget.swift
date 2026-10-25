//
//  YearWidget.swift
//  ClackWidgets
//
//  The year in rail: totals, top route, busiest month and every ride drawn on one map (`YearWidgetView`, ClackDesign).
//

import ClackCore
import ClackDesign
import SwiftUI
import UIKit
import WidgetKit

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.year, provider: PassportProvider()) { entry in
            YearWidgetView(snapshot: entry.snapshot, date: entry.date, isPlaceholder: entry.isPlaceholder, mapImage: { dark in
                Self.map(for: entry.snapshot, dark: dark)
            })
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(WidgetLinks.passport)
        }
        .configurationDisplayName(WidgetWords.t("widgets.year.name"))
        .description(WidgetWords.t("widgets.year.description"))
        .supportedFamilies([.systemLarge])
    }

    /// The map the app drew for these routes, if it is there.
    private static func map(for snapshot: WidgetSnapshot, dark: Bool) -> Image? {
        guard let year = snapshot.year, let url = WidgetMaps.url(key: WidgetMaps.key(year), dark: dark),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        return Image(uiImage: image)
    }
}
