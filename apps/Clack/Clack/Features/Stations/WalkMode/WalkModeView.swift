//
//  WalkModeView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Walk mode (owner, 2026-11-08): the station plan at human scale, heading-up and following you, about 15 m across
/// with you a third up from the bottom, the next step on top with its distance counting down. A pan (or Overhead)
/// leaves the camera for the plan as it is; Follow me goes back.
struct WalkModeView: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let map: StationMap
    let route: StationRoute
    let levelName: (String) -> String
    let poiState: (StationPoi) -> OpenState

    @State private var positioner: WalkPositioner
    @State private var overhead = false

    init(map: StationMap, route: StationRoute, simulate: Bool, levelName: @escaping (String) -> String, poiState: @escaping (StationPoi) -> OpenState) {
        self.map = map
        self.route = route
        self.levelName = levelName
        self.poiState = poiState
        _positioner = State(initialValue: WalkPositioner(map: map, route: route, simulate: simulate))
    }

    private var tracker: WalkTracker { positioner.tracker }

    /// Under Reduce Motion the plan turns in 30° steps, not with every degree of the compass.
    private var heading: Double {
        reduceMotion ? (positioner.heading / 30).rounded() * 30 : positioner.heading
    }

    var body: some View {
        let position = tracker.position
        let level = position?.level ?? tracker.level
        let me = position.map {
            StationSceneLogic.PlacePin(x: $0.pt.x, y: $0.pt.y, level: level, label: l10n.t("stationMap.myLocationApprox"), kind: .me,
                                       accuracyM: positioner.accuracy, headingDeg: positioner.compass)
        }
        ZStack(alignment: .top) {
            StationSceneView(
                map: map, level: level, route: route, marks: [], pins: me.map { [$0] } ?? [], poiState: poiState, dimPoi: { _ in false },
                onPoi: { _ in }, fitKey: "walk|\(level)|\(overhead)",
                insets: .init(top: 200, bottom: 140),
                camera: overhead ? nil : position.map { StationSceneLogic.Camera(x: $0.pt.x, y: $0.pt.y, heading: heading) },
                onCameraPan: { overhead = true }
            )
            .ignoresSafeArea()
            card
            VStack {
                Spacer()
                HStack(spacing: 12) {
                    MapButton(icon: overhead ? "navigation" : "map", label: l10n.t(overhead ? "stationMap.walkMode.follow" : "stationMap.walkMode.overhead")) { overhead.toggle() }
                    Spacer()
                    MapButton(icon: "x", label: l10n.t("common.close")) { dismiss() }
                }
                .padding(.horizontal, 16).padding(.bottom, 24)
            }
        }
        .background(Ink.mapBg)
        .onAppear { positioner.start() }
        .onDisappear { positioner.stop() }
        // A tap of the hand for each new step, and the step read out to VoiceOver.
        .sensoryFeedback(.impact(weight: .medium), trigger: tracker.index)
        .onChange(of: tracker.index) {
            AccessibilityNotification.Announcement(stepText(tracker.step) ?? l10n.t("stationMap.walkMode.arrived")).post()
        }
        .countsScreen("walkMode")
    }

    private func stepText(_ step: RouteGuide.Step?) -> String? {
        guard let step else { return nil }
        let w = RouteGuide.wording(step, levelName: levelName, sideName: { l10n.t("stationMap.side.\($0.rawValue)") })
        return l10n.t(w.key, w.values)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let step = tracker.step {
                Text(stepText(step) ?? "").clack(.walkBig).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                if step.key == .walk {
                    Text(l10n.t("stationMap.walkMode.toGo", ["m": String(Int((tracker.remaining / 5).rounded() * 5))])).clack(.headline).monospacedDigit().foregroundStyle(Ink.text2)
                }
                if tracker.askConfirm {
                    Button { positioner.confirmLevel() } label: {
                        Text(l10n.t("stationMap.walkMode.confirmLevel", ["level": levelName(step.level)]))
                            .clack(.buttonSmall).foregroundStyle(Ink.onAccent).padding(.horizontal, 16).frame(minHeight: 44)
                            .background(Ink.accent, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                if let next = tracker.steps.dropFirst(tracker.index + 1).first, let text = stepText(next) {
                    Text(l10n.t("stationMap.walkMode.then", ["step": text])).clack(.caption).foregroundStyle(Ink.text2)
                }
            } else {
                Text(l10n.t("stationMap.walkMode.arrived")).clack(.walkBig).foregroundStyle(Ink.text)
            }
            if tracker.estimated(now: positioner.now) {
                Text(l10n.t("stationMap.walkMode.estimated")).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .padding(.horizontal, 12).padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}
