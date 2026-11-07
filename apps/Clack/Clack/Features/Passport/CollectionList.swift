//
//  CollectionList.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// One of the Passport's collections as a list: operators, countries, stations, kinds of train or train types. `limit`
/// shows the first rows with "Show all" under them; nil shows every row (the Breakdown screen, owner 2026-11-07, where
/// the collections moved from the Passport's own page).
struct CollectionList: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let tab: PassportLogic.CollectionTab
    let data: Passport
    var limit: Int? = 6
    var stationLimit: Int? = 12
    @State private var showAllStations = false
    @State private var showAllRows = false

    var body: some View { content(tab) }

    // MARK: the collections

    @ViewBuilder
    private func content(_ tab: PassportLogic.CollectionTab) -> some View {
        let unit = app.settings.distanceUnit
        let ops = data.refs.operators
        VStack(alignment: .leading, spacing: 12) {
            switch tab {
            case .operators:
                Bars(rows: limited(data.operators, tab), unit: unit, label: { ops[$0.key]?.name ?? $0.key }, brand: { ops[$0.key]?.brandColor ?? "" }, lead: { OperatorBadge(op: ops[$0.key], size: .medium) })
                showAll(tab, total: data.operators.count)
            case .countries:
                VStack(spacing: 12) {
                    ForEach(limited(data.countries, tab), id: \.code) { country in
                        HStack(spacing: 12) {
                            Flag(country: country.code, size: 24, decorative: true)
                            Text(countryName(country.code)).clack(.rowTitle).foregroundStyle(Ink.text)
                            Spacer(minLength: 0)
                            Text(l10n.t("passport.trainsCount", count: country.legs)).clack(.caption).foregroundStyle(Ink.text2)
                        }
                    }
                }
                showAll(tab, total: data.countries.count)
                Text(l10n.t("passport.borders", count: data.totals.borderCrossings)).clack(.caption).foregroundStyle(Ink.text2)
            case .stations:
                stations
            case .kinds:
                Bars(rows: limited(data.products, tab), unit: unit, label: { l10n.t("products.\($0.key)") }, brand: { _ in nil }, lead: { _ in EmptyView() })
                showAll(tab, total: data.products.count)
            case .trainTypes:
                VStack(spacing: 12) {
                    ForEach(limited(data.trainTypes, tab), id: \.key) { row in
                        let type = data.refs.trainTypes[row.key]
                        HStack(spacing: 12) {
                            TrainPicture(type: type, operatorId: nil, height: 36).frame(width: 120, alignment: .leading).clipped()
                            VStack(alignment: .leading, spacing: 2) {
                                Text(type?.name ?? row.key).clack(.rowTitle).foregroundStyle(Ink.text)
                                Text("\(l10n.t("passport.trainsCount", count: row.count)) · \(Format.distance(row.distanceM, unit: unit, language: app.settings.language))")
                                    .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                showAll(tab, total: data.trainTypes.count)
                Text(l10n.t("passport.typesNote")).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }

    private var stations: some View {
        VStack(alignment: .leading, spacing: 12) {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(showAllStations || stationLimit == nil ? data.stations : Array(data.stations.prefix(stationLimit ?? 0))) { station in
                    NavigationLink(value: AppRoute.board(stationId: station.id, arrivals: false)) {
                        HStack(spacing: 8) {
                            Text(station.name).foregroundStyle(Ink.text)
                            Text("×\(station.count)").clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        }
                        .clack(.stopName)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                        .hairlineBorder(radius: Radius.controlSm)
                    }
                    .buttonStyle(.plain)
                }
            }
            if let stationLimit, data.stations.count > stationLimit {
                Button(showAllStations ? l10n.t("passport.showFewer") : l10n.t("passport.showAllStations", count: data.stations.count)) { showAllStations.toggle() }
                    .buttonStyle(LinkButtonStyle())
            }
            Text(l10n.t("passport.stationsNote")).clack(.caption).foregroundStyle(Ink.text2)
        }
    }

    /// The first rows of a long list, all of them once "Show all" is tapped (or when there is no limit).
    private func limited<Row>(_ rows: [Row], _ tab: PassportLogic.CollectionTab) -> [Row] {
        guard let limit, !showAllRows else { return rows }
        return Array(rows.prefix(limit))
    }

    @ViewBuilder
    private func showAll(_ tab: PassportLogic.CollectionTab, total: Int) -> some View {
        if let limit, total > limit {
            Button(showAllRows ? l10n.t("passport.showFewer") : l10n.t("passport.showAllStations", count: total)) { showAllRows.toggle() }
                .buttonStyle(LinkButtonStyle())
        }
    }

    private func countryName(_ code: String) -> String {
        let key = "countries.\(code)"
        let name = l10n.t(key)
        return name == key ? code : name
    }
}
