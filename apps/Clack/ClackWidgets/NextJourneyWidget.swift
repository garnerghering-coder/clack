//
//  NextJourneyWidget.swift
//  ClackWidgets
//
//  One widget for the next journey that follows it through: before (route, countdown, platform), on the train (next stop,
//  arrival, progress), at a change (minutes to change, the next platform), and a cancellation takes over the top line.
//  It fetches for itself (`WidgetData.load`); the timeline (`WidgetTimeline`) redraws it every minute around the trip,
//  and moves on to the next journey when this one ends.
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

struct JourneyEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    var isPlaceholder = false
    var relevance: TimelineEntryRelevance?
}

struct JourneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> JourneyEntry {
        JourneyEntry(date: .now, snapshot: .placeholder(now: .now), isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (JourneyEntry) -> Void) {
        guard let cached = WidgetSnapshot.load() else {
            completion(placeholder(in: context))
            return
        }
        completion(JourneyEntry(date: .now, snapshot: cached))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<JourneyEntry>) -> Void) {
        Task {
            // The app may have written it a moment ago (it reloads this widget when it does).
            let snapshot = await WidgetData.load(.journey, maxAge: 60_000)
            let now = wMs(.now)
            let entries = WidgetTimeline.journeyEntries(snapshot, now: now).map { at in
                JourneyEntry(date: wDate(at), snapshot: snapshot, relevance: TimelineEntryRelevance(score: WidgetTimeline.relevance(snapshot, at: at)))
            }
            completion(Timeline(entries: entries, policy: .after(wDate(WidgetTimeline.journeyReload(snapshot, now: now)))))
        }
    }
}

struct NextJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.nextJourney, provider: JourneyProvider()) { entry in
            NextJourneyView(entry: entry)
                .containerBackground(for: .widget) { TintedBackground(hex: WidgetTimeline.shown(entry.snapshot, at: wMs(entry.date))?.leg?.color) }
                .widgetURL(WidgetTimeline.shown(entry.snapshot, at: wMs(entry.date))?.leg.flatMap { WidgetLinks.trip($0.id) })
        }
        .configurationDisplayName(WidgetWords.t("widgets.nextJourney.name"))
        .description(WidgetWords.t("widgets.nextJourney.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .freshnessPushHandler()
    }
}

// MARK: look

private struct NextJourneyView: View {
    @Environment(\.widgetFamily) private var family
    var entry: JourneyEntry

    private var now: Double { wMs(entry.date) }
    private var l10n: L10n { WidgetWords.l10n(entry.snapshot.language) }
    private var clock: ClockFormat { entry.snapshot.clock }
    private var shown: WidgetTimeline.Shown? { WidgetTimeline.shown(entry.snapshot, at: now) }

    var body: some View {
        Group {
            if let shown, let leg = shown.leg {
                switch family {
                case .accessoryCircular: circular(shown, leg)
                case .accessoryRectangular: rectangular(shown, leg)
                case .accessoryInline: inline(shown, leg)
                case .systemSmall: small(shown, leg)
                case .systemMedium: medium(shown, leg)
                default: large(shown, leg)
                }
            } else if family == .accessoryInline {
                Text(l10n.t("widgets.noJourney"))
            } else if family == .accessoryCircular || family == .accessoryRectangular {
                ZStack {
                    AccessoryWidgetBackground()
                    LucideIcon(name: "train-front", size: 18)
                }
            } else {
                EmptyWidget(title: l10n.t("widgets.noJourney"), hint: l10n.t("widgets.noJourneyHint"))
            }
        }
        .environment(l10n)
        .placeholder(entry.isPlaceholder)
    }

    // MARK: what to say

    private func time(_ ms: Double, _ tz: String) -> String { Format.time(ms, tz: tz, clock: clock) }

