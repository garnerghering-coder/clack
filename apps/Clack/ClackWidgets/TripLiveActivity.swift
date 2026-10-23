//
//  TripLiveActivity.swift
//  ClackWidgets
//

import ActivityKit
import SwiftUI
import WidgetKit

/// The trip you are on, on the lock screen and in the Dynamic Island (owner, 2026-10-23): where it's going, whether it
/// is late, the next stop, the platform, and a line along the route in the operator's colour. Status is written, not
/// boxed. The dark board look and the yellow accent follow DESIGN.md; the colours are copied from the app's assets
/// because the extension has no access to them.
private enum Board {
    static let bg = Color(red: 0x0A / 255, green: 0x0A / 255, blue: 0x0A / 255)
    static let text = Color.white
    static let text2 = Color(red: 0xA3 / 255, green: 0xA3 / 255, blue: 0xA3 / 255)
    static let track = Color.white.opacity(0.14)
    static let accent = Color(red: 0xF8 / 255, green: 0xD6 / 255, blue: 0x4A / 255)
    static let onTime = Color(red: 0x3D / 255, green: 0xDC / 255, blue: 0x84 / 255)
    static let late = Color(red: 0xFF / 255, green: 0x95 / 255, blue: 0x00 / 255)
    static let cancelled = Color(red: 0xFF / 255, green: 0x45 / 255, blue: 0x3A / 255)
}

/// The words, in the phone's language (the extension can't see the app's language setting).
private enum Words {
    private static var swedish: Bool { Locale.current.language.languageCode?.identifier == "sv" }
    static func t(_ en: String, _ sv: String) -> String { swedish ? sv : en }
    static var onTime: String { t("On time", "I tid") }
    static var cancelled: String { t("Cancelled", "Inställt") }
    static var arrived: String { t("Arrived", "Framme") }
    static var boarding: String { t("Boarding", "Påstigning") }
    static var onItsWay: String { t("On its way", "På väg") }
    static func late(_ n: Int) -> String { t("\(n) min late", "\(n) min försenat") }
    static func platform(_ p: String) -> String { t("Platform \(p)", "Spår \(p)") }
    static func next(_ s: String) -> String { t("Next: \(s)", "Nästa: \(s)") }
}

private extension Color {
    init?(hex: String?) {
        guard let hex, hex.hasPrefix("#"), hex.count == 7, let v = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

private func time(_ ms: Double?, tz: String) -> String {
    guard let ms else { return "–" }
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: tz) ?? .current
    return f.string(from: Date(timeIntervalSince1970: ms / 1000))
}

private func status(_ s: TripActivityAttributes.ContentState) -> (text: String, colour: Color) {
    if s.canceled || s.status == "cancelled" { return (Words.cancelled, Board.cancelled) }
    if s.status == "arrived" { return (Words.arrived, Board.onTime) }
    if let d = s.delayMin, d >= 5 { return (Words.late(d), d >= 16 ? Board.late : Board.accent) }
    if s.status == "approaching" { return (Words.onItsWay, Board.text) }
    if s.status == "boarding" { return (Words.boarding, Board.text) }
    return (Words.onTime, Board.onTime)
}

/// The line along the trip. With a position (`progress`) it is drawn there. Without one, a train that is running gets a bar that
/// fills by itself between its departure and arrival times, so it keeps moving between updates.
private struct RouteLine: View {
    let state: TripActivityAttributes.ContentState
    let colour: Color

    private var running: Bool { state.status == "en_route" || state.status == "at_stop" }

    private var window: ClosedRange<Date>? {
        guard let dep = state.departAt, let arr = state.arriveAt, arr > dep else { return nil }
        return Date(timeIntervalSince1970: dep / 1000)...Date(timeIntervalSince1970: arr / 1000)
    }

