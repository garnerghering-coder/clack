//
//  PassportWidget.swift
//  ClackWidgets
//
//  The passport card on the holographic foil yellow. Static here: a widget can't read the gyroscope. The Passport, Stats
//  and Year in rail widgets share one provider: they fetch every 6 hours, and the app reloads them when a trip arrives.
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
            PassportWidgetView(entry: entry)
                .containerBackground(for: .widget) { FoilBackground() }
                .widgetURL(WidgetLinks.passport)
        }
        .configurationDisplayName(WidgetWords.t("widgets.passport.name"))
        .description(WidgetWords.t("widgets.passport.description"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Yellow, with a rainbow foil sweep and a soft sheen, like the card on the Passport tab.
struct FoilBackground: View {
    var body: some View {
        ZStack {
            Ink.accent
            LinearGradient(colors: [Color.pink, Color.orange, Color.yellow, Color.green, Color.cyan, Color.purple, Color.pink].map { $0.opacity(0.35) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.overlay)
            LinearGradient(colors: [Ink.onTint.opacity(0), Ink.onTint.opacity(0.55), Ink.onTint.opacity(0)], startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
        }
    }
}

private struct PassportWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PassportEntry

    private var l10n: L10n { WidgetWords.l10n(entry.snapshot.language) }
    private var ink: Color { Ink.onAccent }

    var body: some View {
        Group {
            if let b = entry.snapshot.passport {
                card(b)
            } else {
                EmptyWidget(title: l10n.t("passport.emptyTitle"), hint: l10n.t("widgets.openApp"))
            }
        }
        .environment(l10n)
        .placeholder(entry.isPlaceholder)
    }

    /// Kilometres in the app's unit.
    private func distance(_ km: Double) -> Double { entry.snapshot.distanceUnit == .mi ? km * 1000 / 1609.344 : km }
    private var unit: String { entry.snapshot.distanceUnit == .mi ? "mi" : "km" }

    private func number(_ n: Double) -> String {
        let f = NumberFormatter()
        f.locale = Format.locale(entry.snapshot.language)
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: n.rounded())) ?? String(Int(n.rounded()))
    }

    private func big(_ value: String, _ label: String, role: TextRole) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).clack(role).foregroundStyle(ink).minimumScaleFactor(0.6).lineLimit(1)
            Text(label).clack(.captionUpper).foregroundStyle(ink.opacity(0.65)).lineLimit(1)
        }
    }

    private func ring(_ b: WidgetSnapshot.PassportBits) -> some View {
        let fraction = min(1, max(0, (b.nextMedalValue ?? 0) / max(1, b.nextMedalTarget ?? 1)))
        return ZStack {
            Circle().stroke(ink.opacity(0.18), lineWidth: 6)
            Circle().trim(from: 0, to: fraction).stroke(ink, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            LucideIcon(name: "star", size: 18).foregroundStyle(ink)
        }
    }

    private func card(_ b: WidgetSnapshot.PassportBits) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(l10n.t("passport.title")).clack(.captionUpper).foregroundStyle(ink.opacity(0.7))
                Spacer()
                UpdatedLine(updatedAt: entry.snapshot.passportUpdatedAt, now: entry.date, l10n: l10n, clock: entry.snapshot.clock)
            }
            switch family {
            case .systemSmall:
                Spacer(minLength: 0)
                big(number(distance(b.km)), unit, role: .passportBig)
                big(String(b.trains), l10n.t("passport.trains"), role: .bigTime)
            case .systemMedium:
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        big(number(distance(b.km)), unit, role: .passportBig)
                        HStack(spacing: 16) {
                            big(String(b.trains), l10n.t("passport.trains"), role: .walkBig)
                            big(String(b.stations), l10n.t("passport.stations"), role: .walkBig)
                            big(String(b.countries), l10n.t("passport.countries"), role: .walkBig)
                        }
                    }
                    Spacer(minLength: 0)
                    if b.nextMedal != nil { ring(b).frame(width: 56, height: 56) }
                }
            default:
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        big(number(distance(b.km)), unit, role: .passportDistance)
                        HStack(spacing: 16) {
                            big(String(b.trains), l10n.t("passport.trains"), role: .walkBig)
                            big(String(b.journeys), l10n.t("passport.journeys"), role: .walkBig)
                        }
                        HStack(spacing: 16) {
                            big(String(b.stations), l10n.t("passport.stations"), role: .walkBig)
                            big(String(b.countries), l10n.t("passport.countries"), role: .walkBig)
                        }
                    }
                    Spacer(minLength: 0)
                    if let medal = b.nextMedal {
                        VStack(spacing: 4) {
                            ring(b).frame(width: 64, height: 64)
                            Text(medal).clack(.chip).foregroundStyle(ink).multilineTextAlignment(.center)
                            Text(l10n.t("widgets.nextMedal")).clack(.captionUpper).foregroundStyle(ink.opacity(0.65))
                        }
                    }
                }
                Spacer(minLength: 0)
                Rectangle().fill(ink.opacity(0.2)).frame(height: 1)
                HStack(spacing: 24) {
                    if let pct = b.onTimePct { big("\(Int(pct.rounded()))%", l10n.t("widgets.onTime"), role: .walkBig) }
                    if let kg = b.co2SavedKg { big("\(number(kg)) kg", l10n.t("widgets.co2Saved"), role: .walkBig) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
