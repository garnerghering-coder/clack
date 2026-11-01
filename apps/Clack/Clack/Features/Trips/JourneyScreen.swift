//
//  JourneyScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A multi-leg journey (owner, 2026-11-01): the same screen as a single train (map, live status, stops, platform,
/// seat) for the train in focus, with the whole journey's bar on top and every train and change below. During the trip
/// the train in focus is the one you're on (or next to board) and follows you at each change; before and after it is the
/// first. Tapping another train's card puts that one in focus until you leave the screen.
struct JourneyScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let id: String
    @State private var journey: Journey?
    @State private var missing = false
    @State private var lastReload: Date = .distantPast
    /// The train picked by hand; nil follows the journey (the train under way, else the first).
    @State private var picked: String?
    /// The train under way or next to leave, re-worked every 30 s and on every reload.
    @State private var current: String?

    private var legs: [Leg] { TripsLogic.taken((journey?.legs ?? []).map(\.leg)) }

    private func updateCurrent() {
        let legs = legs
        let index = TripsLogic.nowLegIndex(legs, now: Date.now.timeIntervalSince1970 * 1000)
        let next = index.map { legs[$0].id } ?? legs.first?.id
        if next != current { current = next }
    }

    var body: some View {
        Group {
            if missing {
                Page {
                    BackLink(label: router.backLabel(l10n))
                    Text(l10n.t("journey.notFound")).clack(.body).foregroundStyle(Ink.text2)
                }
            } else if let focus = picked ?? current, !legs.isEmpty {
                TripDetailScreen(id: focus, journey: JourneyContext(id: id, legs: legs, select: { picked = $0 }))
                    // A new train in focus is a fresh screen (its map, its live stream, its sections).
                    .id(focus)
            } else {
                Page { Skeleton(height: 120) }
            }
        }
        .countsScreen("journey")
        .task(id: id) {
            do {
                journey = try await app.client.journey(id)
                updateCurrent()
            } catch {
                missing = true
            }
        }
        .task(id: journey?.legs.map(\.id)) {
            while !Task.isCancelled {
                updateCurrent()
                try? await Task.sleep(for: .seconds(30))
            }
        }
        .task(id: id) {
            // A live update for one of its trains (a delay, a platform): reload, at most every 20 s, so the cards and
            // the changes recompute and the focus moves on at a change.
            for await update in app.live.updates() {
                guard journey?.legs.contains(where: { $0.id == update.legId }) == true,
                      Date.now.timeIntervalSince(lastReload) >= 20 else { continue }
                lastReload = .now
                if let fresh = try? await app.client.journey(id) {
                    journey = fresh
                    updateCurrent()
                }
            }
        }
    }
}
