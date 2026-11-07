//
//  PassportBreakdownScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The cover opened (owner, 2026-11-07): every total, then each collection in full (operators, countries, stations,
/// kinds of train, train types) and the records. The same scope as the Passport (its year, its commuter setting).
struct PassportBreakdownScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(PassportStore.self) private var store
    @State private var loaded: Passport?
    @State private var failed = false

    private var data: Passport? { store.data ?? loaded }

    var body: some View {
        Page {
            if let data {
                Text(passportScopeLine(l10n, year: store.data == nil ? nil : store.year)).clack(.caption).foregroundStyle(Ink.text2)
                Card {
                    Text(l10n.t("passport.totals")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    totals(data)
                }
                section(l10n.t("passport.operators"), count: data.operators.count) { CollectionList(tab: .operators, data: data, limit: nil) }
                section(l10n.t("passport.countries"), count: data.countries.count) { CollectionList(tab: .countries, data: data, limit: nil) }
                section(l10n.t("passport.stationsVisited"), count: data.stations.count) { CollectionList(tab: .stations, data: data, limit: nil, stationLimit: nil) }
                section(l10n.t("passport.tab.kinds"), count: data.products.count) { CollectionList(tab: .kinds, data: data, limit: nil) }
                section(l10n.t("passport.trainTypes"), count: data.trainTypes.count) { CollectionList(tab: .trainTypes, data: data, limit: nil) }
                if PassportLogic.showsRecords(journeys: data.totals.journeys) {
                    Card {
                        Text(l10n.t("passport.records")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                        RecordsGrid(data: data)
                    }
                }
            } else if failed {
                Text(l10n.t("passport.loadError")).clack(.body).foregroundStyle(Ink.text2)
            } else {
                Skeleton(height: 120)
            }
        }
        .screenTitle(l10n.t("passport.breakdown"))
        .countsScreen("passport.breakdown")
        .task { await loadIfNeeded() }
    }

    /// Opened without the Passport behind it (a cold stack): all time, the commuter setting as it is.
    private func loadIfNeeded() async {
        guard store.data == nil else { return }
        do {
            loaded = try await app.client.passport(year: nil, commuter: app.settings.includeCommuter, comparison: app.settings.co2Comparison)
        } catch {
            failed = true
        }
    }

    private func totals(_ data: Passport) -> some View {
        let t = data.totals
        let s = app.settings
        return LazyVGrid(columns: [GridItem(.flexible(), alignment: .topLeading), GridItem(.flexible(), alignment: .topLeading)], alignment: .leading, spacing: 16) {
            Tile(label: l10n.t("detail.distance")) { Text(Format.distance(t.distanceM, unit: s.distanceUnit, language: s.language)) }
            Tile(label: l10n.t("passport.timeOnTrains")) { Text(Format.duration(t.minutes)) }
            Tile(label: l10n.t("passport.trains")) { Text(String(t.trains)) }
            Tile(label: l10n.t("passport.journeys")) { Text(String(t.journeys)) }
            Tile(label: l10n.t("passport.stations")) { Text(String(t.stations)) }
            Tile(label: l10n.t("passport.countries")) { Text(String(t.countries)) }
            Tile(label: l10n.t("passport.family.borderCrossings")) { Text(String(t.borderCrossings)) }
            Tile(label: l10n.t("passport.cancellations")) { Text(String(t.cancellations)) }
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, count: Int, @ViewBuilder content: () -> Content) -> some View {
        if count > 0 {
            Card {
                Text("\(title) · \(count)").clack(.sectionHeader).foregroundStyle(Ink.text2)
                content()
            }
        }
    }
}
