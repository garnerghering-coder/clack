//
//  SplitFlap.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// The size of a split-flap display (styles.css `.flap-*`, `.time-flap`, `.board-flap`), at the default text size. The
/// tiles grow with Dynamic Type (`@ScaledMetric`), as the digits on them do.
public struct FlapSize: Sendable {
    public var font: CGFloat
    public var lineHeight: CGFloat
    public var gap: CGFloat
    /// Minimum tile width, in em.
    public var minWidthEm: CGFloat
    public var padX: CGFloat
    public var radius: CGFloat

    public static let sm = FlapSize(font: 14, lineHeight: 20, gap: 1, minWidthEm: 0.64, padX: 1, radius: 3)
    public static let md = FlapSize(font: 22, lineHeight: 30, gap: 2, minWidthEm: 0.64, padX: 2, radius: 5)
    public static let lg = FlapSize(font: 30, lineHeight: 40, gap: 3, minWidthEm: 0.66, padX: 2, radius: 6)
    /// The departure and arrival times on a trip.
    public static let time = FlapSize(font: 34, lineHeight: 44, gap: 3, minWidthEm: 0.66, padX: 2, radius: 7)

    /// The same size multiplied by a Dynamic Type factor (1 at the default size).
    func scaled(_ factor: CGFloat) -> FlapSize {
        FlapSize(
            font: font * factor, lineHeight: lineHeight * factor, gap: gap * factor, minWidthEm: minWidthEm,
            padX: padX * factor, radius: radius * factor
        )
    }
}

/// One tile's top and bottom halves on the board (`--tflap-*`): dark in dark mode, pale in light mode.
private struct FlapFace: View {
    let char: String
    let size: FlapSize
    let half: Half
    var colour: Color?

    enum Half { case whole, top, bottom }

    var body: some View {
        ZStack {
            LinearGradient(stops: [
                .init(color: Ink.tflapTop, location: 0),
                .init(color: Ink.tflapTop, location: 0.49),
                .init(color: Ink.tflapBottom, location: 0.51),
                .init(color: Ink.tflapBottom, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            Text(char)
                // The tile is already sized for Dynamic Type; the digit follows the tile, not the text style again.
                .font(ClackFont.groteskFixed(size.font))
                .monospacedDigit()
                .foregroundStyle(colour ?? Ink.tflapText)
                // A wide letter (M, W) is a little narrower than its natural width rather than cut off by the tile.
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: FlapFace.width(size))
        }
        .frame(width: FlapFace.width(size), height: size.lineHeight)
        .clipShape(HalfShape(half: half))
    }

    static func width(_ size: FlapSize) -> CGFloat {
        // A digit in Space Grotesk is a little wider than 0.6 em; the minimum keeps narrow ones (1) as wide as the rest.
        max(size.minWidthEm * size.font, size.font * 0.6 + 2 * size.padX)
    }
}

/// Clips to the top or bottom half of the rectangle (`clip-path: inset(0 0 50% 0)` and `inset(50% 0 0 0)`).
private struct HalfShape: Shape {
    let half: FlapFace.Half

    func path(in rect: CGRect) -> Path {
        switch half {
        case .whole: Path(rect)
        case .top: Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height / 2))
        case .bottom: Path(CGRect(x: rect.minX, y: rect.midY, width: rect.width, height: rect.height / 2))
        }
    }
}

/// A single flap tile. When `from` differs, the top half of the old character falls away and the new one's bottom
/// half drops into place: `Motion.flapHalf` ease-in, then the same ease-out, started `delay` seconds from now.
private struct FlapTile: View {
    let char: String
    let from: String?
    let delay: Double
    let size: FlapSize
    var colour: Color?

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = false

    private var flipping: Bool { from != nil && !reduceMotion }

