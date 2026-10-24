//
//  TripLiveActivity.swift
//  ClackWidgets
//

import ActivityKit
import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

/// The trip you are on, on the Lock Screen, in the Dynamic Island, in StandBy, and (iOS 18+) in the Apple Watch Smart
/// Stack and CarPlay (owner, 2026-10-24). One card follows the whole journey, so it reads the leg it shows from the
/// content state (`TripCardState.legId` and the fields after it) and falls back to the fixed attributes for an older
/// server. The Lock Screen card is one solid line with the times and status; the island says what matters at that
/// moment (the platform before you leave, the arrival time on the way, the minutes left at the end, the next platform at
/// a change). Status is written, not boxed; a delay that isn't known is a grey "—", never "On time". Tapping opens the
/// leg in the app. Words come from the shared locale files, in the app's language (`SharedSettings`).

// MARK: what the card shows

/// The leg the card shows now, and its words.
@MainActor
private struct Card {
    let attributes: TripActivityAttributes
    let state: TripActivityAttributes.ContentState
    let l10n: L10n
    let clock: ClockFormat

    var legId: String { state.legId ?? attributes.legId }
    var train: String? { state.legId == nil ? attributes.train : state.train }
    var from: String { state.from ?? attributes.from }
    var to: String { state.to ?? attributes.to }
    var fromTz: String { state.fromTz ?? attributes.fromTz }
    var toTz: String { state.toTz ?? attributes.toTz }
    var phase: String { state.moment }
    var line: Color { Color(hex: attributes.color) ?? Ink.accent }
    var url: URL? { URL(string: "clack://trip/\(legId)") }

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

/// The texts and settings for the card, read once per render from the App Group.
@MainActor
private enum CardText {
    static let l10n = L10n(language: SharedSettings.language())

    static func card(_ attributes: TripActivityAttributes, _ state: TripActivityAttributes.ContentState) -> Card {
        let language = SharedSettings.language()
        if l10n.language != language { l10n.language = language }
        return Card(attributes: attributes, state: state, l10n: l10n, clock: SharedSettings.clock())
    }
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
    let card: Card

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
                bar(card.state.progress ?? (card.phase == "arrived" ? 1 : 0))
            }
        }
        .frame(height: ProgressBar.markerSize)
        .accessibilityHidden(true)
    }

    private func bar(_ progress: Double) -> some View {
        ProgressBar(value: progress, color: card.line, marker: .solid)
    }
}

/// The delay, as everywhere in the app: "On time", "+8", "−2", or a grey "—" when it isn't known.
private struct Delay: View {
    let card: Card
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

/// A ring that fills as the train goes, with the train inside it.
private struct ProgressRing: View {
    let progress: Double
    let colour: Color
    var body: some View {
        ZStack {
            Circle().stroke(Ink.fillSoft, lineWidth: 2.5)
            Circle().trim(from: 0, to: min(max(progress, 0.02), 1))
                .stroke(colour, style: StrokeStyle(lineWidth: 2.5, lineCap: .round)).rotationEffect(.degrees(-90))
            LucideIcon(name: "train-front", size: 10).foregroundStyle(Ink.text)
        }
        .frame(width: 22, height: 22)
    }
}

/// Counts down by itself to a time, in `m:ss` (or `h:mm:ss`).
private struct Countdown: View {
    let to: Double
    var colour: Color = Ink.accentInk
    var body: some View {
        Text(timerInterval: Date.now...max(date(to), Date.now.addingTimeInterval(1)), countsDown: true, showsHours: false)
            .clack(.islandValue).monospacedDigit().foregroundStyle(colour)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 52)
    }
}

private struct TimeText: View {
    let text: String
    let card: Card
    var body: some View {
        Text(text).clack(.islandValue).monospacedDigit().foregroundStyle(card.late ? card.band.ink : Ink.text)
    }
}

