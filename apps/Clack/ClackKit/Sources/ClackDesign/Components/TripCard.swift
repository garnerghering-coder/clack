//
//  TripCard.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// The trip card's faces (the Live Activity): the Lock Screen, the Apple Watch Smart Stack and CarPlay card, and the
/// Dynamic Island's expanded, compact and minimal presentations. They live here, not in the widget extension, so the app's
/// Debug gallery (`-activityGallery`) can draw each one inside the island's real shape and size, where clipping shows.
///
/// One card follows the whole journey, so it reads the leg it shows from the content state (`TripCardState.legId` and the
/// fields after it) and falls back to the leg it started on (`TripCardStart`) for an older server. Status is written, not
/// boxed; a delay that isn't known is a grey "—", never "On time".
///
/// Fitting (owner, 2026-10-24: "we should really try not to have text cutting off"; Apple, Human Interface Guidelines,
/// Live Activities, "Use consistent margins and concentric placement" and the iOS dimensions table): the island is black
/// with rounded ends, so nothing is drawn near its edge. The expanded island uses the system's margins and holds two rows
/// under the camera (2026-10-25: three rows with wider margins were cropped), the compact sides hold content no taller
/// than `TripIsland.compactContent`, the ring
/// draws its stroke inside its own frame, and the minimal and the limited-width compact views fit Apple's 28 pt circle.
/// Words that could run long have a shorter form (`ViewThatFits`), and scale down to 0.75 at most as a last resort.

// MARK: what the card shows

/// The leg a card started on (the Live Activity's fixed attributes).
public struct TripCardStart: Sendable {
    public var legId: String
    public var train: String?
    public var from: String
    public var to: String
    public var fromTz: String
    public var toTz: String
    /// The operator's colour, `#rrggbb`.
    public var color: String?

    public init(legId: String, train: String?, from: String, to: String, fromTz: String, toTz: String, color: String?) {
        self.legId = legId
        self.train = train
        self.from = from
        self.to = to
        self.fromTz = fromTz
        self.toTz = toTz
        self.color = color
    }
}

/// The leg the card shows now, and its words.
@MainActor
public struct TripCardFace {
    public let start: TripCardStart
    public let state: TripCardState
    public let l10n: L10n
    public let clock: ClockFormat

    public init(start: TripCardStart, state: TripCardState, l10n: L10n, clock: ClockFormat) {
        self.start = start
        self.state = state
        self.l10n = l10n
        self.clock = clock
    }

    public var legId: String { state.legId ?? start.legId }
    var train: String? { state.legId == nil ? start.train : state.train }
    var from: String { state.from ?? start.from }
    var to: String { state.to ?? start.to }
    var fromTz: String { state.fromTz ?? start.fromTz }
    var toTz: String { state.toTz ?? start.toTz }
    var phase: String { state.moment }
    /// "Car 4 · Seat 23" until the leg is over, when the trip has it.
    var seat: String? { ["arrived", "cancelled"].contains(phase) ? nil : Seat.label(l10n, coach: state.coach, seat: state.seat) }
    /// The operator's colour; the signal yellow when it isn't known (the island is always dark).
    public var line: Color { operatorColor(start.color, scheme: .dark) }
    public var url: URL? { URL(string: "clack://trip/\(legId)") }

    /// A platform change in the last ten minutes, before the train leaves.
    var platformChanged: Bool {
        state.note == "platformChanged" && ["scheduled", "leaveSoon", "approaching", "boarding"].contains(phase)
    }

    var route: String { l10n.t("tripCard.route", ["from": from, "to": to]) }
    func platform(_ p: String) -> String { l10n.t("tripCard.platform", ["platform": p]) }
    func platformShort(_ p: String) -> String { l10n.t("tripCard.platformShort", ["platform": p]) }
    func time(_ ms: Double?, tz: String) -> String { Format.time(ms, tz: tz, clock: clock) }
    var departs: String { time(state.departAt, tz: fromTz) }
    var arrives: String { time(state.arriveAt, tz: toTz) }
    var nowMs: Double { Date().timeIntervalSince1970 * 1000 }

