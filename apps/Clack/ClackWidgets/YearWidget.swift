//
//  YearWidget.swift
//  ClackWidgets
//
//  The year in rail: totals, top route, busiest month and every ride drawn on one map.
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.year, provider: PassportProvider()) { entry in
            YearView(entry: entry)
                .containerBackground(Ink.bg, for: .widget)
                .widgetURL(WidgetLinks.passport)
        }
        .configurationDisplayName(WidgetWords.t("widgets.year.name"))
        .description(WidgetWords.t("widgets.year.description"))
        .supportedFamilies([.systemLarge])
    }
}

/// All the rides, in equirectangular projection fitted to the box (longitudes scaled by the cosine of the middle latitude).
struct RoutesMap: View {
    var routes: [[[Double]]]
    var color: Color

    var body: some View {
        Canvas { ctx, size in
            let points = routes.flatMap { $0 }.filter { $0.count == 2 }
            guard let minLat = points.map({ $0[0] }).min(), let maxLat = points.map({ $0[0] }).max(),
                  let minLon = points.map({ $0[1] }).min(), let maxLon = points.map({ $0[1] }).max() else { return }
            let k = cos((minLat + maxLat) / 2 * .pi / 180)
            let w = max(0.01, (maxLon - minLon) * k), h = max(0.01, maxLat - minLat)
            let scale = min((size.width - 16) / w, (size.height - 16) / h)
            let ox = (size.width - w * scale) / 2, oy = (size.height - h * scale) / 2
            func p(_ q: [Double]) -> CGPoint { CGPoint(x: ox + (q[1] - minLon) * k * scale, y: oy + (maxLat - q[0]) * scale) }
            for route in routes where route.count > 1 {
                var path = Path()
                path.move(to: p(route[0]))
                for q in route.dropFirst() where q.count == 2 { path.addLine(to: p(q)) }
                ctx.stroke(path, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct YearView: View {
    var entry: PassportEntry

    private var l10n: L10n { WidgetWords.l10n(entry.snapshot.language) }

    var body: some View {
        Group {
            if let y = entry.snapshot.year {
                content(y)
            } else {
                EmptyWidget(title: l10n.t("widgets.year.name"), hint: l10n.t("widgets.openApp"))
            }
        }
        .environment(l10n)
        .placeholder(entry.isPlaceholder)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).clack(.walkBig).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).clack(.captionUpper).foregroundStyle(Ink.text2).lineLimit(1)
        }
    }

    /// "March 2026" from `2026-03`.
    private func month(_ iso: String) -> String? {
        Format.isoToNoonMs("\(iso)-15").map { Format.month($0, tz: TimeZone.current.identifier, language: entry.snapshot.language) }
    }

    private func content(_ y: WidgetSnapshot.YearBits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n.t("widgets.yearTitle", ["year": String(y.year)])).clack(.sectionHeader).foregroundStyle(Ink.text)
                Spacer()
                UpdatedLine(updatedAt: entry.snapshot.passportUpdatedAt, now: entry.date, l10n: l10n, clock: entry.snapshot.clock)
            }
            HStack(spacing: 24) {
                stat(Format.distance(y.km * 1000, unit: entry.snapshot.distanceUnit, language: entry.snapshot.language), l10n.t("widgets.distance"))
                stat(String(y.trains), l10n.t("passport.trains"))
            }
            RoutesMap(routes: y.routes, color: Ink.accentInk)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            HStack(alignment: .top, spacing: 16) {
                if let route = y.topRoute { stat(route, l10n.t("widgets.topRoute", ["count": String(y.topRouteCount)])) }
                if let iso = y.busiestMonth, let name = month(iso) { stat(name, l10n.t("widgets.busiestMonth", ["count": String(y.busiestMonthCount)])) }
            }
        }
    }
}
