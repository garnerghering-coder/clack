//
//  NextJourneyWidget.swift
//  ClackWidgets
//
//  One widget for the next journey that follows it through: before (route, countdown, platform), on the train (next stop,
//  arrival, progress), at a change (minutes to change, the next platform), and a cancellation takes over the top line.
//  It fetches for itself (`WidgetData.load`); the timeline (`WidgetTimeline`) redraws it every minute around the trip,
//  and moves on to the next journey when this one ends. The Home Screen sizes are drawn by `NextJourneyWidgetView`
//  (ClackDesign, shared with the app's debug gallery); the Lock Screen ones are here.
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
        if let size = family.homeSize {
            NextJourneyWidgetView(snapshot: entry.snapshot, date: entry.date, size: size, isPlaceholder: entry.isPlaceholder)
        } else {
            Group {
                if let shown, let leg = shown.leg {
                    switch family {
                    case .accessoryCircular: circular(shown, leg)
                    case .accessoryRectangular: rectangular(shown, leg)
                    default: inline(shown, leg)
                    }
                } else if family == .accessoryInline {
                    Text(l10n.t("widgets.noJourney"))
                } else {
                    ZStack {
                        AccessoryWidgetBackground()
                        LucideIcon(name: "train-front", size: 18)
                    }
                }
            }
            .environment(l10n)
            .placeholder(entry.isPlaceholder)
        }
    }

    private func time(_ ms: Double, _ tz: String) -> String { Format.time(ms, tz: tz, clock: clock) }

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

    /// "08:03 · Platform 12b", then "08:03 · Pl 12b".
    private func timeAndPlatform(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg, key: String) -> String {
        [bigTime(s, l), platformCode(s, l).map { l10n.t(key, ["platform": $0]) }].compactMap { $0 }.joined(separator: " · ")
    }

    /// "Departs in 12:34" with a running timer within the hour (it counts by itself), else the countdown's words.
    private func departsIn(_ l: WidgetSnapshot.Leg) -> Text {
        let parts = l10n.t("trips.departsIn").components(separatedBy: "{{time}}")
        let middle = l.depAt - now <= 3_600_000
            ? Text(timerInterval: entry.date...max(entry.date, wDate(l.depAt)), countsDown: true)
            : Text(WidgetTimeline.text(WidgetTimeline.countdown(to: l.depAt, now: now)))
        return Text("\(parts.first ?? "")\(middle)\(parts.count > 1 ? parts[1] : "")")
    }

    /// The line under the time, as it counts down (Lock Screen).
    private func statusText(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> Text {
        if !l.canceled, case .before = s.moment, l.status != "boarding" { return departsIn(l) }
        return Text(status(s, l))
    }

    /// The line under the time: cancelled, the next stop on board, else what the moment is.
    private func status(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> String {
        if l.canceled { return l10n.t("status.cancelled") }
        switch s.moment {
        case .before:
            if l.status == "boarding" { return l10n.t("trips.boarding") }
            return l10n.t("trips.departsIn", ["time": WidgetTimeline.text(WidgetTimeline.countdown(to: l.depAt, now: now))])
        case .onTrain:
            if let stop = l.nextStop { return l10n.t("live.nextStopName", ["name": stop]) }
            return l10n.t("live.arrives", ["time": time(l.arrAt, l.toTz)])
        case .changing(let next, let spare):
            return l10n.t("journey.transfer", ["min": String(spare), "station": s.legs[next].from])
        case .finished:
            return l10n.t("trips.arrivedAt", ["time": time(l.arrAt, l.toTz)])
        }
    }

    // MARK: Lock Screen

    private func circular(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                LucideIcon(name: "train-front", size: 12)
                Text(platformCode(s, l) ?? Format.delay(nil)).clack(.bigTime).minimumScaleFactor(0.5).lineLimit(1)
            }
            .padding(4)
        }
    }

    private func rectangular(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            FittingText(l10n.t("tripCard.route", ["from": l.from, "to": l.to])).clack(.chip)
            FittingText([timeAndPlatform(s, l, key: "trips.platform"), timeAndPlatform(s, l, key: "tripCard.platformShort")])
                .clack(.boardDestination).monospacedDigit()
            statusText(s, l).clack(.caption).monospacedDigit().lineLimit(1).minimumScaleFactor(WidgetInsets.minimumScale)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func inline(_ s: WidgetTimeline.Shown, _ l: WidgetSnapshot.Leg) -> some View {
        ViewThatFits {
            Text(verbatim: "\(l.to) · \(timeAndPlatform(s, l, key: "trips.platform"))")
            Text(verbatim: "\(l.to) · \(timeAndPlatform(s, l, key: "tripCard.platformShort"))")
            Text(timeAndPlatform(s, l, key: "tripCard.platformShort"))
        }
    }
}