    /// The word for the moment, if it has one, and its ink. Running and far-off trips have none: the delay says it.
    var word: (text: String, ink: Color)? {
        switch phase {
        case "cancelled": return (l10n.t("delay.cancelled"), Ink.veryLateInk)
        case "arrived": return (l10n.t("tripCard.arrived"), Ink.onTimeInk)
        case "changing": return (l10n.t("tripCard.changing"), Ink.accentInk)
        case "getOffSoon": return (l10n.t("tripCard.getOffSoon"), Ink.accentInk)
        default: break
        }
        if platformChanged, let p = state.platform { return (l10n.t("tripCard.platformChanged", ["platform": p]), Ink.accentInk) }
        switch phase {
        case "boarding": return (l10n.t("tripCard.boarding"), Ink.text)
        case "approaching": return (l10n.t("tripCard.approaching"), Ink.text)
        case "leaveSoon": return (l10n.t("tripCard.leavingSoon"), Ink.text)
        default: return nil
        }
    }

    /// Whether a delay belongs on the card now (not once arrived or cancelled: the word says it).
    var showsDelay: Bool { !["cancelled", "arrived", "changing"].contains(phase) }

    /// The delay band, for times drawn in its colour.
    var band: DelayBand { DelayBand(delayMin: state.delayMin, canceled: state.canceled) }
    var late: Bool { (state.delayMin ?? 0) >= 1 }
}

/// The island's sizes and margins, in points.
public enum TripIsland {
    /// About the system's own expanded margins, for drawing the island in the Debug gallery (the real island applies
    /// the system's).
    public static let expandedMargins = EdgeInsets(top: 6, leading: expandedSide, bottom: 14, trailing: expandedSide)
    /// The one side margin of every expanded region (the train number and platform beside the camera, and the rows
    /// under it), so they line up.
    public static let expandedSide: CGFloat = 22
    /// The tallest thing a compact side or the minimal view holds: the compact island is 36.67 pt high with round ends,
    /// and Apple asks for the compact and minimal views to fit a 28 pt circle when the island is narrow.
    public static let compactContent: CGFloat = 20
    /// The widest a compact side's text may get before it uses its shorter form (Apple's compact size is 52.33 to
    /// 62.33 pt per side, including the system margins).
    public static let compactTextWidth: CGFloat = 44

    /// The true sizes from Apple's iOS dimensions table (iPhone 17 Pro sized), for the Debug gallery.
    public static let expandedSize = CGSize(width: 371, height: 160)
    public static let compactSize = CGSize(width: 52.33, height: 36.67)
    public static let minimalSize = CGSize(width: 36.67, height: 36.67)
    public static let limitedCircle: CGFloat = 28
    public static let lockScreenWidth: CGFloat = 371
}

private func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }

private func minutesLeft(_ ms: Double?) -> Int? {
    guard let ms else { return nil }
    return max(1, Int(ceil((ms - Date().timeIntervalSince1970 * 1000) / 60_000)))
}

/// Text roles for the card's small spaces (the design scale's big-number roles are too large here).
private extension TextRole {
    /// Times on the Lock Screen line.
    static let cardTime = TextRole(size: 18, lineHeight: 22, display: true, style: .headline)
    /// Times and countdowns in the island.
    static let islandValue = TextRole(size: 14, lineHeight: 18, display: true, style: .subheadline)
    /// The train number.
    static let cardTrain = TextRole(size: 15, lineHeight: 20, display: true, style: .subheadline)
}

// MARK: pieces

/// The line along the trip. With a position (`progress`) it is drawn there. Without one, a train that is running gets a
/// bar that fills by itself between its departure and arrival times, so it keeps moving between updates (and offline).
private struct RouteLine: View {
    let card: TripCardFace

    private var running: Bool { card.phase == "enRoute" || card.phase == "getOffSoon" }

