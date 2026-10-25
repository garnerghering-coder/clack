//
//  WidgetShared.swift
//  ClackDesign
//
//  What the Home Screen widgets share: the one inset rule, the sizes, the app's words in the app's language, the time
//  helpers, the placeholder, and a few small views (the empty state, the "Updated 12:04" line, text that never cuts).
//  The widget bodies live here, in ClackDesign, so the widget extension and the app's debug widget gallery
//  (`-widgetGallery`) draw the very same views.
//

import ClackCore
import SwiftUI

// MARK: the inset rule

/// The gap between a Home Screen widget's edge and its content. The widgets use the system's own content margins
/// (owner, 2026-10-25: large widgets were cut at the edges with hand-set ones); these numbers are the iPhone's, so the
/// app's debug gallery draws the same gap. Backgrounds still reach the edge (`containerBackground`).
public enum WidgetInsets {
    /// Left and right, small widget.
    public static let smallSide: CGFloat = 16
    /// Left and right, medium and large widgets.
    public static let wideSide: CGFloat = 16
    /// Top and bottom, every size.
    public static let topBottom: CGFloat = 16
    /// The rounded corner of a Home Screen widget on a current iPhone, about (for the gallery's outline only).
    public static let cornerRadius: CGFloat = 24
    /// The smallest a value may shrink to before it is cut, and only as the last of the shorter variants.
    public static let minimumScale: CGFloat = 0.75

    public static func insets(_ size: WidgetSize) -> EdgeInsets {
        let side = size == .small ? smallSide : wideSide
        return EdgeInsets(top: topBottom, leading: side, bottom: topBottom, trailing: side)
    }
}

/// The Home Screen sizes (`WidgetFamily` without WidgetKit, so the app can draw them too).
public enum WidgetSize: String, CaseIterable, Sendable {
    case small, medium, large

    /// The size on most iPhones (6.1 and 6.3 inch, Apple's widget size table), in points, for the gallery: the smaller
    /// of the two common sizes, so what doesn't fit shows (the gallery drew the Pro Max size, 364 x 382, and hid it).
    public var points: CGSize {
        switch self {
        case .small: CGSize(width: 158, height: 158)
        case .medium: CGSize(width: 338, height: 158)
        case .large: CGSize(width: 338, height: 354)
        }
    }
}

// MARK: words

/// One `L10n` per language: the app's language setting, carried in the snapshot (the extension can't read the app's
/// settings otherwise). Before the app has written anything, the phone's language when Clack has it, else English.
@MainActor
public enum WidgetWords {
    private static var tables: [String: L10n] = [:]

    public static func l10n(_ language: Language) -> L10n {
        if let known = tables[language.rawValue] { return known }
        let made = L10n(language: language)
        tables[language.rawValue] = made
        return made
    }

    /// The language for texts outside an entry (the widget gallery's names and descriptions).
    public nonisolated static var language: Language {
        if let saved = WidgetSnapshot.load()?.language { return saved }
        return Locale.current.language.languageCode?.identifier == "sv" ? .sv : .en
    }

    public static func t(_ key: String, _ values: [String: String] = [:]) -> String { l10n(language).t(key, values) }
}

// MARK: time

public func wDate(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }
public func wMs(_ date: Date) -> Double { date.timeIntervalSince1970 * 1000 }

extension WidgetSnapshot {
    /// What the gallery and a first look show, drawn redacted (`.redacted(reason: .placeholder)`): only the shapes are
    /// seen, so nothing here is presented as a real trip or a real number.
    public static func placeholder(now: Date) -> WidgetSnapshot {
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

/// One line of text that is never cut with "…" while a shorter wording exists: the first variant that fits whole is
/// shown; the last one may shrink to `WidgetInsets.minimumScale`, and only past that is it cut. Give the variants
/// longest first ("Platform 12b", "Pl 12b").
public struct FittingText: View {
    var variants: [String]

    public init(_ variants: [String]) { self.variants = variants.isEmpty ? [""] : variants }
    public init(_ text: String) { self.init([text]) }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(Array(variants.enumerated()), id: \.offset) { _, text in
                Text(text).lineLimit(1).fixedSize(horizontal: true, vertical: false)
            }
            Text(variants[variants.count - 1]).lineLimit(1).minimumScaleFactor(WidgetInsets.minimumScale)
        }
    }
}

/// Nothing to show yet: a train icon, what's missing and what to do.
public struct EmptyWidget: View {
    var title: String
    var hint: String

    public init(title: String, hint: String) {
        self.title = title
        self.hint = hint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LucideIcon(name: "train-front", size: 18).foregroundStyle(Ink.accentInk)
            Spacer(minLength: 0)
            Text(title).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2).minimumScaleFactor(WidgetInsets.minimumScale)
            Text(hint).clack(.caption).foregroundStyle(Ink.text2).lineLimit(4).minimumScaleFactor(WidgetInsets.minimumScale)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

/// "Updated 12:04", in grey, once the data is more than 30 minutes old: the widget never passes old data off as live.
public struct UpdatedLine: View {
    var updatedAt: Double
    var now: Date
    var l10n: L10n
    var clock: ClockFormat

    public init(updatedAt: Double, now: Date, l10n: L10n, clock: ClockFormat) {
        self.updatedAt = updatedAt
        self.now = now
        self.l10n = l10n
        self.clock = clock
    }

    public static func shows(_ updatedAt: Double, now: Date) -> Bool { WidgetTimeline.isStale(updatedAt, now: wMs(now)) }

    public var body: some View {
        if Self.shows(updatedAt, now: now) {
            Text(l10n.t("widgets.updated", ["time": Format.time(updatedAt, tz: TimeZone.current.identifier, clock: clock)]))
                .clack(.captionUpper).textCase(nil).foregroundStyle(Ink.text3).lineLimit(1).fixedSize()
        }
    }
}

/// The operator's colour as a quiet tint in the top corner over the surface (the app's hero surface, 30%).
public struct TintedBackground: View {
    var hex: String?
    @Environment(\.colorScheme) private var scheme

    public init(hex: String?) { self.hex = hex }

    public var body: some View {
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
    public func placeholder(_ on: Bool) -> some View {
        if on { redacted(reason: .placeholder) } else { self }
    }
}
