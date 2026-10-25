//
//  CollectionsCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Operators, countries, stations, kinds of train and train types in one card: chips name the collections, and the
/// system's paging scroll (or a tap on a chip) moves between them (owner, 2026-10-25). The chips are what VoiceOver uses.
struct CollectionsCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: Passport
    /// The page the scroll view is on; it is also what the chips follow and what they scroll to.
    @State private var scrolled: PassportLogic.CollectionTab?
    /// How tall each page is, so the card is as tall as the page showing and not as the tallest.
    @State private var heights = [PassportLogic.CollectionTab: CGFloat]()
    @State private var showAllStations = false
    @State private var showAllRows = Set<PassportLogic.CollectionTab>()

    private static let rowLimit = 6
    private static let stationLimit = 12

    init(data: Passport) {
        self.data = data
        #if DEBUG
        // `-passportTab <name>` opens a collection, for screenshots.
        let args = CommandLine.arguments
        if let at = args.firstIndex(of: "-passportTab"), args.indices.contains(at + 1), let tab = PassportLogic.CollectionTab(rawValue: args[at + 1]) {
            _scrolled = State(initialValue: tab)
        }
        #endif
    }

    private var tabs: [PassportLogic.TabCount] {
        PassportLogic.collectionTabs(
            operators: data.operators.count, countries: data.countries.count, stations: data.stations.count,
            kinds: data.products.count, trainTypes: data.trainTypes.count
        )
    }

    /// The page showing, or the first one when it has gone (another year has none of it).
    private var selected: PassportLogic.CollectionTab? {
        let shown = tabs.map(\.tab)
        return scrolled.flatMap { shown.contains($0) ? $0 : nil } ?? shown.first
    }

    var body: some View {
        let tabs = tabs
        Card {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tabs, id: \.tab) { entry in
                        ChipButton(text: "\(name(entry.tab)) \(entry.count)", active: entry.tab == selected) { select(entry.tab) }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16)
            // The collections sit side by side in a paging scroll view: the system's own swipe, momentum and bounce.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(tabs, id: \.tab) { entry in
                        content(entry.tab)
                            .containerRelativeFrame(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[entry.tab] = $0 }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .id(entry.tab)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrolled)
            .frame(height: selected.flatMap { heights[$0] }, alignment: .top)
            .animation(reduceMotion ? nil : .snappy, value: selected)
            .onChange(of: tabs.map(\.tab)) { _, shown in
                if let scrolled, !shown.contains(scrolled) { self.scrolled = shown.first }
            }
        }
    }

    // MARK: moving between collections

    private func select(_ tab: PassportLogic.CollectionTab) {
        withAnimation(reduceMotion ? nil : .snappy) { scrolled = tab }
    }

    private func name(_ tab: PassportLogic.CollectionTab) -> String {
        switch tab {
        case .operators: l10n.t("passport.operators")
        case .countries: l10n.t("passport.countries")
        case .stations: l10n.t("passport.stationsVisited")
        case .kinds: l10n.t("passport.tab.kinds")
        case .trainTypes: l10n.t("passport.trainTypes")
        }
    }

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
                ForEach(showAllStations ? data.stations : Array(data.stations.prefix(Self.stationLimit))) { station in
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
            if data.stations.count > Self.stationLimit {
                Button(showAllStations ? l10n.t("passport.showFewer") : l10n.t("passport.showAllStations", count: data.stations.count)) { showAllStations.toggle() }
                    .buttonStyle(LinkButtonStyle())
            }
            Text(l10n.t("passport.stationsNote")).clack(.caption).foregroundStyle(Ink.text2)
        }
    }

    /// The first rows of a long list, all of them once "Show all" is tapped.
    private func limited<Row>(_ rows: [Row], _ tab: PassportLogic.CollectionTab) -> [Row] {
        showAllRows.contains(tab) ? rows : Array(rows.prefix(Self.rowLimit))
    }

    @ViewBuilder
    private func showAll(_ tab: PassportLogic.CollectionTab, total: Int) -> some View {
        if total > Self.rowLimit {
            let open = showAllRows.contains(tab)
            Button(open ? l10n.t("passport.showFewer") : l10n.t("passport.showAllStations", count: total)) {
                if open { showAllRows.remove(tab) } else { showAllRows.insert(tab) }
            }
            .buttonStyle(LinkButtonStyle())
        }
    }

    private func countryName(_ code: String) -> String {
        let key = "countries.\(code)"
        let name = l10n.t(key)
        return name == key ? code : name
    }
}
