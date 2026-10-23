//
//  LegsListView.swift
//  Clack
//

import SwiftUI

/// Temporary screen for step 1: lists `GET /api/legs` (route and date per leg) to prove the foundation works.
/// Step 5 replaces it with the real Trips screen.
struct LegsListView: View {
    @Environment(AppModel.self) private var app
    @State private var legs: [Leg] = []
    @State private var failed = false
    @State private var loaded = false

    var body: some View {
        let l10n = app.l10n
        NavigationStack {
            Group {
                if failed {
                    ContentUnavailableView {
                        Text(l10n.t("trips.loadError"))
                    } description: {
                        Text(l10n.t("common.offline"))
                    } actions: {
                        Button(l10n.t("trips.retry")) { Task { await load() } }
                    }
                } else if !loaded {
                    ProgressView(l10n.t("common.loading"))
                } else if legs.isEmpty {
                    ContentUnavailableView {
                        Text(l10n.t("trips.emptyTitle"))
                    } description: {
                        Text(l10n.t("trips.emptyBody"))
                    }
                } else {
                    List(legs) { leg in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(leg.origin?.name ?? "") → \(leg.destination?.name ?? "")")
                            Text(subtitle(leg)).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
                        }
                    }
                }
            }
            #if DEBUG
            // Debug only, so a phone's trips can be found on the server (the web app uses the shared "local" user).
            .safeAreaInset(edge: .bottom) {
                Text(app.identity).font(.caption2.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
            }
            #endif
            .navigationTitle(l10n.t("trips.title"))
            .refreshable { await load() }
        }
        .task { await load() }
    }

    /// Date in the origin station's time zone ("Never the phone's"), then the train number.
    private func subtitle(_ leg: Leg) -> String {
        var parts: [String] = []
        if let dep = leg.schedDep?.date {
            let zone = TimeZone(identifier: leg.origin?.tz ?? "Europe/Stockholm") ?? .gmt
            let locale = Locale(identifier: app.l10n.language == .sv ? "sv_SE" : "en_GB")
            parts.append(dep.formatted(
                Date.FormatStyle(date: .abbreviated, time: .shortened, locale: locale, timeZone: zone)
            ))
        }
        if let number = leg.trainNumber { parts.append(number) }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        do {
            legs = try await app.client.get(["legs"])
            failed = false
        } catch {
            failed = true
        }
        loaded = true
    }
}
