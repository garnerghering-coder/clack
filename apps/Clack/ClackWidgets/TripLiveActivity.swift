//
//  TripLiveActivity.swift
//  ClackWidgets
//

import ActivityKit
import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

/// The trip you are on, on the Lock Screen and in the Dynamic Island (owner, 2026-10-24). The Lock Screen card is one solid line
/// with the times and status; the island says what matters at that moment (the platform before you leave, the arrival time on the
/// way, the minutes left at the end, the next platform at a change). Status is written, not boxed. Colours are copied from the
/// app's assets because the extension can't read them.
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
    static var board: String { t("BOARD", "PÅ") }
    static var onItsWay: String { t("On its way", "På väg") }
    static var leavingSoon: String { t("Leaving soon", "Avgår snart") }
    static var getOff: String { t("Get off soon", "Kliv av snart") }
    static var change: String { t("Change trains", "Byte") }
    static func late(_ n: Int) -> String { t("\(n) min late", "\(n) min försenat") }
    static func platform(_ p: String) -> String { t("Platform \(p)", "Spår \(p)") }
    static func platformShort(_ p: String) -> String { t("Pl \(p)", "Sp \(p)") }
    static func platformChanged(_ p: String) -> String { t("Platform changed to \(p)", "Spårändring till \(p)") }
    static func next(_ s: String) -> String { t("Next: \(s)", "Nästa: \(s)") }
    static var estimated: String { t("Estimated", "Uppskattat") }
}

private func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

private func time(_ ms: Double?, tz: String) -> String {
    guard let ms else { return "–" }
    let f = DateFormatter()
    f.dateFormat = "HH:mm"
    f.timeZone = TimeZone(identifier: tz) ?? .current
    return f.string(from: date(ms))
}

/// The moment the trip is in: the server's word for it, or (from an older server) worked out from the status.
private func phase(_ s: TripActivityAttributes.ContentState) -> String {
    if let p = s.phase { return p }
    if s.canceled || s.status == "cancelled" { return "cancelled" }
    switch s.status {
    case "arrived": return "arrived"
    case "boarding": return "boarding"
    case "approaching": return "approaching"
    case "en_route", "at_stop": return "enRoute"
    default: return "scheduled"
    }
}

/// How late it is, if it is worth saying (5 minutes or more).
private func lateMin(_ s: TripActivityAttributes.ContentState) -> Int? {
    guard let d = s.delayMin, d >= 5 else { return nil }
    return d
}

private func status(_ s: TripActivityAttributes.ContentState) -> (text: String, colour: Color) {
    switch phase(s) {
    case "cancelled": return (Words.cancelled, Board.cancelled)
    case "arrived": return (Words.arrived, Board.onTime)
    case "changing": return (Words.change, Board.accent)
    case "getOffSoon": return (Words.getOff, Board.accent)
    default: break
    }
    if s.note == "platformChanged", let p = s.platform { return (Words.platformChanged(p), Board.accent) }
    if let d = lateMin(s) { return (Words.late(d), d >= 16 ? Board.late : Board.accent) }
    switch phase(s) {
    case "boarding": return (Words.boarding, Board.text)
    case "approaching": return (Words.onItsWay, Board.text)
    case "leaveSoon": return (Words.leavingSoon, Board.text)
    default: return (Words.onTime, Board.onTime)
    }
}

// MARK: the solid line

/// The line along the trip. With a position (`progress`) it is drawn there. Without one, a train that is running gets a bar that
/// fills by itself between its departure and arrival times, so it keeps moving between updates (and offline).
private struct RouteLine: View {
    let state: TripActivityAttributes.ContentState
    let colour: Color

    private var running: Bool { phase(state) == "enRoute" || phase(state) == "getOffSoon" }

    private var window: ClosedRange<Date>? {
        guard let dep = state.departAt, let arr = state.arriveAt, arr > dep else { return nil }
        return date(dep)...date(arr)
    }

