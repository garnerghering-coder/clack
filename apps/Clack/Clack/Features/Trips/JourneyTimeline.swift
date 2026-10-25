//
//  JourneyTimeline.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// What the rail needs to know of each train: its colour, how far it has gone and whether it has left and arrived.
struct JourneyRail: Identifiable {
    let id: String
    let tint: Color
    /// How much of the train's way has been travelled (0 to 1).
    let travelled: Double
    let departed: Bool
    let arrived: Bool

    /// The rails of a traveller's own legs, and how much of each wait at a change has gone.
    static func of(_ legs: [Leg], now: Double, scheme: ColorScheme) -> (rails: [JourneyRail], waited: [Double]) {
        let rails = legs.map { leg -> JourneyRail in
            let times = TripsLogic.expected(leg)
            var travelled = 0.0
            if let dep = times.dep, let arr = times.arr, arr > dep { travelled = min(1, max(0, (now - dep) / (arr - dep))) }
            return JourneyRail(
                id: leg.id, tint: operatorColor(leg.operator?.brandColor, scheme: scheme), travelled: travelled,
                departed: (times.dep ?? .infinity) <= now, arrived: travelled >= 1
            )
        }
        let waited = zip(legs, legs.dropFirst()).map { a, b -> Double in
            let times = TripsLogic.connectionTimes(a, b)
            guard let arrival = times.arrival, let departure = times.departure, departure > arrival else { return 0 }
            return min(1, max(0, (now - arrival) / (departure - arrival)))
        }
        return (rails, waited)
    }

    /// The rails of a shared journey, from the copy a follower reads.
    static func of(_ j: SharedJourney, now: Double, scheme: ColorScheme) -> (rails: [JourneyRail], waited: [Double]) {
        let rails = j.legs.enumerated().map { index, leg -> JourneyRail in
            var travelled = 0.0
            if leg.arrived { travelled = 1 }
            else if let progress = leg.live?.progress, leg.departed { travelled = min(1, max(0, progress)) }
            else if let dep = leg.expDep, let arr = leg.expArr, arr > dep { travelled = min(1, max(0, (now - dep) / (arr - dep))) }
            return JourneyRail(
                id: "\(index)", tint: operatorColor(leg.operator?.brandColor, scheme: scheme), travelled: travelled,
                departed: leg.departed, arrived: leg.arrived
            )
        }
        let waited = zip(j.legs, j.legs.dropFirst()).map { a, b -> Double in
            guard let arrival = a.expArr, let departure = b.expDep, departure > arrival else { return 0 }
            return min(1, max(0, (now - arrival) / (departure - arrival)))
        }
        return (rails, waited)
    }
}

/// A journey as one vertical rail, in the design of a trip's stops: each leg is a solid line in its operator's colour
/// (filled as far as the train has gone, dotted where it is still to go), each change between legs is a dashed stretch
/// with a dot where you arrive and one where you leave. The rows are the caller's: a leg and a change each carry their
/// own touch target.
struct JourneyTimeline<LegContent: View, ChangeContent: View>: View {
    let rails: [JourneyRail]
    /// How much of the wait at the change after rail `i` has gone.
    let waited: [Double]
    let legContent: (Int) -> LegContent
    let changeContent: (Int) -> ChangeContent

    /// A traveller's own legs.
    init(
        legs: [Leg], now: Double, scheme: ColorScheme,
        @ViewBuilder leg legContent: @escaping (Leg) -> LegContent,
        @ViewBuilder change changeContent: @escaping (Leg, Leg) -> ChangeContent
    ) {
        let made = JourneyRail.of(legs, now: now, scheme: scheme)
        rails = made.rails
        waited = made.waited
        self.legContent = { legContent(legs[$0]) }
        self.changeContent = { changeContent(legs[$0], legs[$0 + 1]) }
    }

    /// The rails and rows of the caller's own making (a shared journey).
    init(
        rails: [JourneyRail], waited: [Double],
        @ViewBuilder leg legContent: @escaping (Int) -> LegContent,
        @ViewBuilder change changeContent: @escaping (Int) -> ChangeContent
    ) {
        self.rails = rails
        self.waited = waited
        self.legContent = legContent
        self.changeContent = changeContent
    }

