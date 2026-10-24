//
//  WidgetShared.swift
//  ClackWidgets
//
//  What the widgets share: the app's words in the app's language, the time helpers, the placeholder, and a few small
//  views (the empty state, the "Updated 12:04" line). Colours, type and icons come from
//  ClackDesign, the same tokens as the app, so the widgets follow light and dark mode.
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

// MARK: words

/// One `L10n` per language: the app's language setting, carried in the snapshot (the extension can't read the app's
/// settings otherwise). Before the app has written anything, the phone's language when Clack has it, else English.
@MainActor
enum WidgetWords {
    private static var tables: [String: L10n] = [:]

    static func l10n(_ language: Language) -> L10n {
        if let known = tables[language.rawValue] { return known }
        let made = L10n(language: language)
        tables[language.rawValue] = made
        return made
    }

    /// The language for texts outside an entry (the widget gallery's names and descriptions).
    nonisolated static var language: Language {
        if let saved = WidgetSnapshot.load()?.language { return saved }
        return Locale.current.language.languageCode?.identifier == "sv" ? .sv : .en
    }

    static func t(_ key: String, _ values: [String: String] = [:]) -> String { l10n(language).t(key, values) }
}

// MARK: time

func wDate(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }
func wMs(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }

extension WidgetSnapshot {
    /// What the gallery and a first look show, drawn redacted (`.redacted(reason: .placeholder)`): only the shapes are
    /// seen, so nothing here is presented as a real trip or a real number.
    static func placeholder(now: Date) -> WidgetSnapshot {
        let t = wMs(now)
        let m = 60_000.0
        let blank = "Xxxxxxxxx"
        var s = WidgetSnapshot(updatedAt: t)
        s.journey = [
            .init(id: "placeholder", from: blank, to: blank, fromTz: TimeZone.current.identifier, toTz: TimeZone.current.identifier,
                  depAt: t + 45 * m, arrAt: t + 165 * m, depPlatform: "0", canceled: false, stops: [blank, blank, blank]),
        ]
        s.passport = .init(km: 0, trains: 0, journeys: 0, stations: 0, countries: 0, minutes: 0, lateMinutes: 0, co2Comparison: "")
        s.stats = .init(
            operators: (1...4).map { .init(name: blank, count: 5 - $0) }, trainTypes: [], stations: [], countries: []
        )
        s.year = .init(year: Calendar.current.component(.year, from: now), km: 0, trains: 0, topRouteCount: 0, busiestMonthCount: 0, routes: [])
        s.boards = [.init(id: "placeholder", name: blank, updatedAt: t, rows: (0..<8).map {
            .init(id: "p\($0)", time: t + Double(5 + $0 * 9) * m, to: blank, train: "000", canceled: false)
        })]
        return s
    }
}

// MARK: views

/// Nothing to show yet: a train icon, what's missing and what to do.
struct EmptyWidget: View {
    var title: String
    var hint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LucideIcon(name: "train-front", size: 18).foregroundStyle(Ink.accentInk)
            Spacer(minLength: 0)
            Text(title).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2)
            Text(hint).clack(.caption).foregroundStyle(Ink.text2).lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// "Updated 12:04", in grey, once the data is more than 30 minutes old: the widget never passes old data off as live.
struct UpdatedLine: View {
    var updatedAt: Double
    var now: Date
    var l10n: L10n
    var clock: ClockFormat

    var body: some View {
        if WidgetTimeline.isStale(updatedAt, now: wMs(now)) {
            Text(l10n.t("widgets.updated", ["time": Format.time(updatedAt, tz: TimeZone.current.identifier, clock: clock)]))
                .clack(.captionUpper).textCase(nil).foregroundStyle(Ink.text3).lineLimit(1)
        }
    }
}

/// The operator's colour as a quiet tint in the top corner over the surface (the app's hero surface, 30%).
struct TintedBackground: View {
    var hex: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let op = operatorColor(hex, scheme: scheme)
        ZStack {
            Ink.surface
            LinearGradient(colors: [op.opacity(0.30), op.opacity(0)], startPoint: .topTrailing, endPoint: .bottomLeading)
        }
    }
}

extension View {
    /// Shapes only, for the gallery and a first look.
    @ViewBuilder
    func placeholder(_ on: Bool) -> some View {
        if on { redacted(reason: .placeholder) } else { self }
    }
}
