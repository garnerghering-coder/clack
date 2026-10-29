//
//  RideScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The Ride view (BUILDOUT O3): Apple's 3D map following the train you're on (or any running train), the train
/// drawn in 3D with as many cars as the data gives, a speedometer from the phone's GPS once you're aboard, and the
/// trip: next stop, delay, what's left. Four camera presets (system picker), pinch for the distance. Portrait puts
/// the panel below the map, landscape beside it.
struct RideScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    @Environment(\.verticalSizeClass) private var vertical
    @State private var model: RideModel
    @State private var now = Date.now.timeIntervalSince1970 * 1000

    init(target: RideTarget) {
        _model = State(initialValue: RideModel(target: target))
    }

    var body: some View {
        // The map and the panel never overlap: the map's centre stays the camera's centre (an overlapping panel
        // skewed the 3D train against the map) and Apple's attribution stays in view.
        Group {
            if vertical == .compact {
                HStack(spacing: 0) {
                    map
                    panel.frame(width: 300)
                }
            } else {
                VStack(spacing: 0) {
                    map
                    panel
                }
            }
        }
        .background(Ink.bg)
        .navigationTitle(model.title.isEmpty ? l10n.t("ride.title") : model.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await model.run(app) }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                now = Date.now.timeIntervalSince1970 * 1000
            }
        }
    }

    @ViewBuilder
    private var map: some View {
        if let track = model.track {
            RideMapView(
                track: track, template: model.template, cars: model.cars.count, brandColor: model.brandColor, camera: model.camera,
                report: model.report, dark: scheme == .dark,
                onPinch: { scale, ended in model.pinch(scale: scale, ended: ended) },
                onDrag: { dx, dy, width in model.orbit(dx: dx, dy: dy, width: width) }
            )
            .ignoresSafeArea(edges: vertical == .compact ? [.top, .bottom, .leading] : [.top, .horizontal])
            .accessibilityLabel(l10n.t("ride.mapLabel"))
        } else {
            VStack(spacing: 12) {
                if model.status == .loading { ProgressView() }
                Text(statusText).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    private var statusText: String {
        switch model.status {
        case .loading: l10n.t("ride.loading")
        case .running: ""
        case .notRunning: l10n.t("ride.notRunning")
        case .noTrack: l10n.t("ride.noTrack")
        case .failed: l10n.t("network.failed")
        }
    }

    private var panel: some View {
        let speed = model.speed(now: now)
        let next = model.nextStop(now: now)
        let left = model.left(now: now)
        return VStack(alignment: .leading, spacing: 12) {
            Text(l10n.t("ride.orbitHint")).clack(.micro).foregroundStyle(Ink.text3)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(speed.kmh.map { "\(Int($0.rounded())) km/h" } ?? "—").clack(.timeBig).monospacedDigit().foregroundStyle(Ink.text)
                    Text(speedCaption(speed.source)).clack(.micro).foregroundStyle(Ink.text3)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    if let delay = model.train?.delayMin { DelayText(delay: delay) }
                    Text(model.cars.known ? l10n.t("ride.cars", count: model.cars.count) : l10n.t("ride.carsAbout", ["n": String(model.cars.count)]))
                        .clack(.micro).foregroundStyle(Ink.text3)
                }
            }
            if let next {
                HStack(spacing: 8) {
                    Text(l10n.t("live.nextStopName", ["name": next.name])).clack(.body).foregroundStyle(Ink.text).lineLimit(1)
                    Spacer(minLength: 8)
                    if let eta = next.eta { Text(Format.time(eta, tz: model.tz, clock: app.settings.clock)).clack(.body).monospacedDigit().foregroundStyle(Ink.text) }
                }
            }
            HStack(spacing: 12) {
                if let left { Text(l10n.t("ride.left", ["km": String(format: "%.0f", left.km), "min": String(left.min)])).clack(.caption).foregroundStyle(Ink.text2) }
                if speed.source == .phone, let alt = model.altitudeM {
                    Text(l10n.t("ride.altitude", ["m": String(Int(alt.rounded()))])).clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            Text(l10n.t("ride.buildings")).clack(.micro).foregroundStyle(Ink.text3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.bg)
    }

    private func speedCaption(_ source: RideLogic.SpeedSource) -> String {
        switch source {
        case .phone: l10n.t("ride.speed.phone")
        case .trainLive: l10n.t("ride.speed.train")
        case .trainEstimated: l10n.t("ride.speed.estimated")
        case .none: l10n.t("ride.speed.none")
        }
    }
}
