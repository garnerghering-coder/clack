//
//  BoardRowView.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// One train on a departure or arrival board (DESIGN §2.5 BoardRow; named `BoardRowView` because `BoardRow` is the
/// board's data): the time, struck through under it when it moved; the destination (`rowTitle`); via and the service in
/// `caption`; the platform as a `PlatformTag`; the delay as `DelayText`. Cancelled trains are struck through, gone ones
/// fade. The compact variant is one line (a station sheet, a widget): time, destination, delay, platform.
public struct BoardRowView<Badge: View>: View {
    public struct Line: Sendable {
        /// The time to show (expected or actual) and the timetabled one.
        public var time: Double
        public var sched: Double
        public var tz: String
        public var destination: String
        /// "Via Hallsberg, Örebro" or "From …", already written.
        public var via: String?
        /// "SJ 529 · X 2000".
        public var service: String?
        /// The board's own notes (deviations), a short line in the accent ink.
        public var notes: String?
        public var platform: String?
        /// The platform it moved from ("" when the old one isn't known), when it changed.
        public var platformFrom: String?
        public var delay: Int?
        public var canceled: Bool
        /// "Departed" or "Arrived" once the train has gone.
        public var done: String?
        /// Gone a while ago: faded.
        public var past: Bool

        public init(
            time: Double, sched: Double, tz: String, destination: String, via: String? = nil, service: String? = nil,
            notes: String? = nil, platform: String? = nil, platformFrom: String? = nil, delay: Int? = nil,
            canceled: Bool = false, done: String? = nil, past: Bool = false
        ) {
            self.time = time
            self.sched = sched
            self.tz = tz
            self.destination = destination
            self.via = via
            self.service = service
            self.notes = notes
            self.platform = platform
            self.platformFrom = platformFrom
            self.delay = delay
            self.canceled = canceled
            self.done = done
            self.past = past
        }
    }

    @Environment(L10n.self) private var l10n
    public let line: Line
    public let clock: ClockFormat
    public var compact = false
    /// No 44 pt minimum: rows that can't be tapped and must fit (a widget).
    public var dense = false
    @ViewBuilder public var badge: Badge

    /// The time column, growing with the text size.
    @ScaledMetric(relativeTo: .body) private var timeWidth: CGFloat = 64

    public init(_ line: Line, clock: ClockFormat, compact: Bool = false, dense: Bool = false, @ViewBuilder badge: () -> Badge) {
        self.line = line
        self.clock = clock
        self.compact = compact || dense
        self.dense = dense
        self.badge = badge()
    }

    public var body: some View {
        Group {
            if compact { compactRow } else { fullRow }
        }
        .opacity(line.past ? 0.55 : 1)
        .contentShape(Rectangle())
    }

    private var destination: String { line.destination.isEmpty ? Format.unknown : line.destination }

    private var fullRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                FlapTime(time: line.time, tz: line.tz, clock: clock, style: .sm)
                if FlapTime.changed(line.time, from: line.sched) {
                    Text(Format.time(line.sched, tz: line.tz, clock: clock)).clack(.struck).strikethrough().monospacedDigit().foregroundStyle(Ink.text3)
                }
            }
            .frame(minWidth: timeWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                Text(destination).clack(.rowTitle).foregroundStyle(Ink.text).strikethrough(line.canceled)
                if let via = line.via { Text(via).clack(.caption).foregroundStyle(Ink.text2) }
                if line.service != nil || ObjectIdentifier(Badge.self) != ObjectIdentifier(EmptyView.self) {
                    HStack(spacing: 8) {
                        badge
                        if let service = line.service { Text(service).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1) }
                    }
                }
                if let notes = line.notes { Text(notes).clack(.caption).foregroundStyle(Ink.accentInk) }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 4) {
                if let platform = line.platform { PlatformTag(platform: platform, changedFrom: line.platformFrom) }
                if line.platformFrom != nil { Text(l10n.t("board.changed")).clack(.caption).foregroundStyle(Ink.lateInk) }
                delay
                if let done = line.done { Text(done).clack(.caption).foregroundStyle(Ink.text2) }
            }
        }
        .padding(.vertical, 12)
    }

    private var compactRow: some View {
        HStack(spacing: 8) {
            FlapTime(time: line.time, sched: line.sched, tz: line.tz, clock: clock, style: .text, strikeOld: false)
                .clack(.stopName).fontWeight(.semibold)
                .frame(minWidth: timeWidth * 0.75, alignment: .leading)
            badge
            Text(destination).clack(.stopName).fontWeight(.semibold).foregroundStyle(Ink.text).lineLimit(1)
                // A widget can't be opened for the rest: shrink a little before cutting.
                .minimumScaleFactor(dense ? 0.75 : 1)
                .strikethrough(line.canceled)
            Spacer(minLength: 4)
            delay
            if let platform = line.platform { PlatformTag(platform: platform, changedFrom: line.platformFrom) }
        }
        .frame(minHeight: dense ? nil : 44)
    }

    /// Cancelled, or the delay once the train has reported or been estimated; nothing from the timetable alone.
    @ViewBuilder
    private var delay: some View {
        if line.canceled {
            DelayText(delay: nil, canceled: true)
        } else if let delay = line.delay {
            DelayText(delay: delay)
        }
    }
}

extension BoardRowView where Badge == EmptyView {
    public init(_ line: Line, clock: ClockFormat, compact: Bool = false, dense: Bool = false) {
        self.init(line, clock: clock, compact: compact, dense: dense) { EmptyView() }
    }
}
