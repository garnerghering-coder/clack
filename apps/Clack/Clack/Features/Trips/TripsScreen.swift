//
//  TripsScreen.swift
//  Clack
//

import SwiftUI

/// Temporary Trips tab for the foundation and design steps: the header and a plain list of `GET /api/legs` (route
/// and date per leg) to prove the app reads the server. Step 5 replaces the list with the real Trips screen.
struct TripsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @State private var legs: [Leg] = []
    @State private var failed = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Page {
                PageHeader(title: l10n.t("trips.title")) { SettingsLink() }
                if failed {
                    VStack(spacing: 10) {
                        Text(l10n.t("trips.loadError")).clack(.headline).foregroundStyle(Ink.text)
                        Text(l10n.t("common.offline")).clack(.body).foregroundStyle(Ink.text2)
                        Button(l10n.t("trips.retry")) { Task { await load() } }.buttonStyle(.clack())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                    .multilineTextAlignment(.center)
                } else if !loaded {
                    VStack(spacing: 10) {
                        Skeleton(height: 120)
                        Skeleton()
                        Skeleton()
                    }
                } else if legs.isEmpty {
                    VStack(spacing: 10) {
                        Text(l10n.t("trips.emptyTitle")).clack(.headline).foregroundStyle(Ink.text)
                        Text(l10n.t("trips.emptyBody")).clack(.body).foregroundStyle(Ink.text2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 48)
                    .multilineTextAlignment(.center)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(legs) { leg in
                            row(leg)
                        }
                    }
                }
                #if DEBUG
                // Debug only, so a phone's trips can be found on the server (the web app uses the shared "local" user).
                Text(app.identity).font(.caption2.monospaced()).foregroundStyle(Ink.text3).textSelection(.enabled)
                #endif
            }
            .refreshable { await load() }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await load() }
    }

    /// `.leg-row`: the route over its date and number, a hairline underneath.
    private func row(_ leg: Leg) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                .clack(.rowTitle).foregroundStyle(Ink.text)
            Text(subtitle(leg)).clack(.caption).foregroundStyle(Ink.text2).monospacedDigit().lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    /// Date in the origin station's time zone ("Never the phone's"), then the train number.
    private func subtitle(_ leg: Leg) -> String {
        var parts: [String] = []
        if let dep = leg.schedDep?.ms {
            let tz = leg.origin?.tz ?? "Europe/Stockholm"
            parts.append("\(Format.day(dep, tz: tz, language: app.settings.language)) \(Format.time(dep, tz: tz, clock: app.settings.clock))")
        }
        if let number = leg.trainNumber { parts.append(number) }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        do {
            legs = try await app.client.get(["legs"])
            failed = false
            app.noteSuccess()
        } catch {
            failed = true
            app.noteFailure(error)
        }
        loaded = true
    }
}