    var body: some View {
        Group {
            if state.progress == nil, running, let window {
                ProgressView(timerInterval: window, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(colour)
            } else {
                bar(state.progress ?? (phase(state) == "arrived" ? 1 : 0))
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

// MARK: Lock Screen

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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(s.text).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(s.colour)
                if phase(state) == "changing", let p = state.changePlatform {
                    Text("·").foregroundStyle(Board.text2)
                    Text(Words.platform(p)).font(.custom("InterVariable", size: 14)).foregroundStyle(Board.text)
                    if let at = state.changeAt {
                        Text(timerInterval: Date.now...max(date(at), Date.now.addingTimeInterval(1)), countsDown: true)
                            .font(.custom("SpaceGrotesk-Bold", size: 14)).monospacedDigit().foregroundStyle(Board.text2)
                    }
                } else if let next = state.nextStop, ["enRoute", "getOffSoon", "approaching"].contains(phase(state)) {
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

// MARK: Dynamic Island

/// The small icon on the island's left.
private struct Glyph: View {
    let name: String
    var colour: Color = Board.accent
    var body: some View { Image(systemName: name).font(.system(size: 14, weight: .semibold)).foregroundStyle(colour) }
}

/// A ring that fills as the train goes, with the train inside it.
private struct ProgressRing: View {
    let progress: Double
    let colour: Color
    var body: some View {
        ZStack {
            Circle().stroke(Board.track, lineWidth: 2.5)
            Circle().trim(from: 0, to: min(max(progress, 0.02), 1)).stroke(colour, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
            Image(systemName: "tram.fill").font(.system(size: 9)).foregroundStyle(Board.text)
        }
        .frame(width: 22, height: 22)
    }
}

/// Counts down by itself to a time, in `m:ss` (or `h:mm:ss`).
private struct Countdown: View {
    let to: Double
    var colour: Color = Board.accent
    var body: some View {
        Text(timerInterval: Date.now...max(date(to), Date.now.addingTimeInterval(1)), countsDown: true, showsHours: false)
            .font(.custom("SpaceGrotesk-Bold", size: 14)).monospacedDigit().foregroundStyle(colour)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 52)
    }
}

private func timeText(_ ms: Double?, tz: String, late: Bool) -> some View {
    Text(time(ms, tz: tz)).font(.custom("SpaceGrotesk-Bold", size: 14)).monospacedDigit().foregroundStyle(late ? Board.accent : Board.text)
}

private func minutesLeft(_ ms: Double?) -> Int? {
    guard let ms else { return nil }
    return max(1, Int(ceil((ms - Date().timeIntervalSince1970 * 1000) / 60_000)))
}

/// What the island's left side says now.
private struct CompactLeading: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState
    var body: some View {
        let line = Color(hex: attributes.color) ?? Board.accent
        let changed = state.note == "platformChanged" && ["scheduled", "leaveSoon", "approaching", "boarding"].contains(phase(state))
        if changed { Glyph(name: "exclamationmark.triangle.fill") }
        else {
            switch phase(state) {
            case "leaveSoon": timeText(state.departAt, tz: attributes.fromTz, late: lateMin(state) != nil)
            case "boarding": Text(Words.board).font(.custom("InterVariable", size: 12).weight(.heavy)).foregroundStyle(Board.accent)
            case "enRoute": ProgressRing(progress: state.progress ?? 0, colour: line)
            case "getOffSoon": Glyph(name: "figure.walk.arrival")
            case "changing": Text("→ \(state.changePlatform ?? "–")").font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.accent)
            case "arrived": Glyph(name: "checkmark.circle.fill", colour: Board.onTime)
            case "cancelled": Glyph(name: "xmark.circle.fill", colour: Board.cancelled)
            default: Glyph(name: "tram.fill", colour: line)
            }
        }
    }
}

/// What the island's right side says now.
private struct CompactTrailing: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState
    var body: some View {
        let late = lateMin(state) != nil
        let changed = state.note == "platformChanged" && ["scheduled", "leaveSoon", "approaching", "boarding"].contains(phase(state))
        if changed, let p = state.platform {
            Text("→ \(p)").font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.accent)
        } else {
            switch phase(state) {
            case "leaveSoon", "boarding":
                Text(state.platform.map { phase(state) == "boarding" ? $0 : Words.platformShort($0) } ?? "–")
                    .font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.accent)
            case "approaching": timeText(state.nextStopAt ?? state.departAt, tz: attributes.fromTz, late: late)
            case "enRoute": timeText(state.arriveAt, tz: attributes.toTz, late: late)
            case "getOffSoon": Countdown(to: state.nextStopAt ?? state.arriveAt ?? Date().timeIntervalSince1970 * 1000)
            case "changing": Countdown(to: state.changeAt ?? Date().timeIntervalSince1970 * 1000)
            case "arrived": Text(Words.arrived).font(.custom("InterVariable", size: 12).weight(.bold)).foregroundStyle(Board.onTime)
            case "cancelled": Text(Words.cancelled).font(.custom("InterVariable", size: 12).weight(.bold)).foregroundStyle(Board.cancelled)
            default: timeText(state.departAt, tz: attributes.fromTz, late: late)
            }
        }
    }
}

/// The one thing, when the island shrinks to a dot beside another activity.
private struct MinimalGlyph: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState
    var body: some View {
        let line = Color(hex: attributes.color) ?? Board.accent
        let changed = state.note == "platformChanged" && ["scheduled", "leaveSoon", "approaching", "boarding"].contains(phase(state))
        let platform = (changed ? state.platform : nil) ?? state.platform
        switch phase(state) {
        case "cancelled": Glyph(name: "xmark.circle.fill", colour: Board.cancelled)
        case "arrived": Glyph(name: "checkmark.circle.fill", colour: Board.onTime)
        case "enRoute": ProgressRing(progress: state.progress ?? 0, colour: line)
        case "getOffSoon": Text("\(minutesLeft(state.nextStopAt ?? state.arriveAt) ?? 0)").font(.custom("SpaceGrotesk-Bold", size: 13)).foregroundStyle(Board.accent)
        case "changing", "leaveSoon", "boarding":
            Text((phase(state) == "changing" ? state.changePlatform : platform) ?? "–").font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.accent)
        default: Glyph(name: changed ? "exclamationmark.triangle.fill" : "tram.fill", colour: changed ? Board.accent : line)
        }
    }
}

