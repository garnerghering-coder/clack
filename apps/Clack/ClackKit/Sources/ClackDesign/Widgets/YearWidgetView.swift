//
//  YearWidgetView.swift
//  ClackDesign
//
//  The year in rail: totals, every ride drawn on one map, the top route and the busiest month (each on its own line, so
//  a long route name has the full width).
//

import ClackCore
import SwiftUI

/// All the rides, in equirectangular projection fitted to the box (longitudes scaled by the cosine of the middle latitude).
public struct RoutesMap: View {
    var routes: [[[Double]]]
    var color: Color

    public init(routes: [[[Double]]], color: Color) {
        self.routes = routes
        self.color = color
    }

    public var body: some View {
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

public struct YearWidgetView: View {
    var snapshot: WidgetSnapshot
    var date: Date
    var isPlaceholder: Bool
    /// The real map the app drew behind the routes (dark or light), when there is one for these routes.
    var mapImage: (Bool) -> Image?
    @Environment(\.colorScheme) private var scheme

    public init(snapshot: WidgetSnapshot, date: Date, isPlaceholder: Bool = false, mapImage: @escaping (Bool) -> Image? = { _ in nil }) {
        self.snapshot = snapshot
        self.date = date
        self.isPlaceholder = isPlaceholder
        self.mapImage = mapImage
    }

    private var l10n: L10n { WidgetWords.l10n(snapshot.language) }

    public var body: some View {
        Group {
            if let y = snapshot.year {
                content(y)
            } else {
                EmptyWidget(title: l10n.t("widgets.year.name"), hint: l10n.t("widgets.openApp"))
            }
        }
        .environment(l10n)
        .placeholder(isPlaceholder)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                Text(value).clack(.walkBig).lineLimit(1).fixedSize()
                Text(value).clack(.bigUnit).lineLimit(1).fixedSize()
                Text(value).clack(.bigUnit).lineLimit(2).minimumScaleFactor(WidgetInsets.minimumScale)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Ink.text)
            FittingText(label).clack(.captionUpper).foregroundStyle(Ink.text2)
        }
    }

    /// "March 2026" from `2026-03`.
    private func month(_ iso: String) -> String? {
        Format.isoToNoonMs("\(iso)-15").map { Format.month($0, tz: TimeZone.current.identifier, language: snapshot.language) }
    }

    private func content(_ y: WidgetSnapshot.YearBits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    Text(l10n.t("widgets.yearTitle", ["year": String(y.year)])).clack(.sectionHeader).foregroundStyle(Ink.text).fixedSize()
                    Spacer(minLength: 0)
                    UpdatedLine(updatedAt: snapshot.passportUpdatedAt, now: date, l10n: l10n, clock: snapshot.clock)
                }
                VStack(alignment: .leading, spacing: 0) {
                    FittingText(l10n.t("widgets.yearTitle", ["year": String(y.year)])).clack(.sectionHeader).foregroundStyle(Ink.text)
                    UpdatedLine(updatedAt: snapshot.passportUpdatedAt, now: date, l10n: l10n, clock: snapshot.clock)
                }
            }
            HStack(alignment: .top, spacing: 24) {
                stat(Format.distance(y.km * 1000, unit: snapshot.distanceUnit, language: snapshot.language), l10n.t("widgets.distance"))
                stat(String(y.trains), l10n.t("passport.trains"))
            }
            Group {
                if let map = mapImage(scheme == .dark) {
                    // The routes are already on this map; it is cut to the box.
                    Color.clear.overlay { map.resizable().scaledToFill() }.clipped()
                } else {
                    RoutesMap(routes: y.routes, color: Ink.accentInk)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            if let route = y.topRoute { stat(route, l10n.t("widgets.topRoute", ["count": String(y.topRouteCount)])) }
            if let iso = y.busiestMonth, let name = month(iso) {
                stat(name, l10n.t("widgets.busiestMonth", ["count": String(y.busiestMonthCount)]))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
