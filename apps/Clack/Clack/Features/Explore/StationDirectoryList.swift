//
//  StationDirectoryList.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Explore's search before anything is typed: your favourite stations (with the board's filled star), the ones you
/// looked at lately, and the big ones. This was the Stations screen on Trips (StationsPage.tsx); typing searches
/// stations and trains in the same field.
struct StationDirectoryList: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let onPick: (StationHit) -> Void
    let onClose: () -> Void
    @State private var favorites: [StationHit] = []
    @State private var recent: [StationHit] = []
    @State private var popular: [StationHit] = []
    @State private var loaded = false

    var body: some View {
        SearchPanel(maxHeight: 520) {
            VStack(alignment: .leading, spacing: 12) {
                let favoriteIds = Set(favorites.map(\.id))
                section(l10n.t("stations.favorites"), favorites, star: true)
                section(l10n.t("stations.recent"), recent.filter { !favoriteIds.contains($0.id) })
                section(l10n.t("stations.popular"), popular.filter { p in !favoriteIds.contains(p.id) && !recent.contains { $0.id == p.id } })
                if !loaded { Text(l10n.t("common.loading")).clack(.caption).foregroundStyle(Ink.text2) }
                Button(l10n.t("common.close"), action: onClose).buttonStyle(LinkButtonStyle())
            }
        }
        .task {
            async let f = try? app.client.favoriteStations()
            async let r = try? app.client.recentStations()
            async let p = try? app.client.popularStations()
            favorites = await f ?? []
            recent = await r ?? []
            popular = await p ?? []
            loaded = true
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ stations: [StationHit], star: Bool = false) -> some View {
        if !stations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2)
                ForEach(stations) { station in
                    StationRow(
                        station: station,
                        // The same filled star as the board's favourite button.
                        trailing: star ? AnyView(LucideIcon(name: "star", size: 16, filled: true, label: l10n.t("stations.favorite")).foregroundStyle(Ink.accentInk)) : nil
                    ) {
                        onPick(station)
                    }
                }
            }
        }
    }
}