    var body: some View {
        let width = FlapFace.width(size)
        let shape = RoundedRectangle(cornerRadius: size.radius, style: .continuous)
        ZStack {
            if flipping, let from {
                // Underneath: the new top half and the old bottom half.
                FlapFace(char: char, size: size, half: .top, colour: colour)
                FlapFace(char: from, size: size, half: .bottom, colour: colour)
                // Leaves: the old top half turns away, the new bottom half turns into place.
                FlapFace(char: from, size: size, half: .top, colour: colour)
                    .rotation3DEffect(.degrees(started ? -90 : 0), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.4)
                    .animation(.easeIn(duration: Motion.flapHalf).delay(delay), value: started)
                    .zIndex(2)
                FlapFace(char: char, size: size, half: .bottom, colour: colour)
                    .rotation3DEffect(.degrees(started ? 0 : 90), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.4)
                    .animation(.easeOut(duration: Motion.flapHalf).delay(delay + Motion.flapHalf), value: started)
                    .zIndex(2)
            } else {
                FlapFace(char: char, size: size, half: .whole, colour: colour)
            }
            // The hinge across the middle.
            Rectangle().fill(Ink.tflapHinge).frame(height: 1).zIndex(3)
        }
        .frame(width: width, height: size.lineHeight)
        .clipShape(shape)
        .overlay(alignment: .bottom) {
            // The tile's edge: a dark line along the bottom in dark mode, a soft outline in light mode.
            if scheme == .dark {
                Rectangle().fill(Color.black.opacity(0.4)).frame(height: 1).clipShape(shape)
            }
        }
        .overlay {
            if scheme == .light { shape.strokeBorder(Color.black.opacity(0.1), lineWidth: 1) }
        }
        .shadow(color: scheme == .light ? Color.black.opacity(0.08) : .clear, radius: 1, y: 1)
        .onAppear {
            if flipping { started = true }
        }
    }
}

/// Split-flap characters (DESIGN §10): each character sits on its own tile. When one changes, it flips (two
/// `Motion.flapHalf` halves, `Motion.flapStagger` between changed tiles, left to right), as on a departure board. Only
/// changed characters flip; `intro` flips every tile in once on first show. Reduce Motion: the changed tiles
/// cross-fade instead. `tick` plays one light haptic when a change (not the first show) has landed. The tiles scale
/// with Dynamic Type.
public struct SplitFlap: View {
    public let value: String
    public var size: FlapSize = .time
    public var intro = false
    public var colour: Color?
    /// Seconds between one tile's flip and the next's, left to right.
    public var stagger: Double = Motion.flapStagger
    /// One light tick (Haptic.snap) when a live change has landed: the "clack" (polish pass 1, signature moment 2).
    public var tick = false

    /// 100 at the default text size; the tiles are multiplied by this / 100.
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 100
    @State private var previous: String
    @State private var from: String
    @State private var sequence = 0
    @State private var landed = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        value: String, size: FlapSize = .time, intro: Bool = false, colour: Color? = nil,
        stagger: Double = Motion.flapStagger, tick: Bool = false
    ) {
        self.stagger = stagger
        self.tick = tick
        self.value = value
        self.size = size
        self.intro = intro
        self.colour = colour
        let start = intro ? String(repeating: " ", count: value.count) : value
        _previous = State(initialValue: start)
        _from = State(initialValue: start)
    }

    /// For each character: the character it replaces and its flip delay, or nil when it doesn't flip. Only the tiles
    /// that flip are counted for the 50 ms stagger.
    private func plan(_ chars: [Character]) -> [(before: Character, delay: Double)?] {
        let old = Array(from)
        var count = 0
        return chars.enumerated().map { index, char in
            guard !Self.isSeparator(char), sequence > 0 else { return nil }
            let before = index < old.count ? old[index] : " "
            guard before != char else { return nil }
            defer { count += 1 }
            return (before, Double(count) * stagger)
        }
    }

    private static func isSeparator(_ char: Character) -> Bool { char == ":" || char == " " || char == "." }

    public var body: some View {
        let chars = Array(value)
        let flips = plan(chars)
        let shown = size.scaled(scale / 100)
        HStack(spacing: shown.gap) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                if Self.isSeparator(char) {
                    Text(String(char))
                        .font(ClackFont.groteskFixed(shown.font))
                        .foregroundStyle(Ink.text2)
                        .padding(.horizontal, Space.xxs / 2)
                } else {
                    FlapTile(
                        char: String(char), from: flips[index].map { String($0.before) }, delay: flips[index]?.delay ?? 0,
                        size: shown, colour: colour
                    )
                    // A new id for a tile that changes restarts its flip (or, with Reduce Motion, cross-fades it);
                    // the others keep theirs.
                    .id(flips[index] == nil ? "\(index)" : "\(index)-\(sequence)")
                    .transition(.opacity)
                }
            }
        }
        .animation(reduceMotion ? Motion.reduced : nil, value: sequence)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value)
        .haptic(.snap, trigger: landed)
        .onAppear { settle(to: value) }
        .onChange(of: value) { _, new in
            settle(to: new)
            guard tick else { return }
            // The last changed tile lands after its stagger and both halves.
            let changed = zip(Array(from), Array(new)).filter { $0 != $1 }.count + abs(from.count - new.count)
            let total = Double(max(changed - 1, 0)) * stagger + 2 * Motion.flapHalf
            Task {
                try? await Task.sleep(for: .seconds(reduceMotion ? 0 : total))
                landed += 1
            }
        }
    }

    private func settle(to new: String) {
        guard previous != new else { return }
        from = previous
        sequence += 1
        previous = new
    }
}