    private var window: ClosedRange<Date>? {
        guard let dep = card.state.departAt, let arr = card.state.arriveAt, arr > dep else { return nil }
        return date(dep)...date(arr)
    }

    var body: some View {
        Group {
            if card.state.progress == nil, running, let window {
                ProgressView(timerInterval: window, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(card.line)
            } else {
                ProgressBar(value: card.state.progress ?? (card.phase == "arrived" ? 1 : 0), color: card.line, marker: .solid)
            }
        }
        // The marker is as tall as the line's frame and rides inside it: half a marker of room at each end, so it never
        // pokes past the card's margin at the start or the end of the trip.
        .padding(.horizontal, ProgressBar.markerSize / 2)
        .frame(height: ProgressBar.markerSize)
        .accessibilityHidden(true)
    }
}

/// The delay, as everywhere in the app: "On time", "+8", "−2", or a grey "—" when it isn't known.
private struct Delay: View {
    let card: TripCardFace
    var body: some View {
        if card.showsDelay { DelayText(delay: card.state.delayMin, canceled: card.state.canceled) }
    }
}

/// A Lucide icon for the island's small spaces.
private struct Glyph: View {
    let name: String
    var colour: Color = Ink.accentInk
    var size: CGFloat = 14
    var body: some View { LucideIcon(name: name, size: size).foregroundStyle(colour) }
}

/// A ring that fills as the train goes, with the train inside it. The stroke is drawn inside the frame (the circle is
/// inset by half the line width), so the ring is exactly `size` across and nothing spills past it.
public struct TripProgressRing: View {
    public let progress: Double
    public let colour: Color
    public static let size: CGFloat = TripIsland.compactContent
    static let lineWidth: CGFloat = 2.5

    public init(progress: Double, colour: Color) {
        self.progress = progress
        self.colour = colour
    }

    public var body: some View {
        ZStack {
            Circle().inset(by: Self.lineWidth / 2).stroke(Ink.fillSoft, lineWidth: Self.lineWidth)
            Circle().inset(by: Self.lineWidth / 2).trim(from: 0, to: min(max(progress, 0.02), 1))
                .stroke(colour, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            LucideIcon(name: "train-front", size: 10).foregroundStyle(Ink.text)
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityHidden(true)
    }
}

/// Counts down by itself to a time, in `m:ss` (or `h:mm:ss`).
private struct Countdown: View {
    let to: Double
    var colour: Color = Ink.accentInk
    var maxWidth: CGFloat = 52
    var body: some View {
        Text(timerInterval: Date.now...max(date(to), Date.now.addingTimeInterval(1)), countsDown: true, showsHours: false)
            .clack(.islandValue).monospacedDigit().foregroundStyle(colour)
            .multilineTextAlignment(.trailing)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(maxWidth: maxWidth)
    }
}

private struct TimeText: View {
    let text: String
    let card: TripCardFace
    var body: some View {
        Text(text).clack(.islandValue).monospacedDigit().foregroundStyle(card.late ? card.band.ink : Ink.text)
            .lineLimit(1).minimumScaleFactor(0.75)
    }
}

/// One line of text that never truncates: its full size when it fits, else scaled down to 0.75.
private struct FitText: View {
    let text: String
    let role: TextRole
    var ink: Color = Ink.text

    init(_ text: String, _ role: TextRole, ink: Color = Ink.text) {
        self.text = text
        self.role = role
        self.ink = ink
    }

    var body: some View {
        Text(text).clack(role).foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.75)
    }
}

/// What follows the word and the delay: the next platform at a change, or the next stop on the way. `withTime: false` is
/// the shorter form, for when the line is full.
private struct Detail: View {
    let card: TripCardFace
    var withTime = true
    var body: some View {
        if card.phase == "changing", let p = card.state.changePlatform {
            Text(card.platform(p)).clack(.stopName).foregroundStyle(Ink.text).lineLimit(1).fixedSize()
            if withTime, let at = card.state.changeAt { Countdown(to: at, colour: Ink.text2) }
        } else if let next = card.state.nextStop, ["enRoute", "getOffSoon", "approaching"].contains(card.phase) {
            FitText(card.l10n.t("tripCard.next", ["station": next]), .stopName, ink: Ink.text2)
            if withTime, let at = card.state.nextStopAt {
                Text(card.time(at, tz: card.toTz)).clack(.islandValue).monospacedDigit().foregroundStyle(Ink.text2).fixedSize()
            }
        }
    }
}

/// The word, the delay and the detail on one line; without the detail's time when they don't fit.
private struct StatusRow: View {
    let card: TripCardFace
    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(withTime: true).fixedSize(horizontal: true, vertical: false)
            row(withTime: false)
        }
    }

