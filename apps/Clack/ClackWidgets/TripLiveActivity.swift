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

private struct LockScreen: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState

    var body: some View {
        let s = status(state)
        let line = Color(hex: attributes.color) ?? Board.accent
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(attributes.from) → \(attributes.to)")
                    .font(.custom("InterVariable", size: 16).weight(.heavy))
                    .foregroundStyle(Board.text).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if let train = attributes.train {
                    Text(train).font(.custom("SpaceGrotesk-Bold", size: 15)).foregroundStyle(Board.text2)
                }
            }
            HStack(alignment: .firstTextBaseline) {
                Text(s.text).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(s.colour)
                if let next = state.nextStop, state.status == "en_route" || state.status == "at_stop" {
                    Text("·").foregroundStyle(Board.text2)
                    Text(Words.next(next)).font(.custom("InterVariable", size: 14)).foregroundStyle(Board.text2).lineLimit(1)
                    if let at = state.nextStopAt { Text(time(at, tz: attributes.toTz)).font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.text2) }
                }
            }
            RouteLine(state: state, colour: line)
            HStack {
                Text(time(state.departAt, tz: attributes.fromTz)).font(.custom("SpaceGrotesk-Bold", size: 18)).foregroundStyle(Board.text)
                Spacer()
                if let p = state.platform {
                    Text(Words.platform(p)).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(Board.accent)
                }
                Spacer()
                Text(time(state.arriveAt, tz: attributes.toTz)).font(.custom("SpaceGrotesk-Bold", size: 18)).foregroundStyle(Board.text)
            }
        }
        .padding(16)
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
