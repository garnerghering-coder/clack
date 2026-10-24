//
//  PassportWidget.swift
//  ClackWidgets
//
//  The passport card on the holographic foil yellow (`PassportWidgetView`, ClackDesign). The Passport, Stats and Year in
//  rail widgets share one provider: they fetch every 6 hours, and the app reloads them when a trip arrives.
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

/// The Passport, Stats and Year in rail widgets' entry: the snapshot, or the placeholder (drawn redacted).
struct PassportEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    var isPlaceholder = false
}

struct PassportProvider: TimelineProvider {
    func placeholder(in context: Context) -> PassportEntry {
        PassportEntry(date: .now, snapshot: .placeholder(now: .now), isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PassportEntry) -> Void) {
        guard let cached = WidgetSnapshot.load(), cached.passport != nil else {
            completion(placeholder(in: context))
            return
        }
        completion(PassportEntry(date: .now, snapshot: cached))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PassportEntry>) -> Void) {
        Task {
            // Within 30 minutes of the last fetch (the app's, after a trip arrived) the kept one is used.
            let snapshot = await WidgetData.load(.passport, maxAge: 30 * 60_000)
            let now = Date.now
            completion(Timeline(entries: [PassportEntry(date: now, snapshot: snapshot)], policy: .after(now.addingTimeInterval(WidgetTimeline.passportReloadMs / 1000))))
        }
    }
}

struct PassportWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetKinds.passport, provider: PassportProvider()) { entry in
            PassportView(entry: entry)
                .widgetPadding()
                .containerBackground(for: .widget) { FoilBackground() }
                .widgetURL(WidgetLinks.passport)
        }
        .configurationDisplayName(WidgetWords.t("widgets.passport.name"))
        .description(WidgetWords.t("widgets.passport.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

private struct PassportView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PassportEntry

    var body: some View {
        PassportWidgetView(snapshot: entry.snapshot, date: entry.date, size: family.homeSize ?? .small, isPlaceholder: entry.isPlaceholder)
    }
}
