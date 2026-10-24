//
//  NextJourneyWidget.swift
//  ClackWidgets
//
//  One widget for the next journey that follows it through: before (route, countdown, platform), on the train (progress, next stop,
//  arrival), at a change (next platform, minutes to spare), and a delay or cancellation takes over the top line. Same gradient by
//  operator colour as the featured card on the Trips tab, in every size.
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

struct JourneyEntry: TimelineEntry {
    var date: Date
    var legs: [WidgetSnapshot.Leg]
    var isSample: Bool
}

struct JourneyProvider: TimelineProvider {
    func placeholder(in context: Context) -> JourneyEntry {
        JourneyEntry(date: .now, legs: SampleData.snapshot(now: .now).journey, isSample: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (JourneyEntry) -> Void) {
        let c = WidgetContent.current()
        completion(JourneyEntry(date: .now, legs: c.snapshot.journey, isSample: c.isSample))
    }

    /// One entry a minute while the journey runs (up to 3 hours ahead), so countdowns, the line and the "now" part follow the clock.
    func getTimeline(in context: Context, completion: @escaping (Timeline<JourneyEntry>) -> Void) {
        let c = WidgetContent.current()
        let legs = c.snapshot.journey
        let start = Date.now
        guard let last = legs.last else {
            completion(Timeline(entries: [JourneyEntry(date: start, legs: [], isSample: c.isSample)], policy: .after(start.addingTimeInterval(30 * 60))))
            return
        }
        let end = min(start.addingTimeInterval(3 * 3600), wDate(last.arrAt).addingTimeInterval(60))
        var entries: [JourneyEntry] = []
        var d = start
        while d <= end {
            entries.append(JourneyEntry(date: d, legs: legs, isSample: c.isSample))
            d = d.addingTimeInterval(60)
        }
        completion(Timeline(entries: entries, policy: .after(end)))
    }
}

struct NextJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextJourney", provider: JourneyProvider()) { entry in
            NextJourneyView(entry: entry)
                .containerBackground(for: .widget) { JourneyBackground(entry: entry) }
                .widgetURL(entry.legs.first.flatMap { URL(string: "clack://trip/\($0.id)") })
        }
        .configurationDisplayName(WW.t("Next journey", "Nästa resa"))
        .description(WW.t("Your next journey, following it from the platform to the arrival.", "Din nästa resa, från perrongen till framme."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: look

private struct JourneyBackground: View {
    var entry: JourneyEntry
    var body: some View {
        let base = Color(hex: entry.legs.first?.color) ?? Color(red: 0.2, green: 0.2, blue: 0.22)
        LinearGradient(colors: [base.opacity(0.95), base.opacity(0.55), WB.bg], startPoint: .topLeading, endPoint: .bottomTrailing)
            .background(WB.bg)
    }
}

private struct NextJourneyView: View {
    @Environment(\.widgetFamily) private var family
    var entry: JourneyEntry

    private var now: Double { entry.date.timeIntervalSince1970 * 1000 }
    private var moment: JourneyMoment { JourneyMoment.at(now, legs: entry.legs) }
    private var leg: WidgetSnapshot.Leg? { moment.legIndex.map { entry.legs[$0] } }

    var body: some View {
        if let leg {
            switch family {
            case .accessoryCircular: circular(leg)
            case .accessoryRectangular: rectangular(leg)
            case .accessoryInline: inline(leg)
            case .systemSmall: small(leg)
            case .systemMedium: medium
            default: large
            }
        } else if family == .accessoryInline {
            Text(WW.noJourney)
        } else {
            EmptyWidget(title: WW.noJourney, hint: WW.noJourneyHint)
        }
    }

    // MARK: what to say

    private func late(_ l: WidgetSnapshot.Leg) -> Int? { (l.delayMin ?? 0) >= 5 ? l.delayMin : nil }

    /// The line at the top: a cancellation or delay takes over, else the moment.
    private func headline(_ l: WidgetSnapshot.Leg) -> (text: String, color: Color) {
        if l.canceled { return (WW.cancelled, WB.cancelled) }
        if let n = late(l) { return (WW.late(n), WB.late) }
        switch moment {
        case .before: return (l.status == "boarding" ? WW.boarding : WW.onTime, l.status == "boarding" ? WB.accent : WB.onTime)
        case .onTrain: return (WW.onItsWay, WB.accent)
        case .changing(_, let spare): return (WW.spare(spare), WB.accent)
        case .finished: return ("", WB.text2)
        }
    }

    private func platformText(_ l: WidgetSnapshot.Leg) -> String? { l.depPlatform }

    // MARK: pieces

    private func routeLine(_ l: WidgetSnapshot.Leg, size: CGFloat = 15) -> some View {
        HStack(spacing: 4) {
            Text(l.from).lineLimit(1)
            Image(systemName: "arrow.right").font(.system(size: size - 4, weight: .bold))
            Text(l.to).lineLimit(1)
        }
        .font(WB.inter(size, .heavy)).foregroundStyle(WB.text)
    }

    @ViewBuilder
    private func line(progress: Double) -> some View {
        GeometryReader { p in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule().fill(WB.accent).frame(width: max(4, p.size.width * progress))
            }
        }
        .frame(height: 4)
    }

    private func footer(_ l: WidgetSnapshot.Leg) -> some View {
        HStack {
            if entry.isSample { SampleTag() }
            Spacer()
        }
    }

    /// The big number for the moment: countdown before, arrival on the train, spare minutes at a change.
    @ViewBuilder
    private func hero(_ l: WidgetSnapshot.Leg, size: CGFloat) -> some View {
        switch moment {
        case .before:
            Text(timerInterval: entry.date...max(entry.date.addingTimeInterval(1), wDate(l.depAt)), countsDown: true)
                .font(WB.digits(size)).monospacedDigit().foregroundStyle(WB.text)
        case .onTrain:
            FlapText(text: wTime(l.arrAt, tz: l.toTz), size: size * 0.8, color: late(l) == nil ? WB.text : WB.accent)
        case .changing(let next, _):
            if let p = entry.legs[next].depPlatform {
                Text(WW.platform(p)).font(WB.digits(size)).foregroundStyle(WB.accent)
            }
        case .finished: EmptyView()
        }
    }

    // MARK: sizes

    private func small(_ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headline(l).text).font(WB.inter(11, .bold)).foregroundStyle(headline(l).color).lineLimit(1)
            routeLine(l, size: 13)
            Spacer(minLength: 0)
            hero(l, size: 26)
            if case .onTrain(_, let p) = moment { line(progress: p) }
            else if let p = platformText(l) { Text(WW.platform(p)).font(WB.inter(12, .semibold)).foregroundStyle(WB.text) }
            if entry.isSample { SampleTag() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func legBlock(_ l: WidgetSnapshot.Leg, index: Int) -> some View {
        let active = moment.legIndex == index
        return HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text([l.operatorName, l.train].compactMap { $0 }.joined(separator: " ")).font(WB.digits(12)).foregroundStyle(WB.text.opacity(0.75))
                    if l.canceled { Text(WW.cancelled).font(WB.inter(11, .bold)).foregroundStyle(WB.cancelled) }
                    else if let n = late(l) { Text(WW.late(n)).font(WB.inter(11, .bold)).foregroundStyle(WB.late) }
                }
                routeLine(l, size: 14)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(wTime(l.depAt, tz: l.fromTz)).font(WB.digits(16)).foregroundStyle(late(l) == nil ? WB.text : WB.accent)
                if let p = l.depPlatform { Text(WW.platform(p)).font(WB.inter(11)).foregroundStyle(WB.text.opacity(0.75)) }
            }
        }
        .opacity(active || moment.legIndex == nil ? 1 : 0.7)
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let l = leg {
                HStack {
                    Text(headline(l).text).font(WB.inter(12, .bold)).foregroundStyle(headline(l).color)
                    Spacer()
                    hero(l, size: 22)
                }
                if case .onTrain(_, let p) = moment { line(progress: p) }
                Spacer(minLength: 0)
                ForEach(Array(entry.legs.prefix(2).enumerated()), id: \.offset) { i, leg in legBlock(leg, index: i) }
                if entry.isSample { SampleTag() }
            }
        }
    }

    private var large: some View {
        VStack(alignment: .leading, spacing: 10) {
            medium
            if let l = leg {
                Divider().overlay(Color.white.opacity(0.2))
                Text(WW.stops.uppercased()).font(WB.inter(10, .heavy)).tracking(0.8).foregroundStyle(WB.text.opacity(0.7))
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(l.stops.prefix(7).enumerated()), id: \.offset) { _, name in
                        HStack(spacing: 8) {
                            Circle().fill(name == l.nextStop ? WB.accent : Color.white.opacity(0.5)).frame(width: 6, height: 6)
                            Text(name).font(WB.inter(13, name == l.nextStop ? .bold : .regular)).foregroundStyle(WB.text).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    // MARK: Lock Screen

    private func circular(_ l: WidgetSnapshot.Leg) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "tram.fill").font(.system(size: 11))
                Text(platformText(l) ?? "–").font(WB.digits(20)).minimumScaleFactor(0.6)
            }
        }
    }

    private func rectangular(_ l: WidgetSnapshot.Leg) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(l.from) → \(l.to)").font(WB.inter(12, .bold)).lineLimit(1)
            switch moment {
            case .before:
                Text(timerInterval: entry.date...max(entry.date.addingTimeInterval(1), wDate(l.depAt)), countsDown: true).font(WB.digits(16)).monospacedDigit()
                Text([platformText(l).map(WW.platform), late(l).map(WW.late)].compactMap { $0 }.joined(separator: " · ")).font(WB.inter(11))
            case .onTrain:
                Text("\(WW.arrives) \(wTime(l.arrAt, tz: l.toTz))").font(WB.digits(16))
                Text(late(l).map(WW.late) ?? WW.onItsWay).font(WB.inter(11))
            case .changing(let next, let spare):
                Text(entry.legs[next].depPlatform.map(WW.platform) ?? WW.change).font(WB.digits(16))
                Text(WW.spare(spare)).font(WB.inter(11))
            case .finished: EmptyView()
            }
        }
    }

    private func inline(_ l: WidgetSnapshot.Leg) -> some View {
        Text("\(l.to) \(wTime(l.arrAt, tz: l.toTz))" + (platformText(l).map { " · \(WW.platform($0))" } ?? ""))
    }
}
