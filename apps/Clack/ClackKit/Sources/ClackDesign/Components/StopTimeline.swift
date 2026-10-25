//
//  StopTimeline.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// The vertical rail beside a stop (DESIGN §2.5 StopTimeline): 2 pt. Where the train has been it is the operator's
/// colour; the rest of the ride is dotted, still to go; stretches you don't ride are a hairline. Dots are 10 pt, 14 pt
/// where you get on and off. It starts at the middle of the first stop and ends at the middle of the last, and a small
/// dot shows the train between stops while it's under way.
public struct StopRail: View {
    public let color: Color
    /// Where you get on or off (the bigger dot in the operator's colour).
    public var big = false
    public var ridden = true
    /// No line above (the first stop) or below (the last).
    public var startsHere = false
    public var endsHere = false
    public var above = TripDetailLogic.RailHalf()
    public var below = TripDetailLogic.RailHalf()

    public static let width: CGFloat = 20

    public init(
        color: Color, big: Bool = false, ridden: Bool = true, startsHere: Bool = false, endsHere: Bool = false,
        above: TripDetailLogic.RailHalf = .init(), below: TripDetailLogic.RailHalf = .init()
    ) {
        self.color = color
        self.big = big
        self.ridden = ridden
        self.startsHere = startsHere
        self.endsHere = endsHere
        self.above = above
        self.below = below
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if startsHere { Color.clear.frame(maxHeight: .infinity) } else { half(above).frame(maxHeight: .infinity) }
                if endsHere { Color.clear.frame(maxHeight: .infinity) } else { half(below).frame(maxHeight: .infinity) }
            }
            .frame(width: 14)
            Circle()
                .fill(big ? color : (ridden ? (covered ? color : Ink.text) : Ink.text3))
                .frame(width: big ? 14 : 10, height: big ? 14 : 10)
                .overlay(Circle().strokeBorder(big ? Ink.text : Ink.bg, lineWidth: 2).padding(-2))
        }
        .frame(width: Self.width)
        .accessibilityHidden(true)
    }

    /// A stop the train has passed: the line below it has started to fill.
    private var covered: Bool { below.fill > 0 || above.fill >= 1 }

    private func half(_ half: TripDetailLogic.RailHalf) -> some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ZStack(alignment: .top) {
                if half.ridden {
                    // Still to go: dotted.
                    Path { p in
                        p.move(to: CGPoint(x: 7, y: 0))
                        p.addLine(to: CGPoint(x: 7, y: h))
                    }
                    .stroke(Ink.text3, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 5]))
                    if half.fill > 0 { color.frame(width: 2, height: h * half.fill).frame(maxWidth: .infinity) }
                } else {
                    Ink.hairline.frame(width: 2).frame(maxWidth: .infinity)
                }
                if let train = half.train {
                    Circle().fill(color).frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(Ink.markerRing, lineWidth: 2))
                        .shadow(color: Color.black.opacity(0.3), radius: 2, y: 1)
                        .frame(maxWidth: .infinity)
                        .offset(y: h * train - 5)
                }
            }
        }
    }
}

/// One stop of a timeline (DESIGN §2.5): the rail, the name with its notes, the time on the right (split-flap `.sm` in
/// the delay band's ink, the timetabled one struck through under it in `struck`), and the platform in a fixed column as
/// a `PlatformTag` (a dash when none is known, so the rows line up). The compact variant (sheets, the watch) is tighter
/// but has the same split-flap times.
public struct StopRow: View {
    public enum Emphasis: Sendable {
        /// A stop you ride through: the name in 600.
        case ridden
        /// Before you get on or after you get off: dimmed.
        case dim
        /// A stop on a train you aren't on: the name in the body weight.
        case plain
        /// The next stop: the name in 600.
        case next
    }

    public struct Note: Hashable, Sendable {
        public enum Tone: Sendable { case accent, secondary, warning }
        public var text: String
        public var tone: Tone

        public init(_ text: String, _ tone: Tone = .secondary) {
            self.text = text
            self.tone = tone
        }
    }

    @Environment(L10n.self) private var l10n
    public let name: String
    public var emphasis: Emphasis = .ridden
    public var canceled = false
    public var notes: [Note] = []
    public let rail: StopRail
    /// The time to show (actual or expected), and the timetabled one.
    public var time: Double?
    public var sched: Double?
    /// Whether `time` is known from a report or estimate (colours it by `delay`).
    public var live = false
    public var delay: Int?
    public var tz: String
    public var clock: ClockFormat
    public var platform: String?
    public var platformChanged = false
    public var compact = false
    /// Asks for the platform when none is known (your own trip's boarding and alighting stops).
    public var onSetPlatform: (() -> Void)?
    /// Opens the station's board when the name is tapped.
    public var onOpen: (() -> Void)?
    public var openLabel: String?

