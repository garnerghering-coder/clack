//
//  YearWidget.swift
//  ClackWidgets
//
//  The year in rail: totals, top route, busiest month and every ride drawn on one map.
//

import ClackCore
import SwiftUI
import WidgetKit

struct YearEntry: TimelineEntry {
    var date: Date
    var year: WidgetSnapshot.YearBits
    var isSample: Bool
}

struct YearProvider: TimelineProvider {
    private func entry() -> YearEntry {
        let c = WidgetContent.current()
        return YearEntry(date: .now, year: c.snapshot.year ?? SampleData.snapshot(now: .now).year!, isSample: c.isSample || c.snapshot.year == nil)
    }
    func placeholder(in context: Context) -> YearEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (YearEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<YearEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(6 * 3600))))
    }
}

struct YearWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "YearInRail", provider: YearProvider()) { entry in
            YearView(entry: entry)
                .containerBackground(WB.bg, for: .widget)
                .widgetURL(URL(string: "clack://tab/passport"))
        }
        .configurationDisplayName(WW.yearInRail)
        .description(WW.t("This year's totals and every ride on one map.", "Årets summor och varje resa på en karta."))
        .supportedFamilies([.systemLarge])
    }
}

/// All the rides, in equirectangular projection fitted to the box (longitudes scaled by the cosine of the middle latitude).
struct RoutesMap: View {
    var routes: [[[Double]]]
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
                ctx.stroke(path, with: .color(WB.accent.opacity(0.8)), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct YearView: View {
    var entry: YearEntry
    private var y: WidgetSnapshot.YearBits { entry.year }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(WB.digits(22)).foregroundStyle(WB.text).lineLimit(1).minimumScaleFactor(0.6)
            Text(label.uppercased()).font(WB.inter(9, .heavy)).tracking(0.8).foregroundStyle(WB.text2)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(WW.yearInRail) \(String(y.year))").font(WB.inter(14, .heavy)).foregroundStyle(WB.accent)
                Spacer()
                if entry.isSample { SampleTag() }
            }
            HStack(spacing: 24) {
                stat(Int(y.km.rounded()).formatted(), WW.km)
                stat(String(y.trains), WW.trains)
            }
            RoutesMap(routes: y.routes)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(WB.tile, in: RoundedRectangle(cornerRadius: 8))
            HStack(alignment: .top, spacing: 16) {
                if let route = y.topRoute { stat(route, "\(WW.topRoute) · \(y.topRouteCount)×") }
                if let month = y.busiestMonth { stat(month, "\(WW.busiestMonth) · \(y.busiestMonthCount)") }
            }
        }
    }
}
