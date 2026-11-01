//
//  TimelineDemoView.swift
//  Clack
//

#if DEBUG
import ClackCore
import ClackDesign
import SwiftUI

/// Debug only: four ways to weigh trains against changes in a journey's timeline, on one sample journey, for the owner
/// to pick from (2026-11-01). `-timelineDemo A|B|C|D` opens one. Sample data, not a real journey.
struct TimelineDemoView: View {
    let style: String

    struct Train: Identifiable {
        let id = UUID()
        let op: String, number: String, color: Color
        let from: String, to: String, dep: String, arr: String, depTrack: String, arrTrack: String
        let minutes: Int
        let status: String?
        let progress: Double
    }
    struct Change {
        let at: String, minutes: Int, tracks: String, walk: String
        let tight: Bool
    }

    let trains = [
        Train(op: "DSB", number: "IC 836", color: Color(red: 0.78, green: 0.13, blue: 0.18), from: "Kolding St.", to: "Fredericia St.", dep: "10:12", arr: "10:26", depTrack: "2", arrTrack: "3", minutes: 14, status: "Arrived", progress: 1),
        Train(op: "DSB", number: "ICL 126", color: Color(red: 0.78, green: 0.13, blue: 0.18), from: "Fredericia St.", to: "København H", dep: "10:44", arr: "12:56", depTrack: "4", arrTrack: "5", minutes: 132, status: "+2 · near Odense", progress: 0.35),
        Train(op: "SJ", number: "SJ 1078", color: Color(red: 0.16, green: 0.2, blue: 0.45), from: "København H", to: "Jönköping C", dep: "13:36", arr: "17:12", depTrack: "26", arrTrack: "1", minutes: 216, status: nil, progress: 0),
    ]
    let changes = [
        Change(at: "Fredericia St.", minutes: 18, tracks: "3 → 4", walk: "2 min walk", tight: false),
        Change(at: "København H", minutes: 40, tracks: "5 → 26", walk: "6 min walk", tight: false),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Kolding St. → Jönköping C").clack(.detailRoute).foregroundStyle(Ink.text)
                Text("Style \(style): " + title).clack(.caption).foregroundStyle(Ink.text2)
                switch style {
                case "A": current
                case "C": scaled
                case "D": strip
                default: cards
                }
            }
            .padding(16)
        }
        .background(Ink.bg)
    }

    private var title: String {
        switch style {
        case "A": "today: trains and changes as equal blocks on one rail"
        case "C": "the rail drawn to time: trains long and coloured, changes short gaps"
        case "D": "a whole-journey strip on top, then one card per train; changes as chips"
        default: "trains as cards, changes as thin rows between them"
        }
    }

    // MARK: A, today

    private var current: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(trains.enumerated()), id: \.element.id) { i, t in
                if i > 0 {
                    let c = changes[i - 1]
                    railRow(color: Ink.accent, dashed: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Change at \(c.at)").clack(.banner).fontWeight(.semibold).foregroundStyle(Ink.text)
                            Text("Platform \(c.tracks) · \(c.walk) · \(c.minutes) min to change").clack(.caption).foregroundStyle(Ink.text2)
                            Text("Relaxed").clack(.chip).foregroundStyle(Ink.onTimeInk)
                            Text("Station map ›").clack(.caption).foregroundStyle(Ink.accentInk)
                        }
                        .padding(.vertical, 14)
                    }
                }
                railRow(color: t.color, dashed: false) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(t.op) \(t.number)").clack(.trainNumber).foregroundStyle(Ink.text2)
                        Text("\(t.from) → \(t.to)").clack(.rowTitle).foregroundStyle(Ink.text)
                        Text("\(t.dep) – \(t.arr)").clack(.caption).foregroundStyle(Ink.text2)
                    }
                    .padding(.vertical, 10)
                }
            }
        }
    }

    private func railRow<C: View>(color: Color, dashed: Bool, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 28)
            .background(alignment: .leading) {
                Rectangle().fill(color).frame(width: dashed ? 0 : 2)
                    .overlay { if dashed { Line().stroke(color, style: StrokeStyle(lineWidth: 2, dash: [3, 4])) } }
                    .frame(width: 2).padding(.leading, 9)
            }
    }

    // MARK: B, trains as cards, changes as thin rows

    private var cards: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(trains.enumerated()), id: \.element.id) { i, t in
                if i > 0 { thinChange(changes[i - 1]) }
                trainCard(t)
            }
        }
    }

    private func trainCard(_ t: Train) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: Radius.badge, style: .continuous).fill(t.color).frame(width: 34, height: 34)
                    .overlay(Text(t.op).font(.system(size: 11, weight: .heavy)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 0) {
                    Text(t.number).clack(.rowTitle).foregroundStyle(Ink.text)
                    if let s = t.status { Text(s).clack(.caption).foregroundStyle(t.progress >= 1 ? Ink.text2 : Ink.slightInk) }
                }
                Spacer()
                Text("\(t.minutes / 60 > 0 ? "\(t.minutes / 60) h " : "")\(t.minutes % 60) min").clack(.caption).foregroundStyle(Ink.text2)
            }
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.dep).clack(.bigTime).foregroundStyle(Ink.text)
                    Text(t.from).clack(.stopName).foregroundStyle(Ink.text)
                    Text("Platform \(t.depTrack)").clack(.caption).foregroundStyle(Ink.text2)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(t.arr).clack(.bigTime).foregroundStyle(Ink.text)
                    Text(t.to).clack(.stopName).foregroundStyle(Ink.text)
                    Text("Platform \(t.arrTrack)").clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            ProgressBar(value: t.progress, color: t.color)
        }
        .padding(14)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).strokeBorder(Ink.hairline))
    }

    private func thinChange(_ c: Change) -> some View {
        HStack(spacing: 8) {
            Line().stroke(Ink.text3, style: StrokeStyle(lineWidth: 2, dash: [3, 4])).frame(width: 2, height: 34).padding(.leading, 30)
            Text("Change at \(c.at) · \(c.minutes) min · \(c.tracks) · \(c.walk)")
                .clack(.caption).foregroundStyle(c.tight ? Ink.lateInk : Ink.text2)
                .lineLimit(2)
        }
    }

    // MARK: C, the rail to time

    private var scaled: some View {
        let total = Double(trains.reduce(0) { $0 + $1.minutes } + changes.reduce(0) { $0 + $1.minutes })
        let height = 640.0
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(trains.enumerated()), id: \.element.id) { i, t in
                if i > 0 {
                    let c = changes[i - 1]
                    HStack(alignment: .center, spacing: 12) {
                        Line().stroke(Ink.text3, style: StrokeStyle(lineWidth: 2, dash: [2, 3])).frame(width: 2).padding(.horizontal, 7)
                        Text("Change \(c.minutes) min · \(c.tracks)").clack(.micro).foregroundStyle(Ink.text2)
                    }
                    .frame(height: max(26, height * Double(c.minutes) / total))
                }
                HStack(alignment: .top, spacing: 12) {
                    RoundedRectangle(cornerRadius: Radius.bar).fill(t.color).frame(width: 8)
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: Radius.bar).fill(Color.white.opacity(0.0)).frame(height: 0)
                        }
                        .padding(.horizontal, 4)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack { Text(t.dep).clack(.rowTitle); Text(t.from).clack(.stopName) }.foregroundStyle(Ink.text)
                        Text("\(t.op) \(t.number)" + (t.status.map { " · \($0)" } ?? "")).clack(.caption).foregroundStyle(Ink.text2)
                        Spacer(minLength: 0)
                        HStack { Text(t.arr).clack(.rowTitle); Text(t.to).clack(.stopName) }.foregroundStyle(Ink.text)
                    }
                }
                .frame(height: max(70, height * Double(t.minutes) / total))
            }
        }
    }

    // MARK: D, strip + cards

    private var strip: some View {
        let total = Double(trains.reduce(0) { $0 + $1.minutes } + changes.reduce(0) { $0 + $1.minutes })
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { g in
                    HStack(spacing: 2) {
                        ForEach(Array(trains.enumerated()), id: \.element.id) { i, t in
                            if i > 0 {
                                Color.clear.frame(width: g.size.width * Double(changes[i - 1].minutes) / total)
                                    .overlay(Line().stroke(Ink.text3, style: StrokeStyle(lineWidth: 2, dash: [2, 3])).rotationEffect(.degrees(90)).frame(height: 2))
                            }
                            RoundedRectangle(cornerRadius: Radius.bar).fill(t.color).frame(width: g.size.width * Double(t.minutes) / total)
                        }
                    }
                }
                .frame(height: 8)
                HStack {
                    Text("10:12 Kolding").clack(.micro)
                    Spacer()
                    Text("2 changes · 7 h").clack(.micro)
                    Spacer()
                    Text("17:12 Jönköping").clack(.micro)
                }
                .foregroundStyle(Ink.text2)
            }
            ForEach(Array(trains.enumerated()), id: \.element.id) { i, t in
                if i > 0 {
                    let c = changes[i - 1]
                    Text("↓ \(c.minutes) min at \(c.at) · platform \(c.tracks)")
                        .clack(.chip).foregroundStyle(Ink.text2)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Ink.fillSoft, in: RoundedRectangle(cornerRadius: Radius.tag, style: .continuous))
                        .padding(.leading, 14)
                }
                trainCard(t)
            }
        }
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}
#endif
