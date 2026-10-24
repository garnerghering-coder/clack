//
//  JourneyScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A multi-leg journey door to door: a summary, a combined map and the legs joined by connections (DESIGN §7).
struct JourneyScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let id: String
    @State private var journey: Journey?
    @State private var missing = false
    @State private var lastReload: Date = .distantPast
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Page {
            BackLink(label: l10n.t("nav.trips"))
            if missing {
                Text(l10n.t("journey.notFound")).clack(.body).foregroundStyle(Ink.text2)
            } else if let legs = journey?.legs.map(\.leg), let first = legs.first, let last = legs.last {
                let dep = first.actualDep?.ms ?? first.schedDep?.ms ?? 0
                let arr = last.actualArr?.ms ?? last.schedArr?.ms ?? 0
                let distance = legs.reduce(0) { $0 + ($1.distanceM ?? 0) }
                Text("\(first.origin?.name ?? "") → \(last.destination?.name ?? "")")
                    .clack(.detailRoute).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(Format.longDate(dep, tz: first.origin?.tz ?? "Europe/Stockholm", language: app.settings.language))
                    .clack(.body).foregroundStyle(Ink.text2)
                HStack(spacing: 12) {
                    Tile(label: l10n.t("journey.doorToDoor"), value: Format.duration((arr - dep) / 60_000))
                    Tile(label: l10n.t("passport.trains"), value: String(legs.count))
                    Tile(label: l10n.t("detail.distance"), value: Format.distance(distance, unit: app.settings.distanceUnit, language: app.settings.language))
                }
                MultiRouteMapView(
                    routes: (journey?.legs ?? []).map {
                        MultiRoute(color: MapStyle.opColor($0.leg.operator?.brandColor, dark: scheme == .dark), geometry: $0.geometry, stops: [])
                    },
                    stations: [], railNetwork: app.settings.showRailNetwork, label: l10n.t("journey.mapLabel")
                )
                .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                    .hairlineBorder(radius: Radius.card)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                        if index > 0 {
                            if legs[index - 1].destination?.id == leg.origin?.id {
                                ConnectionCard(a: legs[index - 1], b: leg)
                            } else {
                                TransferChip(prev: legs[index - 1], next: leg)
                            }
                        }
                        LegRow(leg: leg)
                            .padding(.vertical, 4)
                    }
                }
            } else {
                Skeleton(height: 120)
            }
        }
        .task(id: id) {
            do {
                journey = try await app.client.journey(id)
            } catch {
                missing = true
            }
        }
        .task(id: id) {
            // A live update for one of its trains (a delay, a platform): reload, at most every 20 s, so the connections
            // recompute.
            for await update in app.live.updates() {
                guard journey?.legs.contains(where: { $0.id == update.legId }) == true,
                      Date.now.timeIntervalSince(lastReload) >= 20 else { continue }
                lastReload = .now
                if let fresh = try? await app.client.journey(id) { journey = fresh }
            }
        }
    }
}