    private func row(withTime: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let word = card.word { Text(word.text).clack(.delay).foregroundStyle(word.ink).lineLimit(1).fixedSize() }
            Delay(card: card)
            Detail(card: card, withTime: withTime)
        }
    }
}

// MARK: Lock Screen and StandBy

/// The Lock Screen card (also StandBy, scaled up): the route and train, the moment, the line, the times and platform.
public struct TripCardLockScreen: View {
    let card: TripCardFace
    let stale: Bool

    public init(card: TripCardFace, stale: Bool) {
        self.card = card
        self.stale = stale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                switch card.phase {
                case "arrived":
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(Ink.onTimeInk).accessibilityHidden(true)
                    FitText(card.l10n.t("tripCard.welcome", ["station": card.to]), .boardDestination).layoutPriority(1)
                case "changing":
                    LucideIcon(name: "repeat", size: 16).foregroundStyle(Ink.accentInk)
                    FitText(card.l10n.t("tripCard.changeAt", ["station": card.to]), .boardDestination).layoutPriority(1)
                case "getOffSoon":
                    LucideIcon(name: "map-pin", size: 16).foregroundStyle(Ink.accentInk)
                    FitText(card.l10n.t("tripCard.getOffAt", ["station": card.to]), .boardDestination).layoutPriority(1)
                default:
                    FitText(card.route, .boardDestination).layoutPriority(1)
                }
                Spacer(minLength: 0)
                if let train = card.train { Text(train).clack(.cardTrain).foregroundStyle(Ink.text2).lineLimit(1).fixedSize() }
            }
            StatusRow(card: card)
            RouteLine(card: card).padding(.vertical, 4)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(card.departs).clack(.cardTime).foregroundStyle(Ink.text).fixedSize()
                Spacer(minLength: 0)
                VStack(spacing: 2) {
                    if let p = card.state.platform {
                        FitText(card.platform(p), .delay, ink: card.platformChanged ? Ink.accentInk : Ink.text)
                    }
                    // Where you sit, under the platform: the top line is the route's.
                    if let seat = card.seat { FitText(seat, .chip, ink: Ink.text2) }
                    // Stale: no news from the server for five minutes; the times are the last ones it sent.
                    if stale { Text(card.l10n.t("tripCard.estimated")).clack(.caption).italic().foregroundStyle(Ink.text3).lineLimit(1) }
                }
                .multilineTextAlignment(.center)
                Spacer(minLength: 0)
                Text(card.arrives).clack(.cardTime).foregroundStyle(Ink.text).fixedSize()
            }
        }
        // Apple's standard Lock Screen margin is 14 pt; 16 keeps the 4 pt grid and still clears the card's corners.
        .padding(16)
    }
}

// MARK: Apple Watch Smart Stack and CarPlay

/// The small card (iOS 18+): the route, then the one number that matters now (the countdown to leaving or to getting
/// off, the next stop, the next train), the platform, and the delay.
public struct TripCardSmall: View {
    let card: TripCardFace
    let stale: Bool