/// What follows the word and the delay: the next platform at a change, or the next stop on the way.
private struct Detail: View {
    let card: Card
    var body: some View {
        if card.phase == "changing", let p = card.state.changePlatform {
            Text(card.platform(p)).clack(.stopName).foregroundStyle(Ink.text)
            if let at = card.state.changeAt {
                Text(timerInterval: Date.now...max(date(at), Date.now.addingTimeInterval(1)), countsDown: true)
                    .clack(.islandValue).monospacedDigit().foregroundStyle(Ink.text2)
            }
        } else if let next = card.state.nextStop, ["enRoute", "getOffSoon", "approaching"].contains(card.phase) {
            Text(card.l10n.t("tripCard.next", ["station": next])).clack(.stopName).foregroundStyle(Ink.text2).lineLimit(1)
            if let at = card.state.nextStopAt {
                Text(card.time(at, tz: card.toTz)).clack(.islandValue).foregroundStyle(Ink.text2)
            }
        }
    }
}

// MARK: Lock Screen and StandBy

private struct LockScreen: View {
    let card: Card
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(card.route).clack(.boardDestination).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 8)
                if let train = card.train { Text(train).clack(.cardTrain).foregroundStyle(Ink.text2) }
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let word = card.word { Text(word.text).clack(.delay).foregroundStyle(word.ink).lineLimit(1) }
                Delay(card: card)
                Detail(card: card)
            }
            RouteLine(card: card)
            HStack(alignment: .firstTextBaseline) {
                Text(card.departs).clack(.cardTime).foregroundStyle(Ink.text)
                Spacer()
                VStack(spacing: 2) {
                    if let p = card.state.platform {
                        Text(card.platform(p)).clack(.delay).foregroundStyle(card.platformChanged ? Ink.accentInk : Ink.text)
                    }
                    // Stale: no news from the server for five minutes; the times are the last ones it sent.
                    if stale { Text(card.l10n.t("tripCard.estimated")).clack(.caption).italic().foregroundStyle(Ink.text3) }
                }
                Spacer()
                Text(card.arrives).clack(.cardTime).foregroundStyle(Ink.text)
            }
        }
        .padding(16)
    }
}

// MARK: Apple Watch Smart Stack and CarPlay

