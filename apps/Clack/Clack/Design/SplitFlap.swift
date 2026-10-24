//
//  SplitFlap.swift
//  Clack
//

import ClackCore
import SwiftUI

/// The size of a split-flap display (styles.css `.flap-*`, `.time-flap`, `.board-flap`).
struct FlapSize {
    var font: CGFloat
    var lineHeight: CGFloat
    var gap: CGFloat
    /// Minimum tile width, in em.
    var minWidthEm: CGFloat
    var padX: CGFloat
    var radius: CGFloat

    static let board = FlapSize(font: 18, lineHeight: 24, gap: 1, minWidthEm: 0.62, padX: 1, radius: 4)
    static let sm = FlapSize(font: 14, lineHeight: 20, gap: 1, minWidthEm: 0.64, padX: 1, radius: 3)
    static let md = FlapSize(font: 22, lineHeight: 30, gap: 2, minWidthEm: 0.64, padX: 2, radius: 5)
    static let lg = FlapSize(font: 30, lineHeight: 40, gap: 3, minWidthEm: 0.66, padX: 2, radius: 6)
    /// The departure and arrival times on a trip.
    static let time = FlapSize(font: 34, lineHeight: 44, gap: 3, minWidthEm: 0.66, padX: 2, radius: 7)
}

/// One tile's top and bottom halves on the board (`--tflap-*`): dark in dark mode, pale in light mode.
private struct FlapFace: View {
    let char: String
    let size: FlapSize
    let half: Half
    var colour: Color?

    enum Half { case whole, top, bottom }

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tile = tileWidth
        ZStack {
            LinearGradient(stops: [
                .init(color: Ink.tflapTop, location: 0),
                .init(color: Ink.tflapTop, location: 0.49),
                .init(color: Ink.tflapBottom, location: 0.51),
                .init(color: Ink.tflapBottom, location: 1),
            ], startPoint: .top, endPoint: .bottom)
            Text(char)
                .font(ClackFont.grotesk(size.font, relativeTo: .title))
                .monospacedDigit()
                .foregroundStyle(colour ?? Ink.tflapText)
        }
        .frame(width: tile, height: size.lineHeight)
        .clipShape(HalfShape(half: half))
    }

    private var tileWidth: CGFloat { FlapFace.width(size) }

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
/// half drops into place: 180 ms ease-in, then 180 ms ease-out, started `delay` seconds from now.
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
        ZStack {
            if flipping, let from {
                // Underneath: the new top half and the old bottom half.
                FlapFace(char: char, size: size, half: .top, colour: colour)
                FlapFace(char: from, size: size, half: .bottom, colour: colour)
                // Leaves: the old top half turns away, the new bottom half turns into place.
                FlapFace(char: from, size: size, half: .top, colour: colour)
                    .rotation3DEffect(.degrees(started ? -90 : 0), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.4)
                    .animation(.easeIn(duration: 0.18).delay(delay), value: started)
                    .zIndex(2)
                FlapFace(char: char, size: size, half: .bottom, colour: colour)
                    .rotation3DEffect(.degrees(started ? 0 : 90), axis: (x: 1, y: 0, z: 0), anchor: .center, perspective: 0.4)
                    .animation(.easeOut(duration: 0.18).delay(delay + 0.18), value: started)
                    .zIndex(2)
            } else {
                FlapFace(char: char, size: size, half: .whole, colour: colour)
            }
            // The hinge across the middle.
            Rectangle().fill(Ink.tflapHinge).frame(height: 1).zIndex(3)
        }
        .frame(width: width, height: size.lineHeight)
        .clipShape(RoundedRectangle(cornerRadius: size.radius, style: .continuous))
        .overlay(alignment: .bottom) {
            // The tile's edge: a dark line along the bottom in dark mode, a soft outline in light mode.
            if scheme == .dark {
                Rectangle().fill(.black.opacity(0.4)).frame(height: 1)
                    .clipShape(RoundedRectangle(cornerRadius: size.radius, style: .continuous))
            }
        }
        .overlay {
            if scheme == .light {
                RoundedRectangle(cornerRadius: size.radius, style: .continuous).strokeBorder(.black.opacity(0.1), lineWidth: 1)
            }
        }
        .shadow(color: scheme == .light ? .black.opacity(0.08) : .clear, radius: 1, y: 1)
        .onAppear {
            if flipping { started = true }
        }
    }
}

/// Split-flap characters (DESIGN §10): each character sits on its own tile. When one changes, it flips (360 ms, 50 ms
/// stagger left to right), as on a departure board. Only changed characters flip; `intro` flips every tile in once
/// on first show. Reduced motion: no flip.
struct SplitFlap: View {
    let value: String
    var size: FlapSize = .time
    var intro = false
    var colour: Color?

    @State private var previous: String
    @State private var from: String
    @State private var sequence = 0

    init(value: String, size: FlapSize = .time, intro: Bool = false, colour: Color? = nil) {
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
            guard char != ":", char != " ", char != ".", sequence > 0 else { return nil }
            let before = index < old.count ? old[index] : " "
            guard before != char else { return nil }
            defer { count += 1 }
            return (before, Double(count) * 0.05)
        }
    }

    var body: some View {
        let chars = Array(value)
        let flips = plan(chars)
        HStack(spacing: size.gap) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                if char == ":" || char == " " || char == "." {
                    Text(String(char))
                        .font(ClackFont.grotesk(size.font, relativeTo: .title))
                        .foregroundStyle(Ink.text2)
                        .padding(.horizontal, 1)
                } else {
                    FlapTile(
                        char: String(char), from: flips[index].map { String($0.before) }, delay: flips[index]?.delay ?? 0,
                        size: size, colour: colour
                    )
                    // A new id per change restarts the animation.
                    .id("\(index)-\(sequence)")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value)
        .onAppear { settle(to: value) }
        .onChange(of: value) { _, new in settle(to: new) }
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
/// the new one is drawn in the accent colour.
struct FlapTime: View {
    enum Style { case text, sm, md, lg, time }

    let time: Double?
    var sched: Double?
    let tz: String
    let clock: ClockFormat
    var style: Style = .text
    var intro = false
    /// Show the timetabled time struck through beside a changed one (inside a trip), or only the new one (the Trips tab).
    var strikeOld = true

    var body: some View {
        if let time {
            let changed = sched.map { floor($0 / 60_000) != floor(time / 60_000) } ?? false
            let text = Format.time(time, tz: tz, clock: clock)
            let schedText = sched.map { Format.time($0, tz: tz, clock: clock) }
            HStack(spacing: 6) {
                if changed, strikeOld, let schedText {
                    Text(schedText)
                        .strikethrough()
                        .font(ClackFont.inter(style == .sm ? 12 : fontSize * 0.8, .medium))
                        .foregroundStyle(Ink.text3)
                        .lineLimit(1)
                        .fixedSize()
                }
                if style == .text {
                    Text(text)
                        .monospacedDigit()
                        .fontWeight(changed ? .bold : .regular)
                        .foregroundStyle(changed ? Ink.accentInk : Ink.text)
                } else {
                    SplitFlap(value: text, size: flapSize, intro: intro, colour: changed ? Ink.accentInk : nil)
                        .accessibilityLabel(changed ? "\(text) (\(schedText ?? ""))" : text)
                }
            }
        } else {
            Text("—").foregroundStyle(Ink.text2)
        }
    }

    private var fontSize: CGFloat { flapSize.font }

    private var flapSize: FlapSize {
        switch style {
        case .text, .sm: .sm
        case .md: .md
        case .lg: .lg
        case .time: .time
        }
    }
}
