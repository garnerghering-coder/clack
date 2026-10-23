//
//  ArrivalScreen.swift
//  Clack
//

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
    @State private var stamped = false

    private var legs: [Leg] { journey?.legs.map(\.leg) ?? [] }

    var body: some View {
        ZStack {
            Ink.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let last = legs.last, let destination = last.destination {
                        header(last, destination)
                        summary
                        if let journey, !journey.legs.isEmpty { map(journey) }
                        if let progress, progress.counted {
                            TripProgressView(legId: last.id, quietIfNothing: true, given: progress)
                        }
                    } else {
                        Skeleton(height: 120)
                    }
                    actions
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.impact(weight: .heavy), trigger: stamped)
        .sensoryFeedback(.success, trigger: progress?.unlocked.count ?? 0)
        .task {
            app.arrivals.markShown(moment)
            await load()
        }
    }

    private func header(_ last: Leg, _ destination: StationRef) -> some View {
        let arr = TripsLogic.expected(last).arr ?? 0
        let name = destination.name.uppercased()
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(l10n.t("arrival.arrived")) · \(Format.time(arr, tz: destination.tz, clock: app.settings.clock))")
                .clack(.captionUpper).foregroundStyle(Ink.accent)
            Text(l10n.t("arrival.welcomeTo")).clack(.welcomeTitle).foregroundStyle(Ink.text)
            SplitFlap(value: name, size: name.count <= 12 ? .lg : (name.count <= 17 ? .md : .sm), intro: true)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(destination.name)
            Stamp(name: destination.name, date: Format.longDate(arr, tz: destination.tz, language: app.settings.language), landed: stamped || reduceMotion)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .task {
                    // After the flaps have settled.
                    try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 1400))
                    withAnimation(.timingCurve(0.2, 1.4, 0.4, 1, duration: 0.45)) { stamped = true }
                }
        }
    }

    @ViewBuilder
    private var summary: some View {
        let s = ArrivalLogic.summary(legs)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Tile(title: l10n.t("passport.timeOnTrains"), value: Format.duration(s.minutesOnBoard))
                Tile(title: l10n.t("passport.trains"), value: String(s.trains))
                if let distance = s.distanceM {
                    Tile(title: l10n.t("detail.distance"), value: Format.distance(distance, unit: app.settings.distanceUnit, language: app.settings.language))
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
            stations: [], railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel")
        )
        .frame(height: 200)
        .allowsHitTesting(false)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
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

/// A passport stamp: the station and the date in a ring, set down at a slight tilt (DESIGN §10: scale 1.4 to 1).
private struct Stamp: View {
    let name: String
    let date: String
    let landed: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(name.uppercased()).clack(.captionUpper).fontWeight(.heavy).lineLimit(2).multilineTextAlignment(.center)
            Text(date).clack(.captionUpper)
        }
        .foregroundStyle(Ink.accent)
        .padding(14)
        .frame(maxWidth: 190)
        .overlay(RoundedRectangle(cornerRadius: Radius.card, style: .continuous).stroke(Ink.accent, lineWidth: 2))
        .rotationEffect(.degrees(landed ? -6 : -14))
        .scaleEffect(landed ? 1 : 1.4)
        .opacity(landed ? 1 : 0)
        .accessibilityHidden(true)
    }
}