    var body: some View {
        Group {
            if state.progress == nil, running, let window {
                ProgressView(timerInterval: window, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(colour)
            } else {
                bar(state.progress ?? (state.status == "arrived" ? 1 : 0))
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private func bar(_ progress: Double) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Board.track).frame(height: 4)
                Capsule().fill(colour).frame(width: max(4, g.size.width * min(max(progress, 0), 1)), height: 4)
                Circle().fill(Board.text).frame(width: 10, height: 10)
                    .offset(x: min(max(g.size.width * progress - 5, 0), g.size.width - 10))
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// The route drawn as a line (no map tiles: a Live Activity can't hold a live map), with the stretch travelled in the operator's
/// colour, the stations at its ends and the train as a dot where it is.
private struct RouteSketch: View {
    let route: [[Double]]
    let progress: Double
    let colour: Color

    var body: some View {
        GeometryReader { g in
            let points = project(in: g.size)
            ZStack {
                Path { p in
                    guard let first = points.first else { return }
                    p.move(to: first)
                    points.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(Board.track, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                Path { p in
                    let part = travelled(points)
                    guard let first = part.first else { return }
                    p.move(to: first)
                    part.dropFirst().forEach { p.addLine(to: $0) }
                }
                .stroke(colour, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                if let start = points.first { Circle().fill(Board.text2).frame(width: 7, height: 7).position(start) }
                if let end = points.last { Circle().strokeBorder(Board.text, lineWidth: 2).background(Circle().fill(Board.bg)).frame(width: 10, height: 10).position(end) }
                if let train = trainPoint(points) {
                    Circle().fill(colour).frame(width: 12, height: 12).overlay(Circle().strokeBorder(Board.text, lineWidth: 2)).position(train)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// The route fitted to the box, true to shape (east-west is stretched by the latitude), with a small margin.
    private func project(in size: CGSize) -> [CGPoint] {
        guard route.count > 1, size.width > 0, size.height > 0 else { return [] }
        let lats = route.map { $0[0] }, lons = route.map { $0[1] }
        let k = cos((lats.reduce(0, +) / Double(lats.count)) * .pi / 180)
        let w = max((lons.max()! - lons.min()!) * k, 0.0001), h = max(lats.max()! - lats.min()!, 0.0001)
        let pad = 8.0
        let scale = min((size.width - 2 * pad) / w, (size.height - 2 * pad) / h)
        let ox = (size.width - w * scale) / 2, oy = (size.height - h * scale) / 2
        return route.map { CGPoint(x: ox + ($0[1] - lons.min()!) * k * scale, y: oy + (lats.max()! - $0[0]) * scale) }
    }

    private func lengths(_ pts: [CGPoint]) -> (cum: [Double], total: Double) {
        var cum = [0.0]
        for i in 1..<pts.count { cum.append(cum[i - 1] + Double(hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y))) }
        return (cum, cum.last ?? 0)
    }

    private func at(_ pts: [CGPoint], _ d: Double) -> (point: CGPoint, index: Int) {
        let (cum, total) = lengths(pts)
        let target = min(max(d, 0), total)
        var i = 1
        while i < pts.count - 1, cum[i] < target { i += 1 }
        let span = cum[i] - cum[i - 1]
        let t = span > 0 ? (target - cum[i - 1]) / span : 0
        return (CGPoint(x: pts[i - 1].x + (pts[i].x - pts[i - 1].x) * t, y: pts[i - 1].y + (pts[i].y - pts[i - 1].y) * t), i)
    }

    private func trainPoint(_ pts: [CGPoint]) -> CGPoint? {
        guard pts.count > 1 else { return nil }
        return at(pts, lengths(pts).total * min(max(progress, 0), 1)).point
    }

    private func travelled(_ pts: [CGPoint]) -> [CGPoint] {
        guard pts.count > 1 else { return [] }
        let (point, i) = at(pts, lengths(pts).total * min(max(progress, 0), 1))
        return Array(pts[..<i]) + [point]
    }
}

private struct LockScreen: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState

    var body: some View {
        let s = status(state)
        let line = Color(hex: attributes.color) ?? Board.accent
        let sketch = (attributes.route?.count ?? 0) > 1
        // A Lock Screen card is at most about 160 points tall: the text on the left, the picture and sketch in a column on the right.
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(attributes.from) → \(attributes.to)")
                        .font(.custom("InterVariable", size: 16).weight(.heavy))
                        .foregroundStyle(Board.text).lineLimit(1).minimumScaleFactor(0.7)
                    if let train = attributes.train {
                        Text(train).font(.custom("SpaceGrotesk-Bold", size: 15)).foregroundStyle(Board.text2)
                    }
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(s.text).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(s.colour)
                    if let next = state.nextStop, state.status == "en_route" || state.status == "at_stop" {
                        Text("·").foregroundStyle(Board.text2)
                        Text(Words.next(next)).font(.custom("InterVariable", size: 14)).foregroundStyle(Board.text2).lineLimit(1)
                    }
                }
                if !sketch { RouteLine(state: state, colour: line) }
                HStack {
                    Text(time(state.departAt, tz: attributes.fromTz)).font(.custom("SpaceGrotesk-Bold", size: 18)).foregroundStyle(Board.text)
                    Spacer(minLength: 6)
                    if let p = state.platform {
                        Text(Words.platform(p)).font(.custom("InterVariable", size: 13).weight(.bold)).foregroundStyle(Board.accent)
                    }
                    Spacer(minLength: 6)
                    Text(time(state.arriveAt, tz: attributes.toTz)).font(.custom("SpaceGrotesk-Bold", size: 18)).foregroundStyle(Board.text)
                }
            }
            if attributes.art != nil || sketch {
                VStack(spacing: 6) {
                    if let art = attributes.art {
                        Image(art).resizable().scaledToFit().frame(height: sketch ? 26 : 38)
                    }
                    if sketch, let route = attributes.route {
                        RouteSketch(route: route, progress: state.progress ?? (state.status == "arrived" ? 1 : 0), colour: line)
                            .frame(width: 84, height: attributes.art != nil ? 70 : 84)
                    }
                }
                .frame(width: 84)
            }
        }
        .padding(14)
    }
}

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            LockScreen(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(Board.bg)
                .activitySystemActionForegroundColor(Board.accent)
        } dynamicIsland: { context in
            let s = status(context.state)
            let line = Color(hex: context.attributes.color) ?? Board.accent
            return DynamicIsland {
                // Beside the camera: only small things (the camera cut-out hides anything wide). The destination goes below it.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "tram.fill").font(.system(size: 17)).foregroundStyle(Board.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if let p = context.state.platform {
                        Text(p).font(.custom("SpaceGrotesk-Bold", size: 20)).foregroundStyle(Board.accent)
                            .accessibilityLabel(Words.platform(p))
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.to).font(.custom("InterVariable", size: 16).weight(.heavy)).foregroundStyle(Board.text).lineLimit(1).minimumScaleFactor(0.7)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(s.text).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(s.colour)
                        RouteLine(state: context.state, colour: line)
                        HStack {
                            Text(time(context.state.departAt, tz: context.attributes.fromTz))
                            Spacer()
                            if let next = context.state.nextStop, context.state.status == "en_route" || context.state.status == "at_stop" { Text(next).lineLimit(1) }
                            Spacer()
                            Text(time(context.state.arriveAt, tz: context.attributes.toTz))
                        }
                        .font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.text2)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "tram.fill").foregroundStyle(Board.accent)
            } compactTrailing: {
                Text(context.state.delayMin.map { $0 >= 5 ? "+\($0)" : "✓" } ?? "✓")
                    .font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(s.colour)
            } minimal: {
                Image(systemName: "tram.fill").foregroundStyle(s.colour)
            }
            .keylineTint(line)
            // Even margins, kept inside the island's rounded corners.
            .contentMargins([.leading, .trailing], 18, for: .expanded)
            .contentMargins(.bottom, 16, for: .expanded)
            .contentMargins(.top, 6, for: .expanded)
        }
    }
}

#if DEBUG
private let previewAttributes = TripActivityAttributes(legId: "preview", journeyId: nil, train: "547", from: "Stockholm C", to: "Malmö C", fromTz: "Europe/Stockholm", toTz: "Europe/Stockholm", color: "#2ea44f")
private func previewState(_ status: String, delay: Int?, progress: Double?) -> TripActivityAttributes.ContentState {
    let now = Date().timeIntervalSince1970 * 1000
    return .init(status: status, delayMin: delay, nextStop: "Hässleholm C", nextStopAt: now + 14 * 60_000, platform: "3", platformFor: "arrival", progress: progress, departAt: now - 120 * 60_000, arriveAt: now + 90 * 60_000, canceled: false)
}

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    previewState("en_route", delay: 0, progress: 0.6)
    previewState("en_route", delay: 12, progress: nil)
    previewState("approaching", delay: 9, progress: 0)
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    previewState("en_route", delay: 12, progress: 0.6)
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    TripLiveActivity()
} contentStates: {
    previewState("en_route", delay: 12, progress: 0.6)
}
#endif