/// The small card (iOS 18+): the route, then the one number that matters now (the countdown to leaving or to getting
/// off, the next stop, the next train), the platform, and the delay.
private struct SmallCard: View {
    let card: Card
    let stale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                LucideIcon(name: "train-front", size: 12).foregroundStyle(card.line)
                Text(card.route).clack(.chip).foregroundStyle(Ink.text).lineLimit(1).minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                key
                Spacer(minLength: 2)
                Delay(card: card)
            }
            HStack(spacing: 4) {
                if card.phase == "changing", let p = card.state.changePlatform {
                    Text(card.platform(p)).clack(.chip).foregroundStyle(Ink.accentInk)
                } else if let p = card.state.platform {
                    Text(card.platform(p)).clack(.chip).foregroundStyle(card.platformChanged ? Ink.accentInk : Ink.text2)
                }
                Spacer(minLength: 0)
                if stale { Text(card.l10n.t("tripCard.estimated")).clack(.captionUpper).foregroundStyle(Ink.text3) }
            }
        }
        .padding(8)
    }

    @ViewBuilder private var key: some View {
        switch card.phase {
        case "cancelled", "arrived":
            if let word = card.word { Text(word.text).clack(.delay).foregroundStyle(word.ink) }
        case "changing":
            if let at = card.state.changeAt { Countdown(to: at) } else if let word = card.word { Text(word.text).clack(.delay).foregroundStyle(word.ink) }
        case "getOffSoon":
            Countdown(to: card.state.nextStopAt ?? card.state.arriveAt ?? Date().timeIntervalSince1970 * 1000)
        case "enRoute":
            if let next = card.state.nextStop {
                Text(card.l10n.t("tripCard.next", ["station": next])).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
            } else {
                Text(verbatim: "\(card.l10n.t("tripCard.arrives")) \(card.arrives)").clack(.caption).foregroundStyle(Ink.text2)
            }
        default:
            if let dep = card.state.departAt, dep > Date().timeIntervalSince1970 * 1000, dep - Date().timeIntervalSince1970 * 1000 < 3_600_000 {
                Countdown(to: dep)
            } else {
                Text(verbatim: "\(card.l10n.t("tripCard.leaves")) \(card.departs)").clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }
}

/// Picks the layout for where the card is shown (iOS 18+).
@available(iOS 18.0, *)
private struct FamilyCard: View {
    @Environment(\.activityFamily) private var family
    let card: Card
    let stale: Bool

    var body: some View {
        switch family {
        case .small: SmallCard(card: card, stale: stale)
        default: LockScreen(card: card, stale: stale)
        }
    }
}

/// The Lock Screen, StandBy and (iOS 18+) the small presentations.
private struct Presentation: View {
    let card: Card
    let stale: Bool

    var body: some View {
        if #available(iOS 18.0, *) { FamilyCard(card: card, stale: stale) } else { LockScreen(card: card, stale: stale) }
    }
}

// MARK: Dynamic Island

/// What the island's left side says now.
private struct CompactLeading: View {
    let card: Card
    var body: some View {
        if card.platformChanged { Glyph(name: "triangle-alert") }
        else {
            switch card.phase {
            case "leaveSoon": TimeText(text: card.departs, card: card)
            case "boarding": Text(card.l10n.t("tripCard.board")).clack(.captionUpper).fontWeight(.heavy).foregroundStyle(Ink.accentInk)
            case "enRoute": ProgressRing(progress: card.state.progress ?? 0, colour: card.line)
            case "getOffSoon": Glyph(name: "map-pin")
            case "changing": Text(verbatim: "→ \(card.state.changePlatform ?? "–")").clack(.islandValue).foregroundStyle(Ink.accentInk)
            case "arrived": Glyph(name: "check", colour: Ink.onTimeInk)
            case "cancelled": Glyph(name: "x", colour: Ink.veryLateInk)
            default: Glyph(name: "train-front", colour: card.line)
            }
        }
    }
}

/// What the island's right side says now.
private struct CompactTrailing: View {
    let card: Card
    var body: some View {
        if card.platformChanged, let p = card.state.platform {
            Text(verbatim: "→ \(p)").clack(.islandValue).foregroundStyle(Ink.accentInk)
        } else {
            switch card.phase {
            case "leaveSoon", "boarding":
                Text(card.state.platform.map { card.phase == "boarding" ? $0 : card.platformShort($0) } ?? "–")
                    .clack(.islandValue).foregroundStyle(Ink.accentInk)
            case "approaching": TimeText(text: card.time(card.state.nextStopAt ?? card.state.departAt, tz: card.fromTz), card: card)
            case "enRoute": TimeText(text: card.arrives, card: card)
            case "getOffSoon": Countdown(to: card.state.nextStopAt ?? card.state.arriveAt ?? Date().timeIntervalSince1970 * 1000)
            case "changing": Countdown(to: card.state.changeAt ?? Date().timeIntervalSince1970 * 1000)
            case "arrived": Text(card.l10n.t("tripCard.arrived")).clack(.captionUpper).foregroundStyle(Ink.onTimeInk)
            case "cancelled": Text(card.l10n.t("delay.cancelled")).clack(.captionUpper).foregroundStyle(Ink.veryLateInk)
            default: TimeText(text: card.departs, card: card)
            }
        }
    }
}

/// The one thing, when the island shrinks to a dot beside another activity.
private struct MinimalGlyph: View {
    let card: Card
    var body: some View {
        switch card.phase {
        case "cancelled": Glyph(name: "x", colour: Ink.veryLateInk)
        case "arrived": Glyph(name: "check", colour: Ink.onTimeInk)
        case "enRoute": ProgressRing(progress: card.state.progress ?? 0, colour: card.line)
        case "getOffSoon":
            Text(verbatim: "\(minutesLeft(card.state.nextStopAt ?? card.state.arriveAt) ?? 0)").clack(.islandValue).foregroundStyle(Ink.accentInk)
        case "changing", "leaveSoon", "boarding":
            Text((card.phase == "changing" ? card.state.changePlatform : card.state.platform) ?? "–")
                .clack(.islandValue).foregroundStyle(Ink.accentInk)
        default:
            Glyph(name: card.platformChanged ? "triangle-alert" : "train-front", colour: card.platformChanged ? Ink.accentInk : card.line)
        }
    }
}

/// The big value on the expanded island's right, the one that matters now.
private struct KeyValue: View {
    let card: Card
    var body: some View {
        switch card.phase {
        case "changing":
            VStack(alignment: .trailing, spacing: 0) {
                Text(card.platform(card.state.changePlatform ?? "–")).clack(.delay).foregroundStyle(Ink.accentInk)
                if let at = card.state.changeAt { Countdown(to: at, colour: Ink.text2) }
            }
        case "getOffSoon":
            Countdown(to: card.state.nextStopAt ?? card.state.arriveAt ?? Date().timeIntervalSince1970 * 1000)
        case "enRoute":
            TimeText(text: card.arrives, card: card)
        case "approaching":
            TimeText(text: card.time(card.state.nextStopAt ?? card.state.departAt, tz: card.fromTz), card: card)
        case "arrived", "cancelled":
            EmptyView()
        default:
            if let p = card.state.platform { Text(card.platform(p)).clack(.delay).foregroundStyle(Ink.accentInk) }
        }
    }
}

private struct ExpandedLeading: View {
    let card: Card
    var body: some View {
        HStack(spacing: 5) {
            LucideIcon(name: "train-front", size: 14).foregroundStyle(card.line)
            if let train = card.train { Text(train).clack(.cardTrain).foregroundStyle(Ink.text) }
        }
    }
}

private struct ExpandedBottom: View {
    let card: Card
    let stale: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let word = card.word { Text(word.text).clack(.delay).foregroundStyle(word.ink).lineLimit(1) }
                Delay(card: card)
                Spacer(minLength: 4)
                Text(card.to).clack(.buttonSmall).foregroundStyle(Ink.text).lineLimit(1)
            }
            RouteLine(card: card)
            HStack {
                Text(card.departs)
                Spacer()
                if stale { Text(card.l10n.t("tripCard.estimated")).clack(.caption).italic() }
                Spacer()
                Text(card.arrives)
            }
            .clack(.islandValue).foregroundStyle(Ink.text2)
        }
    }
}