/// The big value on the expanded island's right, the one that matters now.
private struct KeyValue: View {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState
    var body: some View {
        switch phase(state) {
        case "changing":
            VStack(alignment: .trailing, spacing: 0) {
                Text(Words.platform(state.changePlatform ?? "–")).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(Board.accent)
                if let at = state.changeAt { Countdown(to: at, colour: Board.text2) }
            }
        case "getOffSoon":
            Countdown(to: state.nextStopAt ?? state.arriveAt ?? Date().timeIntervalSince1970 * 1000)
        case "enRoute", "approaching":
            timeText(phase(state) == "approaching" ? (state.nextStopAt ?? state.departAt) : state.arriveAt, tz: phase(state) == "approaching" ? attributes.fromTz : attributes.toTz, late: lateMin(state) != nil)
        case "arrived", "cancelled":
            EmptyView()
        default:
            if let p = state.platform { Text(Words.platform(p)).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(Board.accent) }
        }
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
            // Apple's layout, with its default margins: small things beside the camera, everything else in the bottom block.
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "tram.fill").font(.system(size: 14)).foregroundStyle(line)
                        if let train = context.attributes.train { Text(train).font(.custom("SpaceGrotesk-Bold", size: 16)).foregroundStyle(Board.text) }
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    KeyValue(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(s.text).font(.custom("InterVariable", size: 14).weight(.bold)).foregroundStyle(s.colour)
                            Spacer(minLength: 4)
                            Text(context.attributes.to).font(.custom("InterVariable", size: 14).weight(.semibold)).foregroundStyle(Board.text).lineLimit(1)
                        }
                        RouteLine(state: context.state, colour: line)
                        HStack {
                            Text(time(context.state.departAt, tz: context.attributes.fromTz))
                            Spacer()
                            if context.isStale {
                                Text(Words.estimated).font(.custom("InterVariable", size: 11))
                            }
                            Spacer()
                            Text(time(context.state.arriveAt, tz: context.attributes.toTz))
                        }
                        .font(.custom("SpaceGrotesk-Bold", size: 14)).foregroundStyle(Board.text2)
                    }
                }
            } compactLeading: {
                CompactLeading(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                CompactTrailing(attributes: context.attributes, state: context.state)
            } minimal: {
                MinimalGlyph(attributes: context.attributes, state: context.state)
            }
            .keylineTint(line)
        }
    }
}
