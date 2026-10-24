//
//  PassportWidget.swift
//  ClackWidgets
//
//  The passport card on the holographic foil yellow. Static here: a widget can't read the gyroscope.
//

import ClackCore
import SwiftUI
import WidgetKit

struct PassportEntry: TimelineEntry {
    var date: Date
    var bits: WidgetSnapshot.PassportBits
    var isSample: Bool
}

struct PassportProvider: TimelineProvider {
    private func entry() -> PassportEntry {
        let c = WidgetContent.current()
        return PassportEntry(date: .now, bits: c.snapshot.passport ?? SampleData.snapshot(now: .now).passport!, isSample: c.isSample || c.snapshot.passport == nil)
    }
    func placeholder(in context: Context) -> PassportEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (PassportEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<PassportEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(.now.addingTimeInterval(3600))))
    }
}

struct PassportWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Passport", provider: PassportProvider()) { entry in
            PassportWidgetView(entry: entry)
                .containerBackground(for: .widget) { FoilBackground() }
                .widgetURL(URL(string: "clack://tab/passport"))
        }
        .configurationDisplayName(WW.t("Passport", "Pass"))
        .description(WW.t("Your rail history on the foil card.", "Din tåghistorik på folie-kortet."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Yellow, with a rainbow foil sweep and a soft sheen, like the card on the Passport tab.
struct FoilBackground: View {
    var body: some View {
        ZStack {
            WB.accent
            LinearGradient(colors: [Color.pink, Color.orange, Color.yellow, Color.green, Color.cyan, Color.purple, Color.pink].map { $0.opacity(0.35) },
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.overlay)
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.55), .white.opacity(0)], startPoint: UnitPoint(x: 0.1, y: 0), endPoint: UnitPoint(x: 0.7, y: 1))
        }
    }
}

private struct PassportWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: PassportEntry
    private var b: WidgetSnapshot.PassportBits { entry.bits }

    private func number(_ n: Double) -> String { Int(n.rounded()).formatted(.number.grouping(.automatic)) }

    private func big(_ value: String, _ label: String, size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(WB.digits(size)).foregroundStyle(WB.ink).minimumScaleFactor(0.6).lineLimit(1)
            Text(label.uppercased()).font(WB.inter(9, .heavy)).tracking(0.8).foregroundStyle(WB.ink.opacity(0.65))
        }
    }

    private var ring: some View {
        let fraction = min(1, max(0, (b.nextMedalValue ?? 0) / max(1, b.nextMedalTarget ?? 1)))
        return ZStack {
            Circle().stroke(WB.ink.opacity(0.18), lineWidth: 6)
            Circle().trim(from: 0, to: fraction).stroke(WB.ink, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
            Image(systemName: "medal.fill").foregroundStyle(WB.ink)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CLACK").font(WB.inter(10, .heavy)).tracking(1.5).foregroundStyle(WB.ink.opacity(0.7))
                if let year = b.year { Text(String(year)).font(WB.digits(10)).foregroundStyle(WB.ink.opacity(0.7)) }
                Spacer()
                if entry.isSample { SampleTag(onLight: true) }
            }
            switch family {
            case .systemSmall:
                Spacer(minLength: 0)
                big(number(b.km), WW.km, size: 34)
                big(String(b.trains), WW.trains, size: 22)
            case .systemMedium:
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        big(number(b.km), WW.km, size: 32)
                        HStack(spacing: 16) {
                            big(String(b.trains), WW.trains, size: 18)
                            big(String(b.stations), WW.stationsWord, size: 18)
                            big(String(b.countries), WW.countriesWord, size: 18)
                        }
                    }
                    Spacer(minLength: 0)
                    if b.nextMedal != nil { ring.frame(width: 56, height: 56) }
                }
            default:
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        big(number(b.km), WW.km, size: 40)
                        HStack(spacing: 18) {
                            big(String(b.trains), WW.trains, size: 22)
                            big(String(b.journeys), WW.journeysWord, size: 22)
                        }
                        HStack(spacing: 18) {
                            big(String(b.stations), WW.stationsWord, size: 22)
                            big(String(b.countries), WW.countriesWord, size: 22)
                        }
                    }
                    Spacer(minLength: 0)
                    if let medal = b.nextMedal {
                        VStack(spacing: 4) {
                            ring.frame(width: 64, height: 64)
                            Text(medal).font(WB.inter(11, .bold)).foregroundStyle(WB.ink)
                            Text(WW.nextMedal).font(WB.inter(9)).foregroundStyle(WB.ink.opacity(0.65))
                        }
                    }
                }
                Spacer(minLength: 0)
                Rectangle().fill(WB.ink.opacity(0.2)).frame(height: 1)
                HStack(spacing: 24) {
                    if let pct = b.onTimePct { big("\(Int(pct.rounded()))%", WW.onTimeRecord, size: 22) }
                    if let kg = b.co2SavedKg { big("\(number(kg)) kg", WW.co2Saved, size: 22) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
