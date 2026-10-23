//
//  StationsScreen.swift
//  Clack
//

import SwiftUI

/// Station search (StationsPage.tsx): one field, favourites and recent stations when it's empty.
struct StationsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @State private var query = ""
    @State private var hits: [StationHit]?
    @State private var favorites: [StationHit] = []
    @State private var recent: [StationHit] = []
    @State private var popular: [StationHit] = []
    @FocusState private var focused: Bool

    var body: some View {
        Page {
            BackLink(label: l10n.t("nav.trips"))
            PageHeader(title: l10n.t("stations.title"))
            field
            if let hits {
                if hits.isEmpty {
                    Text(l10n.t("stations.noMatch")).clack(.body).foregroundStyle(Ink.text2)
                } else {
                    list(hits)
                }
            } else {
                let favoriteIds = Set(favorites.map(\.id))
                section(l10n.t("stations.favorites"), favorites, star: true)
                section(l10n.t("stations.recent"), recent.filter { !favoriteIds.contains($0.id) })
                section(l10n.t("stations.popular"), popular.filter { p in !favoriteIds.contains(p.id) && !recent.contains { $0.id == p.id } })
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task {
            focused = true
            async let f = try? app.client.favoriteStations()
            async let r = try? app.client.recentStations()
            async let p = try? app.client.popularStations()
            favorites = await f ?? []
            recent = await r ?? []
            popular = await p ?? []
        }
        // Debounced 120 ms; typing again cancels the one before.
        .task(id: query) {
            let text = query.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { hits = nil; return }
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            if let found = try? await app.client.searchStations(text) { hits = found }
        }
    }

    private var field: some View {
        TextField("", text: $query, prompt: Text(l10n.t("stations.placeholder")).foregroundStyle(Ink.text3).fontWeight(.medium))
            .focused($focused)
            .clack(.searchField)
            .foregroundStyle(Ink.text)
            .tint(Ink.accentLine)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.search)
            .padding(.horizontal, 14)
            .frame(height: 52)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
            .hairlineBorder(radius: Radius.input, color: focused ? Ink.accentLine : Ink.hairline)
            .accessibilityLabel(l10n.t("stations.placeholder"))
    }

    @ViewBuilder
    private func section(_ title: String, _ stations: [StationHit], star: Bool = false) -> some View {
        if !stations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2)
                list(stations, star: star)
            }
        }
    }

    private func list(_ stations: [StationHit], star: Bool = false) -> some View {
        VStack(spacing: 0) {
            ForEach(stations) { station in
                StationRow(
                    station: station,
                    trailing: star ? AnyView(LucideIcon(name: "star", size: 16).foregroundStyle(Ink.accentInk).accessibilityLabel(l10n.t("stations.favorite"))) : nil
                ) {
                    router.push(.board(stationId: station.id, arrivals: false))
                }
            }
        }
    }
}