    /// The delay that matters now: the departure's until you leave, then the arrival's.
    private func delay(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> Int? {
        if case .before = s.moment { return l.depDelayMin }
        if case .changing = s.moment { return l.depDelayMin }
        return l.arrDelayMin
    }

    private func service(_ l: WidgetSnapshot.Leg) -> String { [l.operatorName, l.train].compactMap { $0 }.joined(separator: " ") }

    /// "Departs in {{time}}" with the time as a running timer (within 30 minutes) or the countdown's words.
    private func departsIn(_ l: WidgetSnapshot.Leg) -> Text {
        let template = l10n.t("trips.departsIn")
        let parts = template.components(separatedBy: "{{time}}")
        let middle: Text
        if l.depAt - now <= WidgetTimeline.denseBeforeMs {
            middle = Text(timerInterval: entry.date...max(entry.date, wDate(l.depAt)), countsDown: true)
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

    /// The big time: departure before, arrival on the train and after.
    private func bigTime(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> String {
        switch s.moment {
        case .before, .changing: time(l.depAt, l.fromTz)
        case .onTrain, .finished: time(l.arrAt, l.toTz)
        }
    }

    private func platform(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> String? {
        switch s.moment {
        case .before, .changing: l.depPlatform.map { l10n.t("trips.platform", ["platform": $0]) }
        case .onTrain, .finished: l.arrPlatform.map { l10n.t("trips.platform", ["platform": $0]) }
        }
    }

    // MARK: pieces

    private func route(_ l: WidgetSnapshot.Leg, role: TextRole = .rowTitle) -> some View {
        HStack(spacing: 4) {
            Text(l.from).lineLimit(1)
            Text("→").foregroundStyle(Ink.text2)
            Text(l.to).lineLimit(1)
        }
        .clack(role)
        .foregroundStyle(Ink.text)
    }

    @ViewBuilder
    private func progress(_ s: WidgetTimeline.Shown) -> some View {
        if case .onTrain(_, let p) = s.moment { ProgressBar(value: p, color: Ink.accent) }
    }

    private func topLine(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        HStack(spacing: 8) {
            LucideIcon(name: "train-front", size: 14).foregroundStyle(Ink.accentInk)
            Text(service(l)).clack(.captionUpper).foregroundStyle(Ink.text2).lineLimit(1)
            Spacer(minLength: 4)
            DelayText(delay: delay(s, l), canceled: l.canceled)
        }
    }

    private func updated() -> some View {
        UpdatedLine(updatedAt: entry.snapshot.updatedAt, now: entry.date, l10n: l10n, clock: clock)
    }

    // MARK: sizes

    private func small(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            topLine(s, l)
            Text(l.from).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
            Text(l.to).clack(.rowTitle).foregroundStyle(Ink.text2).lineLimit(1)
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bigTime(s, l)).clack(.bigTime).monospacedDigit().foregroundStyle(Ink.text).strikethrough(l.canceled)
                if let p = platform(s, l) { Text(p).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1) }
            }
            progress(s)
            headline(s, l).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
            updated()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func legRow(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, index: Int) -> some View {
        let active = s.moment.legIndex == index
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(service(l)).clack(.captionUpper).foregroundStyle(Ink.text2).lineLimit(1)
                    DelayText(delay: l.depDelayMin, canceled: l.canceled)
                }
                route(l, role: .stopName)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(time(l.depAt, l.fromTz)).clack(.boardDestination).monospacedDigit().foregroundStyle(Ink.text)
                    .strikethrough(l.canceled)
                if let p = l.depPlatform { Text(l10n.t("trips.platform", ["platform": p])).clack(.caption).foregroundStyle(Ink.text2) }
            }
        }
        .opacity(active || s.moment.legIndex == nil ? 1 : 0.6)
    }

    /// The legs around the one under way: it and the next (or the last two).
    private func visibleLegs(_ s: WidgetTimeline.Shown, count: Int) -> [(Int, WidgetSnapshot.Leg)] {
        let start = min(s.moment.legIndex ?? 0, max(0, s.legs.count - count))
        return Array(s.legs.enumerated()).dropFirst(start).prefix(count).map { ($0.offset, $0.element) }
    }

    private func medium(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    topLine(s, l)
                    headline(s, l).clack(.caption).foregroundStyle(Ink.text).lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(bigTime(s, l)).clack(.bigTime).monospacedDigit().foregroundStyle(Ink.text).strikethrough(l.canceled)
            }
            progress(s)
            Spacer(minLength: 0)
            ForEach(visibleLegs(s, count: 2), id: \.1.id) { i, leg in legRow(s, leg, index: i) }
            updated()
        }
    }

    private func large(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            medium(s, l)
            if !l.stops.isEmpty {
                Rectangle().fill(Ink.hairline).frame(height: 1)
                Text(l10n.t("detail.stops")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(l.stops.prefix(7).enumerated()), id: \.offset) { _, name in
                        let next = name == l.nextStop
                        HStack(spacing: 8) {
                            Circle().fill(next ? Ink.accent : Ink.text3).frame(width: 6, height: 6)
                            Text(name).clack(.stopName).fontWeight(next ? .bold : .regular).foregroundStyle(Ink.text).lineLimit(1)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Lock Screen

    private func circular(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        let platformCode: String? = {
            switch s.moment {
            case .before, .changing: l.depPlatform
            case .onTrain, .finished: l.arrPlatform
            }
        }()
        return ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                LucideIcon(name: "train-front", size: 12)
                Text(platformCode ?? Format.delay(nil)).clack(.bigTime).minimumScaleFactor(0.5).lineLimit(1)
            }
            .padding(4)
        }
    }

    private func rectangular(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(l.from) → \(l.to)").clack(.chip).lineLimit(1)
            Text(bigTime(s, l)).clack(.boardDestination).monospacedDigit()
            headline(s, l).clack(.caption).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        Text([l.to, bigTime(s, l), platform(s, l)].compactMap { $0 }.joined(separator: " · "))
    }
}