    public init(card: TripCardFace, stale: Bool) {
        self.card = card
        self.stale = stale
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                LucideIcon(name: "train-front", size: 12).foregroundStyle(card.line)
                FitText(card.route, .chip)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                key
                Spacer(minLength: 2)
                Delay(card: card)
            }
            HStack(spacing: 4) {
                if card.phase == "changing", let p = card.state.changePlatform {
                    Text(card.platform(p)).clack(.chip).foregroundStyle(Ink.accentInk).lineLimit(1).fixedSize()
                } else if let p = card.state.platform {
                    Text(card.platform(p)).clack(.chip).foregroundStyle(card.platformChanged ? Ink.accentInk : Ink.text2).lineLimit(1).fixedSize()
                }
                if let seat = card.seat { FitText(seat, .chip, ink: Ink.text2) }
                Spacer(minLength: 0)
                if stale { Text(card.l10n.t("tripCard.estimated")).clack(.captionUpper).foregroundStyle(Ink.text3).lineLimit(1).fixedSize() }
            }
        }
        .padding(8)
    }

    @ViewBuilder private var key: some View {
        switch card.phase {
        case "cancelled", "arrived":
            if let word = card.word { FitText(word.text, .delay, ink: word.ink) }
        case "changing":
            if let at = card.state.changeAt { Countdown(to: at) } else if let word = card.word { FitText(word.text, .delay, ink: word.ink) }
        case "getOffSoon":
            Countdown(to: card.state.nextStopAt ?? card.state.arriveAt ?? card.nowMs)
        case "enRoute":
            if let next = card.state.nextStop {
                FitText(card.l10n.t("tripCard.next", ["station": next]), .caption, ink: Ink.text2)
            } else {
                FitText("\(card.l10n.t("tripCard.arrives")) \(card.arrives)", .caption, ink: Ink.text2)
            }
        default:
            if let dep = card.state.departAt, dep > card.nowMs, dep - card.nowMs < 3_600_000 {
                Countdown(to: dep)
            } else {
                FitText("\(card.l10n.t("tripCard.leaves")) \(card.departs)", .caption, ink: Ink.text2)
            }
        }
    }
}

// MARK: Dynamic Island, compact and minimal

/// What the island's left side says now. Content is at most `TripIsland.compactContent` tall, so it clears the island's
/// round end at the top and bottom. When the island is narrow (`limited`: iPhone in landscape, two activities on the
/// newest phones), it shows the minimal view, which fits Apple's 28 pt circle.
public struct TripIslandCompactLeading: View {
    let card: TripCardFace
    let limited: Bool

    public init(card: TripCardFace, limited: Bool = false) {
        self.card = card
        self.limited = limited
    }

    public var body: some View {
        Group {
            if limited { TripIslandMinimal(card: card) } else { content }
        }
        .frame(maxHeight: TripIsland.compactContent)
    }

    @ViewBuilder private var content: some View {
        if card.platformChanged { Glyph(name: "triangle-alert") }
        else {
            switch card.phase {
            case "leaveSoon": TimeText(text: card.departs, card: card)
            case "boarding":
                Text(card.l10n.t("tripCard.board")).clack(.captionUpper).fontWeight(.heavy).foregroundStyle(Ink.accentInk)
                    .lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: TripIsland.compactTextWidth)
            case "enRoute": TripProgressRing(progress: card.state.progress ?? 0, colour: card.line)
            case "getOffSoon": Glyph(name: "map-pin")
            case "changing":
                Text(verbatim: "→ \(card.state.changePlatform ?? Format.unknown)").clack(.islandValue).foregroundStyle(Ink.accentInk)
                    .lineLimit(1).minimumScaleFactor(0.75).frame(maxWidth: TripIsland.compactTextWidth)
            case "arrived": Glyph(name: "check", colour: Ink.onTimeInk)
            case "cancelled": Glyph(name: "x", colour: Ink.veryLateInk)
            default: Glyph(name: "train-front", colour: card.line)
            }
        }
    }
}

/// What the island's right side says now: always a short value (a time, a countdown, a platform), never a word that
/// could run past the side. Empty when the island is narrow: the left side then says it alone (Apple's advice), and the
/// system hides an empty side.
public struct TripIslandCompactTrailing: View {
    let card: TripCardFace
    let limited: Bool

