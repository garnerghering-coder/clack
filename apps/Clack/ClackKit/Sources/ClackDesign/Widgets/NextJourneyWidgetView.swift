//
//  NextJourneyWidgetView.swift
//  ClackDesign
//
//  The Next journey widget's Home Screen sizes (the Lock Screen ones stay in the extension). Before (route, countdown,
//  platform), on the train (next stop, arrival, progress), at a change (minutes to change, the next platform), and a
//  cancellation takes over the top line.
//
//  Nothing essential is cut (owner, 2026-10-24): the train number, platform, next stop, times and delay each have shorter
//  wordings (`FittingText`), lines stack when they don't fit side by side, and when the size is too small for everything
//  the secondary parts go first (the operator's name and icon, then the origin once you're on board, then a leg row,
//  then stops), through `ViewThatFits`.
//

import ClackCore
import SwiftUI

public struct NextJourneyWidgetView: View {
    var snapshot: WidgetSnapshot
    var date: Date
    var size: WidgetSize
    var isPlaceholder: Bool

    public init(snapshot: WidgetSnapshot, date: Date, size: WidgetSize, isPlaceholder: Bool = false) {
        self.snapshot = snapshot
        self.date = date
        self.size = size
        self.isPlaceholder = isPlaceholder
    }

    private var now: Double { wMs(date) }
    private var l10n: L10n { WidgetWords.l10n(snapshot.language) }
    private var clock: ClockFormat { snapshot.clock }
    private var shown: WidgetTimeline.Shown? { WidgetTimeline.shown(snapshot, at: now) }

    public var body: some View {
        Group {
            if let shown, let leg = shown.leg {
                switch size {
                case .small: small(shown, leg)
                case .medium: medium(shown, leg)
                case .large: large(shown, leg)
                }
            } else {
                EmptyWidget(title: l10n.t("widgets.noJourney"), hint: l10n.t("widgets.noJourneyHint"))
            }
        }
        .environment(l10n)
        .placeholder(isPlaceholder)
    }

    // MARK: what to say

    private func time(_ ms: Double, _ tz: String) -> String { Format.time(ms, tz: tz, clock: clock) }