    private static var railWidth: CGFloat { 20 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rails.enumerated()), id: \.element.id) { index, rail in
                if index > 0 { changeRow(index - 1) }
                legRow(index, rail)
            }
        }
    }

    private func legRow(_ index: Int, _ rail: JourneyRail) -> some View {
        let first = index == 0
        let last = index == rails.count - 1
        return legContent(index)
            .padding(.leading, Self.railWidth + 8)
            .background(alignment: .leading) {
                ZStack {
                    RailLine(color: rail.tint, fill: rail.travelled, dashed: false)
                        .padding(.top, first ? 7 : 0)
                        .padding(.bottom, last ? 7 : 0)
                    if first { dot(rail.tint, big: true, reached: rail.departed).frame(maxHeight: .infinity, alignment: .top) }
                    if last { dot(rail.tint, big: true, reached: rail.arrived).frame(maxHeight: .infinity, alignment: .bottom) }
                }
                .frame(width: Self.railWidth)
            }
    }

    private func changeRow(_ index: Int) -> some View {
        let a = rails[index]
        let b = rails[index + 1]
        let wait = waited.indices.contains(index) ? waited[index] : 0
        return changeContent(index)
            .padding(.vertical, 8)
            .padding(.leading, Self.railWidth + 8)
            .background(alignment: .leading) {
                ZStack {
                    RailLine(color: Ink.accent, fill: wait, dashed: true)
                    // Where you get off and where you get on again.
                    dot(a.tint, big: false, reached: a.arrived)
                        .frame(maxHeight: .infinity, alignment: .top).offset(y: -5)
                    dot(b.tint, big: false, reached: b.departed)
                        .frame(maxHeight: .infinity, alignment: .bottom).offset(y: 5)
                }
                .frame(width: Self.railWidth)
            }
    }

    private func dot(_ tint: Color, big: Bool, reached: Bool) -> some View {
        Circle()
            .fill(big || reached ? tint : Ink.text3)
            .frame(width: big ? 14 : 10, height: big ? 14 : 10)
            .overlay(Circle().strokeBorder(big ? Ink.text : Ink.bg, lineWidth: 2).padding(-2))
    }
}

/// The line of the rail: dotted where still to go (dashed for a change), in the colour where it has been.
private struct RailLine: View {
    let color: Color
    let fill: Double
    let dashed: Bool

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            let x = proxy.size.width / 2
            let style = dashed
                ? StrokeStyle(lineWidth: 2, lineCap: .butt, dash: [3, 4])
                : StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 5])
            Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: h))
            }
            .stroke(Ink.text3, style: style)
            if fill > 0 {
                if dashed {
                    Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x, y: h * fill))
                    }
                    .stroke(color, style: style)
                } else {
                    color.frame(width: 2, height: h * fill).position(x: x, y: h * fill / 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The change between two legs, for the rail: where, the tracks, the walk and the wait, how it stands. It opens the
/// station map when there is one. Two stations that differ (a walk between them) say it in a line.
struct JourneyChange: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let a: Leg
    let b: Leg
    @State private var model = ConnectionModel()

    var body: some View {
        if a.destination?.id == b.origin?.id {
            let result = model.result(a, b, profile: app.walkProfile)
            let walkMin = result.walkSeconds.map { max(1, Int(($0 / 60).rounded())) }
            let tracks = (a.arrPlatform != nil || b.depPlatform != nil)
                ? l10n.t("connection.tracks", ["from": a.arrPlatform ?? Format.unknown, "to": b.depPlatform ?? Format.unknown]) : nil
            let caption = [
                tracks,
                walkMin.map { l10n.t("connection.walk", ["min": String($0)]) },
                result.layoverSeconds.map { l10n.t("connection.layover", ["min": String(Int((Double($0) / 60).rounded()))]) },
            ].compactMap { $0 }.joined(separator: " · ")
            let content = VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("connection.changeAt", ["station": a.destination?.name ?? ""])).clack(.banner).fontWeight(.semibold).foregroundStyle(Ink.text)
                if !caption.isEmpty { Text(caption).clack(.caption).foregroundStyle(Ink.text2) }
                ConnectionChip(result: result)
                if model.map != nil {
                    HStack(spacing: 4) {
                        LucideIcon(name: "map", size: 14)
                        Text(l10n.t("trips.layoverMap") + " ›")
                    }
                    .clack(.caption).foregroundStyle(Ink.accentInk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            Group {
                if model.map != nil, let stationId = a.destination?.id {
                    NavigationLink(value: AppRoute.stationMap(TripsLogic.mapLink(stationId, a, b))) { content }
                        .buttonStyle(.plain)
                        .accessibilityLabel(l10n.t("trips.layoverOpen", ["station": a.destination?.name ?? ""]))
                } else {
                    content
                }
            }
            .task { await model.load(stationId: a.destination?.id, using: app.stations) }
        } else {
            TransferChip(prev: a, next: b, plain: true)
        }
    }
}