    public init(card: TripCardFace, limited: Bool = false) {
        self.card = card
        self.limited = limited
    }

    public var body: some View {
        if limited { EmptyView() } else { content.frame(maxWidth: TripIsland.compactTextWidth, maxHeight: TripIsland.compactContent) }
    }

    @ViewBuilder private var content: some View {
        if card.platformChanged, let p = card.state.platform {
            fit("→ \(p)", Ink.accentInk)
        } else {
            switch card.phase {
            case "leaveSoon", "boarding":
                if let p = card.state.platform {
                    // "Pl 5" when it fits, else the number alone.
                    ViewThatFits(in: .horizontal) {
                        if card.phase == "leaveSoon" {
                            Text(card.platformShort(p)).clack(.islandValue).foregroundStyle(Ink.accentInk).lineLimit(1).fixedSize()
                        }
                        fit(p, Ink.accentInk)
                    }
                } else {
                    // No platform announced yet: the departure time rather than a dash.
                    TimeText(text: card.departs, card: card)
                }
            case "approaching": TimeText(text: card.time(card.state.nextStopAt ?? card.state.departAt, tz: card.fromTz), card: card)
            case "enRoute": TimeText(text: card.arrives, card: card)
            case "getOffSoon": Countdown(to: card.state.nextStopAt ?? card.state.arriveAt ?? card.nowMs, maxWidth: TripIsland.compactTextWidth)
            case "changing": Countdown(to: card.state.changeAt ?? card.nowMs, maxWidth: TripIsland.compactTextWidth)
            // The left side has the tick or the cross: the right side gives the time (arrived) or the struck departure.
            case "arrived": TimeText(text: card.arrives, card: card)
            case "cancelled": fit(card.departs, Ink.veryLateInk).strikethrough()
            default: TimeText(text: card.departs, card: card)
            }
        }
    }

    private func fit(_ text: String, _ ink: Color) -> some View {
        Text(verbatim: text).clack(.islandValue).monospacedDigit().foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.75)
    }
}

/// The one thing, when the island shrinks to a dot beside another activity: it fits inside Apple's 28 pt circle, so the
/// round dot never cuts it.
public struct TripIslandMinimal: View {
    let card: TripCardFace

    public init(card: TripCardFace) { self.card = card }

    public var body: some View {
        content
            .frame(maxWidth: TripIsland.compactContent + 4, maxHeight: TripIsland.compactContent)
    }

    @ViewBuilder private var content: some View {
        switch card.phase {
        case "cancelled": Glyph(name: "x", colour: Ink.veryLateInk)
        case "arrived": Glyph(name: "check", colour: Ink.onTimeInk)
        case "enRoute": TripProgressRing(progress: card.state.progress ?? 0, colour: card.line)
        case "getOffSoon":
            value("\(minutesLeft(card.state.nextStopAt ?? card.state.arriveAt) ?? 0)")
        case "changing", "leaveSoon", "boarding":
            value((card.phase == "changing" ? card.state.changePlatform : card.state.platform) ?? Format.unknown)
        default:
            Glyph(name: card.platformChanged ? "triangle-alert" : "train-front", colour: card.platformChanged ? Ink.accentInk : card.line)
        }
    }

    private func value(_ text: String) -> some View {
        Text(verbatim: text).clack(.islandValue).monospacedDigit().foregroundStyle(Ink.accentInk).lineLimit(1).minimumScaleFactor(0.75)
    }
}

// MARK: Dynamic Island, expanded

/// The train, beside the camera on the left.
public struct TripIslandExpandedLeading: View {
    let card: TripCardFace

    public init(card: TripCardFace) { self.card = card }