    /// The delay that matters now: the departure's until you leave, then the arrival's.
    private func delay(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> Int? {
        if case .before = s.moment { return l.depDelayMin }
        if case .changing = s.moment { return l.depDelayMin }
        return l.arrDelayMin
    }

    /// "SJ 529", then "529" alone: the train number is the part that must stay.
    private func services(_ l: WidgetSnapshot.Leg) -> [String] {
        let full = [l.operatorName, l.train].compactMap { $0 }.joined(separator: " ")
        guard let train = l.train, full != train else { return [full.isEmpty ? Format.unknown : full] }
        return [full, train]
    }

    /// "Car 4 · Seat 23" while it's still ahead or under way; not once you're off. On the medium and large sizes (the
    /// small one has no line to spare).
    private func seat(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> String? {
        if case .finished = s.moment { return nil }
        return Seat.label(l10n, coach: l.coach, seat: l.seat)
    }

    /// "Departs in {{time}}" with the time as a running timer (within the hour: it counts by itself) or the countdown's
    /// words.
    private func departsIn(_ l: WidgetSnapshot.Leg) -> Text {
        let template = l10n.t("trips.departsIn")
        let parts = template.components(separatedBy: "{{time}}")
        let middle: Text
        if l.depAt - now <= 3_600_000 {
            middle = Text(timerInterval: date...max(date, wDate(l.depAt)), countsDown: true)
        } else {
            middle = Text(WidgetTimeline.text(WidgetTimeline.countdown(to: l.depAt, now: now)))
        }
        let before = parts.first ?? "", after = parts.count > 1 ? parts[1] : ""
        return Text("\(before)\(middle)\(after)")
    }

    /// The line under the route: a cancellation takes over, else what the moment is.
    private func headline(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> Text {
        if l.canceled { return Text(l10n.t("status.cancelled")).foregroundStyle(DelayBand.cancelled.ink) }
        switch s.moment {
        case .before:
            if l.status == "boarding" { return Text(l10n.t("trips.boarding")) }
            return departsIn(l)
        case .onTrain:
            if let stop = l.nextStop { return Text(l10n.t("live.nextStopName", ["name": stop])) }
            return Text(l10n.t("live.arrives", ["time": time(l.arrAt, l.toTz)]))
        case .changing(let next, let spare):
            return Text(l10n.t("journey.transfer", ["min": String(spare), "station": s.legs[next].from]))
        case .finished:
            return Text(l10n.t("trips.arrivedAt", ["time": time(l.arrAt, l.toTz)]))
        }
    }

    /// The headline on up to two lines, shrinking a little only if two lines are not enough.
    private func headlineView(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, ink: Color) -> some View {
        headline(s, l).clack(.caption).foregroundStyle(ink)
            .lineLimit(2).minimumScaleFactor(WidgetInsets.minimumScale)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The big time: departure before, arrival on the train and after.
    private func bigTime(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> String {
        switch s.moment {
        case .before, .changing: time(l.depAt, l.fromTz)
        case .onTrain, .finished: time(l.arrAt, l.toTz)
        }
    }

    private func platformCode(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> String? {
        switch s.moment {
        case .before, .changing: l.depPlatform
        case .onTrain, .finished: l.arrPlatform
        }
    }

    /// "Platform 12b", then "Pl 12b".
    private func platformWords(_ code: String) -> [String] {
        [l10n.t("trips.platform", ["platform": code]), l10n.t("tripCard.platformShort", ["platform": code])]
    }

    private var onBoard: Bool {
        guard let shown else { return false }
        switch shown.moment {
        case .onTrain, .finished: return true
        case .before, .changing: return false
        }
    }

    // MARK: pieces

    /// On the train, a bar that fills by itself between the departure and arrival (no redraw needed); the known
    /// position when the times can't say.
    @ViewBuilder
    private func progress(_ s: WidgetTimeline.Shown) -> some View {
        if case .onTrain(_, let p) = s.moment {
            if let l = s.leg, l.arrAt > l.depAt {
                ProgressView(timerInterval: wDate(l.depAt)...wDate(l.arrAt), countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear)
                    .tint(Ink.accent)
            } else {
                ProgressBar(value: p, color: Ink.accent)
            }
        }
    }

    /// The train and its delay on one line: the icon and the operator's name give way before the number does.
    private func topLine(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        let names = services(l)
        return HStack(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    LucideIcon(name: "train-front", size: 14).foregroundStyle(Ink.accentInk)
                    Text(names[0]).lineLimit(1).fixedSize()
                }
                FittingText(names)
            }
            .clack(.trainNumber)
            .foregroundStyle(Ink.text2)
            .layoutPriority(1)
            Spacer(minLength: 0)
            DelayText(delay: delay(s, l), canceled: l.canceled)
        }
    }

    private func updated() -> some View {
        UpdatedLine(updatedAt: snapshot.updatedAt, now: date, l10n: l10n, clock: clock)
    }

    private func bigTimeText(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        Text(bigTime(s, l)).clack(.bigTime).monospacedDigit().foregroundStyle(Ink.text).strikethrough(l.canceled)
            .lineLimit(1).fixedSize()
    }

    // MARK: small

    private func small(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        // Everything, then the route on one line, then (on board, where it no longer matters) without the origin.
        ViewThatFits(in: .vertical) {
            smallBody(s, l, route: .twoLines)
            smallBody(s, l, route: .oneLine)
            if onBoard { smallBody(s, l, route: .destination) }
            smallBody(s, l, route: .oneLine, headlineLines: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private enum RouteForm { case twoLines, oneLine, destination }

    @ViewBuilder
    private func smallRoute(_ l: WidgetSnapshot.Leg, _ form: RouteForm) -> some View {
        switch form {
        case .twoLines:
            FittingText(l.from).clack(.rowTitle).foregroundStyle(Ink.text)
            FittingText(l.to).clack(.rowTitle).foregroundStyle(Ink.text2)
        case .oneLine:
            FittingText(l10n.t("tripCard.route", ["from": l.from, "to": l.to])).clack(.stopName).fontWeight(.semibold).foregroundStyle(Ink.text)
        case .destination:
            FittingText("→ \(l.to)").clack(.rowTitle).foregroundStyle(Ink.text)
        }
    }

    private func smallBody(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, route: RouteForm, headlineLines: Int = 2) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            topLine(s, l)
            smallRoute(l, route)
            Spacer(minLength: 0)
            // The time with the platform beside it, else the short platform, else under it.
            ViewThatFits(in: .horizontal) {
                ForEach(platformCode(s, l).map(platformWords) ?? [""], id: \.self) { words in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        bigTimeText(s, l)
                        Text(words).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1).fixedSize()
                    }
                }
                VStack(alignment: .leading, spacing: 0) {
                    bigTimeText(s, l)
                    if let code = platformCode(s, l) { FittingText(platformWords(code)).clack(.caption).foregroundStyle(Ink.text2) }
                }
            }
            progress(s)
            headline(s, l).clack(.caption).foregroundStyle(Ink.text2)
                .lineLimit(headlineLines).minimumScaleFactor(WidgetInsets.minimumScale)
                .fixedSize(horizontal: false, vertical: true)
            updated()
        }
    }

    // MARK: medium and large

    /// The train, what's happening and the seat as one block on the leading side; the big time on the trailing side,
    /// centred on the block's height (owner, 2026-10-24).
    private func header(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                topLine(s, l)
                headlineView(s, l, ink: Ink.text)
                if let seat = seat(s, l) { FittingText(seat).clack(.caption).foregroundStyle(Ink.text2) }
            }
            bigTimeText(s, l)
        }
    }

    private func legRow(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, index: Int) -> some View {
        let active = s.moment.legIndex == index
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    FittingText(services(l)).clack(.trainNumber).foregroundStyle(Ink.text2)
                    DelayText(delay: l.depDelayMin, canceled: l.canceled)
                }
                FittingText(l10n.t("tripCard.route", ["from": l.from, "to": l.to])).clack(.stopName).foregroundStyle(Ink.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .trailing, spacing: 2) {
                Text(time(l.depAt, l.fromTz)).clack(.boardDestination).monospacedDigit().foregroundStyle(Ink.text)
                    .strikethrough(l.canceled).lineLimit(1).fixedSize()
                if let p = l.depPlatform { FittingText(platformWords(p)).clack(.caption).foregroundStyle(Ink.text2) }
            }
            .layoutPriority(1)
        }
        .opacity(active || s.moment.legIndex == nil ? 1 : 0.6)
    }

    /// The legs around the one under way: it and the next (or the last two).
    private func visibleLegs(_ s: WidgetTimeline.Shown, count: Int) -> [(Int, WidgetSnapshot.Leg)] {
        let start = min(s.moment.legIndex ?? 0, max(0, s.legs.count - count))
        return Array(s.legs.enumerated()).dropFirst(start).prefix(count).map { ($0.offset, $0.element) }
    }

    private func mediumBody(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, legs: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            header(s, l)
            progress(s)
            Spacer(minLength: 0)
            ForEach(visibleLegs(s, count: legs), id: \.1.id) { i, leg in legRow(s, leg, index: i) }
            updated()
        }
    }

    private func medium(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        // Two leg rows when they fit, else one: the header (train, delay, time, platform in the row) always stays.
        ViewThatFits(in: .vertical) {
            mediumBody(s, l, legs: 2)
            mediumBody(s, l, legs: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Up to `count` stops around the next one (from the start before you board).
    private func stopWindow(_ l: WidgetSnapshot.Leg, count: Int) -> [String] {
        let next = l.nextStop.flatMap { l.stops.firstIndex(of: $0) } ?? 0
        let start = max(0, min(next - 1, l.stops.count - count))
        return Array(l.stops.dropFirst(start).prefix(count))
    }

    private func largeBody(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, stops: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            mediumBody(s, l, legs: 2)
            if !l.stops.isEmpty, stops > 0 {
                Rectangle().fill(Ink.hairline).frame(height: 1)
                Text(l10n.t("detail.stops")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(stopWindow(l, count: stops).enumerated()), id: \.offset) { _, name in
                        let next = name == l.nextStop
                        HStack(spacing: 8) {
                            Circle().fill(next ? Ink.accent : Ink.text3).frame(width: 6, height: 6)
                            FittingText(name).clack(.stopName).fontWeight(next ? .bold : .regular).foregroundStyle(Ink.text)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func large(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        ViewThatFits(in: .vertical) {
            largeBody(s, l, stops: 7)
            largeBody(s, l, stops: 5)
            largeBody(s, l, stops: 3)
            largeBody(s, l, stops: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