    public init(
        name: String, emphasis: Emphasis = .ridden, canceled: Bool = false, notes: [Note] = [], rail: StopRail,
        time: Double?, sched: Double? = nil, live: Bool = false, delay: Int? = nil, tz: String, clock: ClockFormat,
        platform: String? = nil, platformChanged: Bool = false, compact: Bool = false,
        onSetPlatform: (() -> Void)? = nil, onOpen: (() -> Void)? = nil, openLabel: String? = nil
    ) {
        self.onSetPlatform = onSetPlatform
        self.name = name
        self.emphasis = emphasis
        self.canceled = canceled
        self.notes = notes
        self.rail = rail
        self.time = time
        self.sched = sched
        self.live = live
        self.delay = delay
        self.tz = tz
        self.clock = clock
        self.platform = platform
        self.platformChanged = platformChanged
        self.compact = compact
        self.onOpen = onOpen
        self.openLabel = openLabel
    }

    /// The platform column: wide enough for "17b" and a changed mark, growing with the text size.
    @ScaledMetric(relativeTo: .footnote) private var platformWidth: CGFloat = 44

    public var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                rail
                VStack(alignment: .leading, spacing: 0) {
                    nameView
                    ForEach(notes, id: \.self) { note in
                        Text(note.text).clack(.caption).foregroundStyle(ink(note.tone))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, compact ? 4 : 8)
                timeView
            }
            .accessibilityElement(children: .combine)
            // Its own element: the dash that asks for the platform is a button of its own.
            platformView
        }
        .frame(minHeight: compact ? 44 : 48)
    }

    private func ink(_ tone: Note.Tone) -> Color {
        switch tone {
        case .accent: Ink.accentInk
        case .secondary: Ink.text2
        case .warning: Ink.lateInk
        }
    }

    @ViewBuilder
    private var nameView: some View {
        let text = Text(name)
            .clack(emphasis == .ridden || emphasis == .next ? .rowTitle : .body)
            .fontWeight(emphasis == .dim ? .medium : nil)
            .foregroundStyle(emphasis == .dim ? Ink.text3 : Ink.text)
            .strikethrough(canceled)
            .opacity(canceled ? 0.6 : 1)
            .multilineTextAlignment(.leading)
        if let onOpen {
            Button(action: onOpen) { text }
                .buttonStyle(.plain)
                .accessibilityLabel(openLabel ?? name)
        } else {
            text
        }
    }

    @ViewBuilder
    private var timeView: some View {
        let band = DelayBand(delayMin: delay, canceled: canceled)
        let tint: Color? = live ? band.ink : nil
        let shown = time ?? sched
        if shown != nil {
        VStack(alignment: .trailing, spacing: 0) {
            SplitFlap(value: Format.time(shown, tz: tz, clock: clock), size: .sm, colour: tint)
                .opacity(emphasis == .dim ? 0.6 : 1)
            if FlapTime.changed(time, from: sched), let sched {
                Text(Format.time(sched, tz: tz, clock: clock))
                    .clack(.struck).strikethrough().monospacedDigit().foregroundStyle(Ink.text3)
            }
        }
        .opacity(canceled ? 0.5 : 1)
        .overlay { if canceled { Rectangle().fill(Ink.text2).frame(height: 1.5) } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeLabel(shown))
        }
    }

    private func timeLabel(_ shown: Double?) -> String {
        guard shown != nil else { return "" }
        let main = Format.time(shown, tz: tz, clock: clock)
        if canceled { return Format.join([main, l10n.t("delay.cancelled")], separator: ", ") }
        if FlapTime.changed(time, from: sched), let sched {
            return Format.join([main, l10n.t("detail.timetabledTime", ["time": Format.time(sched, tz: tz, clock: clock)])], separator: ", ")
        }
        return main
    }

    private var platformView: some View {
        Group {
            if let platform {
                PlatformTag(platform: platform, changedFrom: platformChanged ? "" : nil)
            } else {
                UnknownPlatformTag(onSet: onSetPlatform)
            }
        }
        .frame(minWidth: platformWidth, alignment: .trailing)
    }
}