    public var body: some View {
        HStack(spacing: 4) {
            LucideIcon(name: "train-front", size: 14).foregroundStyle(card.line)
            if let train = card.train { FitText(train, .cardTrain) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The value that matters now, beside the camera on the right: one line, so it never runs into the island's top.
public struct TripIslandExpandedTrailing: View {
    let card: TripCardFace

    public init(card: TripCardFace) { self.card = card }

    public var body: some View {
        content.frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder private var content: some View {
        switch card.phase {
        case "changing":
            if let at = card.state.changeAt { Countdown(to: at) }
        case "getOffSoon":
            Countdown(to: card.state.nextStopAt ?? card.state.arriveAt ?? card.nowMs)
        case "enRoute":
            TimeText(text: card.arrives, card: card)
        case "approaching":
            TimeText(text: card.time(card.state.nextStopAt ?? card.state.departAt, tz: card.fromTz), card: card)
        case "arrived", "cancelled":
            EmptyView()
        default:
            if let p = card.state.platform { FitText(card.platform(p), .delay, ink: Ink.accentInk) }
        }
    }
}

/// Under the camera, two rows at most so the island never crops them (owner, 2026-10-25), with a look for each moment
/// of the trip: before and on the train, the moment and delay over the line between the two times; getting off, where
/// and how long; a change, where, the next platform and the countdown to the next train; arrived, a welcome; cancelled,
/// the struck departure.
public struct TripIslandExpandedBottom: View {
    let card: TripCardFace
    let stale: Bool

    public init(card: TripCardFace, stale: Bool) {
        self.card = card
        self.stale = stale
    }

    public var body: some View {
        Group {
            switch card.phase {
            case "arrived": arrived
            case "cancelled": cancelled
            case "changing": changing
            case "getOffSoon": getOff
            default: travelling
            }
        }
        .padding(.bottom, 2)
    }

    /// The times at each end with the line between them, in one row.
    private var timeline: some View {
        HStack(spacing: 8) {
            Text(card.departs).fixedSize()
            RouteLine(card: card)
            Text(card.arrives).fixedSize()
        }
        .clack(.islandValue).monospacedDigit().foregroundStyle(Ink.text2)
    }

    private var travelling: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                StatusRow(card: card).layoutPriority(2)
                Spacer(minLength: 4)
                if stale {
                    Text(card.l10n.t("tripCard.estimated")).clack(.caption).italic().foregroundStyle(Ink.text3).lineLimit(1).fixedSize()
                } else {
                    FitText(card.to, .buttonSmall).layoutPriority(1)
                }
            }
            timeline
        }
    }

    private var getOff: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Glyph(name: "map-pin")
                FitText(card.l10n.t("tripCard.getOffAt", ["station": card.to]), .alertTitle).layoutPriority(1)
                Spacer(minLength: 0)
            }
            timeline
        }
    }

    private var changing: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Glyph(name: "repeat")
                FitText(card.l10n.t("tripCard.changeAt", ["station": card.to]), .alertTitle).layoutPriority(1)
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                if let p = card.state.changePlatform {
                    Text(verbatim: "→ \(card.platform(p))").clack(.delay).foregroundStyle(Ink.accentInk).lineLimit(1).fixedSize()
                }
                Spacer(minLength: 0)
                if let at = card.state.changeAt {
                    Text(card.l10n.t("tripCard.nextLeaves", ["time": card.time(at, tz: card.toTz)]))
                        .clack(.islandValue).monospacedDigit().foregroundStyle(Ink.text2).lineLimit(1).fixedSize()
                }
            }
        }
    }

    private var arrived: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(Ink.onTimeInk)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                FitText(card.l10n.t("tripCard.welcome", ["station": card.to]), .alertTitle)
                HStack(spacing: 6) {
                    Text(card.l10n.t("tripCard.arrivedAt", ["time": card.arrives])).clack(.stopName).foregroundStyle(Ink.text2).lineLimit(1)
                    DelayText(delay: card.state.delayMin, canceled: false)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var cancelled: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Glyph(name: "x", colour: Ink.veryLateInk)
            FitText(card.l10n.t("delay.cancelled"), .alertTitle, ink: Ink.veryLateInk)
            Spacer(minLength: 4)
            Text(card.departs).clack(.islandValue).monospacedDigit().strikethrough().foregroundStyle(Ink.text2).fixedSize()
        }
    }
}
