//
//  ArrivalScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The end of a journey, on an arrivals board (owner, 2026-10-23): the destination flips in, a stamp lands, then what
/// the whole journey came to and what it did for the Passport. Calm: no confetti.
struct ArrivalScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    let moment: ArrivalMoment

    @State private var journey: Journey?
    @State private var progress: TripProgress?
    @State private var settled = false

    private var legs: [Leg] { journey?.legs.map(\.leg) ?? [] }

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let last = legs.last, let destination = last.destination {
                        header(last, destination)
                        summary
                        // What the journey did for your milestones plays straight after the board settles, up here
                        // where it is seen, not under the map.
                        if let progress, progress.counted, settled {
                            TripProgressView(legId: last.id, quietIfNothing: true, given: progress)
                                .transition(.opacity)
                        }
                        if let journey, !journey.legs.isEmpty { map(journey) }
                    } else {
                        Skeleton(height: 120)
                    }
                    actions
                }
                .padding(16)
            }
        }
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .snappy, value: settled)
        .sensoryFeedback(.impact(weight: .heavy), trigger: settled)
        .sensoryFeedback(.success, trigger: progress?.unlocked.count ?? 0)
        .task {
            app.arrivals.markShown(moment)
            await load()
        }
    }

    private func header(_ last: Leg, _ destination: StationRef) -> some View {
        let arr = TripsLogic.expected(last).arr ?? 0
        let name = destination.name.uppercased()
        return VStack(alignment: .leading, spacing: 12) {
            Text("\(l10n.t("arrival.arrived")) · \(Format.time(arr, tz: destination.tz, clock: app.settings.clock))")
                .clack(.captionUpper).foregroundStyle(Ink.accent)
            Text(l10n.t("arrival.welcomeTo")).clack(.welcomeTitle).foregroundStyle(Ink.text)
            ArrivalBoard(name: name, plain: destination.name) { settled = true }
        }
    }

    @ViewBuilder
    private var summary: some View {
        let s = ArrivalLogic.summary(legs)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Tile(label: l10n.t("passport.timeOnTrains"), value: Format.duration(s.minutesOnBoard))
                Tile(label: l10n.t("passport.trains"), value: String(s.trains))
                if let distance = s.distanceM {
                    Tile(label: l10n.t("detail.distance"), value: Format.distance(distance, unit: app.settings.distanceUnit, language: app.settings.language))
                }
            }
            if let line = punctuality(s.arrDelayMin) {
                Text(line).clack(.body).foregroundStyle(Ink.text2)
            }
        }
    }

    private func punctuality(_ delay: Int?) -> String? {
        guard let delay else { return nil }
        if delay < 0 { return l10n.t("delay.explainEarly", count: -delay) }
        if delay == 0 { return l10n.t("delay.explainOnTime") }
        return l10n.t("delay.explainLate", count: delay)
    }

    private func map(_ journey: Journey) -> some View {
        MultiRouteMapView(
            routes: journey.legs.map {
                MultiRoute(color: MapStyle.opColor($0.leg.operator?.brandColor, dark: scheme == .dark), geometry: $0.geometry, stops: [])
            },
            stations: stations(journey), railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel")
        )
        .frame(height: 200)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    /// A dot at each station the journey used: where each train was boarded and left, a change counting for both.
    private func stations(_ journey: Journey) -> [MultiStation] {
        var out: [MultiStation] = []
        for leg in journey.legs {
            guard let points = leg.geometry.map(Polyline.decode), let first = points.first, let last = points.last else { continue }
            for (point, name) in [(first, leg.leg.origin?.name), (last, leg.leg.destination?.name)] {
                guard let name else { continue }
                if let i = out.firstIndex(where: { $0.name == name }) { out[i].count += 1 } else { out.append(MultiStation(lat: point.lat, lon: point.lon, name: name, count: 1)) }
            }
        }
        return out
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(l10n.t("common.done")) { dismiss() }
                .buttonStyle(ClackButtonStyle(kind: .primary, wide: true))
            Button(l10n.t("arrival.seeJourney")) {
                let route: AppRoute = moment.journeyId.map(AppRoute.journey) ?? .trip(moment.legId)
                dismiss()
                router.push(route)
            }
            .buttonStyle(LinkButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }

    /// The journey, then what each of its legs did for the Passport, put together.
    private func load() async {
        let id = moment.journeyId ?? "j-\(moment.legId)"
        let loaded: Journey
        guard let fetched = try? await app.client.journey(id) else { return }
        loaded = fetched
        journey = loaded
        let client = app.client
        let parts = await withTaskGroup(of: TripProgress?.self) { group in
            for leg in loaded.legs { group.addTask { try? await client.tripProgress(leg.id) } }
            var out: [TripProgress] = []
            for await part in group { if let part { out.append(part) } }
            return out
        }
        if !parts.isEmpty { progress = ArrivalLogic.merge(parts) }
    }
}

/// The destination on a split-flap board that clatters through letters before it settles on the name, as a board does
/// when it changes (owner, 2026-10-24). With Reduce Motion it just shows the name.
private struct ArrivalBoard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let name: String
    let plain: String
    let onSettled: () -> Void
    @State private var shown: String

    init(name: String, plain: String, onSettled: @escaping () -> Void) {
        self.name = name
        self.plain = plain
        self.onSettled = onSettled
        _shown = State(initialValue: String(repeating: " ", count: name.count))
    }

    private static let letters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZÅÄÖ")

    /// How long one round of flips takes: the last tile starts after the others, then flips for 360 ms.
    private static func roundMs(_ count: Int) -> Int { 380 + count * Int(Self.stagger * 1000) }
    private static let stagger = 0.02

    private func scramble() -> String {
        String(name.map { $0 == " " ? " " : Self.letters.randomElement() ?? "A" })
    }

    var body: some View {
        SplitFlap(value: shown, size: name.count <= 12 ? .lg : (name.count <= 17 ? .md : .sm), stagger: Self.stagger)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(plain)
            .task {
                guard !reduceMotion else {
                    shown = name
                    onSettled()
                    return
                }
                // Blank, one round of letters, then the name: each change flips the tiles left to right, quickly.
                try? await Task.sleep(for: .milliseconds(150))
                shown = scramble()
                try? await Task.sleep(for: .milliseconds(Self.roundMs(name.count)))
                shown = name
                try? await Task.sleep(for: .milliseconds(Self.roundMs(name.count)))
                onSettled()
            }
    }
}