// MARK: the widget

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        // Apple Watch Smart Stack and CarPlay get the small layout, StandBy the medium one (iOS 18+).
        if #available(iOS 18.0, *) {
            return configuration.supplementalActivityFamilies([.small, .medium])
        } else {
            return configuration
        }
    }

    private var configuration: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            let card = CardText.card(context.attributes, context.state)
            Presentation(card: card, stale: context.isStale)
                .environment(card.l10n)
                .widgetURL(card.url)
                .activityBackgroundTint(Ink.bg)
                .activitySystemActionForegroundColor(Ink.accentInk)
        } dynamicIsland: { context in
            let card = CardText.card(context.attributes, context.state)
            // Apple's layout, with its default margins: small things beside the camera, everything else in the bottom block.
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { ExpandedLeading(card: card) }
                DynamicIslandExpandedRegion(.trailing) { KeyValue(card: card) }
                DynamicIslandExpandedRegion(.bottom) { ExpandedBottom(card: card, stale: context.isStale).environment(card.l10n) }
            } compactLeading: {
                CompactLeading(card: card)
            } compactTrailing: {
                CompactTrailing(card: card)
            } minimal: {
                MinimalGlyph(card: card)
            }
            .widgetURL(card.url)
            .keylineTint(card.line)
        }
    }
}
