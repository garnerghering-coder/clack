//
//  TimePair.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// A departure and an arrival, "08:03 – 10:51", with one separator (an en dash) and one "+1" style (`captionUpper`,
/// inline) when the arrival is on a later day. Digits are tabular. A time that differs from the timetable by a minute
/// or more is drawn in the accent ink; an unknown one is "—".
///
/// As text (`text`) it runs inside a line of other facts and wraps with it; as a view it can also sit on flap tiles.
public struct TimePair: View {
    public struct End: Sendable {
        public var time: Double?
        public var sched: Double?
        public var tz: String

        public init(time: Double?, sched: Double? = nil, tz: String) {
            self.time = time
            self.sched = sched
            self.tz = tz
        }
    }

    public let dep: End
    public let arr: End
    public let clock: ClockFormat
    /// Flap tiles for the times (the featured trip), or plain text when nil.
    public var flap: FlapTime.Style?
    public var intro = false

    public init(dep: End, arr: End, clock: ClockFormat, flap: FlapTime.Style? = nil, intro: Bool = false) {
        self.dep = dep
        self.arr = arr
        self.clock = clock
        self.flap = flap
        self.intro = intro
    }

    /// How many days after the departure's day the arrival is, in each station's own time zone (timetabled times).
    public static func plusDays(_ dep: End, _ arr: End) -> Int {
        guard let d = dep.sched ?? dep.time, let a = arr.sched ?? arr.time else { return 0 }
        return Format.dayOffset(from: d, fromTz: dep.tz, to: a, toTz: arr.tz)
    }

    public static let separator = " – "

    /// The pair as one run of text, for a caption line.
    public static func text(_ dep: End, _ arr: End, clock: ClockFormat) -> Text {
        var out = part(dep, clock: clock) + Text(separator).foregroundStyle(Ink.text3) + part(arr, clock: clock)
        let plus = plusDays(dep, arr)
        if plus > 0 { out = out + Text(" ") + plusText(plus) }
        return out.monospacedDigit()
    }

    private static func part(_ end: End, clock: ClockFormat) -> Text {
        guard let time = end.time else { return Text(Format.unknown).foregroundStyle(Ink.text2) }
        let shown = Text(Format.time(time, tz: end.tz, clock: clock))
        return FlapTime.changed(time, from: end.sched) ? shown.foregroundStyle(Ink.accentInk).bold() : shown
    }

    /// "+1", the one style for a later day.
    public static func plusText(_ days: Int) -> Text {
        let role = TextRole.captionUpper
        return Text("+\(days)").font(role.font).foregroundStyle(Ink.text2)
    }

    public var body: some View {
        if let flap {
            let plus = Self.plusDays(dep, arr)
            FlowLayout(spacing: 8, lineSpacing: 2) {
                FlapTime(time: dep.time, sched: dep.sched, tz: dep.tz, clock: clock, style: flap, intro: intro, strikeOld: false)
                Text("–").foregroundStyle(Ink.text3)
                FlapTime(time: arr.time, sched: arr.sched, tz: arr.tz, clock: clock, style: flap, intro: intro, strikeOld: false)
                if plus > 0 { Self.plusText(plus) }
            }
            .accessibilityElement(children: .combine)
        } else {
            Self.text(dep, arr, clock: clock)
        }
    }
}