/// A time on flip cards for the main time on a screen, and plain text elsewhere (owner feedback 2026-10-21). When the
/// expected time differs from the timetable by a minute or more, the timetabled one is struck through beside it and
/// the new one is drawn in the accent colour (or `colour`, the delay band's ink, where a stop list asks for it).
public struct FlapTime: View {
    public enum Style: Sendable { case text, sm, md, lg, time }

    public let time: Double?
    public var sched: Double?
    public let tz: String
    public let clock: ClockFormat
    public var style: Style = .text
    public var intro = false
    /// Show the timetabled time struck through beside a changed one (inside a trip), or only the new one (the Trips tab).
    public var strikeOld = true
    /// The colour of a changed time; the accent ink when not given.
    public var colour: Color?
    /// A light tick when a live change has landed (flip styles only).
    public var tick = false

    public init(
        time: Double?, sched: Double? = nil, tz: String, clock: ClockFormat, style: Style = .text, intro: Bool = false,
        strikeOld: Bool = true, colour: Color? = nil, tick: Bool = false
    ) {
        self.tick = tick
        self.time = time
        self.sched = sched
        self.tz = tz
        self.clock = clock
        self.style = style
        self.intro = intro
        self.strikeOld = strikeOld
        self.colour = colour
    }

    /// Whether a changed time is worth the accent colour: 6 minutes or more either way (designer, 2026-11-14: "a
    /// one-minute delay on a finished trip gets the biggest, brightest text on the card"). Smaller changes still show
    /// the timetabled time struck through, in plain ink.
    public static func notable(_ time: Double?, from sched: Double?) -> Bool {
        guard let time, let sched else { return false }
        return abs(floor(time / 60_000) - floor(sched / 60_000)) > Double(5)
    }

    /// Whether `time` is in a different minute from `sched`.
    public static func changed(_ time: Double?, from sched: Double?) -> Bool {
        guard let time, let sched else { return false }
        return floor(sched / 60_000) != floor(time / 60_000)
    }

    public var body: some View {
        if let time {
            let changed = Self.changed(time, from: sched)
            let text = Format.time(time, tz: tz, clock: clock)
            let schedText = sched.map { Format.time($0, tz: tz, clock: clock) }
            HStack(spacing: Space.xs) {
                if changed, strikeOld, let schedText {
                    Text(schedText)
                        .clack(.struck).strikethrough().monospacedDigit()
                        .foregroundStyle(Ink.text3)
                        .lineLimit(1)
                        .fixedSize()
                }
                if style == .text {
                    let notable = Self.notable(time, from: sched)
                    Text(text)
                        .monospacedDigit()
                        .fontWeight(notable ? .bold : nil)
                        .foregroundStyle(notable ? (colour ?? Ink.accentInk) : Ink.text)
                        .contentTransition(.numericText())
                } else {
                    SplitFlap(value: text, size: flapSize, intro: intro, colour: Self.notable(time, from: sched) ? (colour ?? Ink.accentInk) : nil, tick: tick)
                        .accessibilityLabel(changed ? "\(text) (\(schedText ?? ""))" : text)
                }
            }
        } else {
            Text(Format.unknown).foregroundStyle(Ink.text2)
        }
    }

    private var flapSize: FlapSize {
        switch style {
        case .text, .sm: .sm
        case .md: .md
        case .lg: .lg
        case .time: .time
        }
    }
}
