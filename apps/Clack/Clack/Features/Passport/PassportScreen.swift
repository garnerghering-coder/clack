//
//  PassportScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Passport (DESIGN §8, product brief §9): everything you've ridden, by year; commuter trains per the setting.
/// Collection first (the summary and your map, milestones, collections and records), then the detailed statistics
/// (the trips themselves are on Trips). Every number comes from trips recorded as travelled (PassportPage.tsx).
struct PassportScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @State private var year: Int?
    @State private var comparison: Co2Comparison?
    @State private var data: Passport?
    @State private var failed = false
    @State private var flavorIndex = 0
    @State private var showAllStations = false
    @State private var sharing = false

    init() {
        #if DEBUG
        // `-share` opens the share sheet straight away, to check the cards.
        _sharing = State(initialValue: CommandLine.arguments.contains("-share"))
        #endif
    }

    private var settings: Settings { app.settings }
    /// Old settings may hold a comparison no longer offered; it shows as a petrol car.
    private var activeComparison: Co2Comparison { comparison ?? (Settings.co2Choices.contains(settings.co2Comparison) ? settings.co2Comparison : .car1) }

    var body: some View {
        Page {
            PageHeader(title: l10n.t("passport.title")) {
                HStack(spacing: 8) {
                    if let data, data.totals.trains > 0 {
                        IconButton(icon: "share-2", label: l10n.t("share.title")) { sharing = true }
                    }
                    SettingsLink()
                }
            }
            if failed {
                Banner(kind: .error) { Text(l10n.t("passport.loadError")) }
            } else if let data {
                content(data)
            } else {
                Skeleton(height: 120)
            }
        }
        .refreshable { await load() }
        .task(id: "\(year.map(String.init) ?? "all")|\(settings.includeCommuter)|\(activeComparison.rawValue)") { await load() }
        .sheet(isPresented: $sharing) {
            if let data { ShareSheet(passport: data, year: year, commuter: settings.includeCommuter) { sharing = false } }
        }
    }

    private func load() async {
        do {
            data = try await app.client.passport(year: year, commuter: settings.includeCommuter, comparison: activeComparison)
            failed = false
        } catch {
            if data == nil { failed = true }
        }
    }

    // MARK: content

    @ViewBuilder
    private func content(_ data: Passport) -> some View {
        Section {
            if !data.review.isEmpty {
                Button {
                    router.tripsTab = .past
                    router.tab = .trips
                } label: {
                    Banner { Text(l10n.t("passport.reviewBanner", count: data.review.count)).fontWeight(.semibold) }
                }
                .buttonStyle(.plain)
            }
            if data.totals.trains == 0 {
                VStack(spacing: 12) {
                    Text(l10n.t("passport.emptyTitle")).clack(.headline).foregroundStyle(Ink.text)
                    Text(l10n.t("passport.emptyHow")).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
                    VStack(spacing: 10) {
                        Button(l10n.t("trips.findTrain")) { router.openAdd() }.buttonStyle(.clack(.primary, wide: true))
                        Button(l10n.t("trips.exploreTrains")) { router.tab = .explore }.buttonStyle(.clack(wide: true))
                    }
                    .frame(maxWidth: 320)
                }
                .frame(maxWidth: .infinity).padding(.top, 48)
            } else {
                full(data)
            }
        } header: {
            // The year chips stay at the top while you scroll (`.passport-controls`).
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ChipButton(text: l10n.t("passport.allTime"), active: year == nil) { year = nil }
                    ForEach(data.years, id: \.self) { y in ChipButton(text: String(y), active: year == y) { year = y } }
                }
                .padding(.horizontal, 16)
            }
            .padding(.horizontal, -16).padding(.vertical, 8)
            .background(Ink.bg)
        }
    }

    @ViewBuilder
    private func full(_ data: Passport) -> some View {
        let unit = settings.distanceUnit
        let ops = data.refs.operators
        VStack(alignment: .leading, spacing: 16) {
            PassportCard(data: data, year: year, flavorIndex: $flavorIndex)
            MultiRouteMapView(
                routes: data.map.map { m in
                    MultiRoute(
                        color: MapStyle.opColor(m.operatorId.flatMap { ops[$0]?.brandColor }, dark: app.colorScheme != .light),
                        geometry: m.geometry, stops: m.stops.compactMap { $0.count == 2 ? LatLon($0[0], $0[1]) : nil }
                    )
                },
                stations: data.stations.map { MultiStation(lat: $0.lat, lon: $0.lon, name: $0.name, count: $0.count) },
                railNetwork: settings.showRailNetwork, label: l10n.t("passport.mapLabel", count: data.totals.trains)
            )
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)

            MilestonesCard(data: data)

            groupTitle(l10n.t("passport.collections"))
            Card {
                Text(l10n.t("passport.operators")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Bars(rows: data.operators, unit: unit, label: { ops[$0.key]?.name ?? $0.key }, brand: { ops[$0.key]?.brandColor ?? "" }, lead: { OperatorBadge(op: ops[$0.key], size: .medium) })
            }
            if !data.trainTypes.isEmpty {
                Card {
                    Text(l10n.t("passport.trainTypes")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    VStack(spacing: 12) {
                        ForEach(data.trainTypes, id: \.key) { row in
                            let type = data.refs.trainTypes[row.key]
                            HStack(spacing: 12) {
                                TrainPicture(type: type, operatorId: nil, height: 36).frame(width: 120, alignment: .leading).clipped()
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(type?.name ?? row.key).clack(.rowTitle).foregroundStyle(Ink.text)
                                    Text("\(l10n.t("passport.trainsCount", count: row.count)) · \(Format.distance(row.distanceM, unit: unit, language: settings.language))")
                                        .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    Text(l10n.t("passport.typesNote")).clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            Card {
                Text(l10n.t("passport.countries")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                VStack(spacing: 12) {
                    ForEach(data.countries, id: \.code) { country in
                        HStack(spacing: 12) {
                            Flag(country: country.code, size: 24, decorative: true)
                            Text(countryName(country.code)).clack(.rowTitle).foregroundStyle(Ink.text)
                            Spacer(minLength: 0)
                            Text(l10n.t("passport.trainsCount", count: country.legs)).clack(.caption).foregroundStyle(Ink.text2)
                        }
                    }
                }
                Text(l10n.t("passport.borders", count: data.totals.borderCrossings)).clack(.caption).foregroundStyle(Ink.text2)
            }
            Card {
                Text(l10n.t("passport.stationsVisited")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                FlowLayout(spacing: 8, lineSpacing: 8) {
                    ForEach(showAllStations ? data.stations : Array(data.stations.prefix(12))) { station in
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
                if data.stations.count > 12 {
                    Button(showAllStations ? l10n.t("passport.showFewer") : l10n.t("passport.showAllStations", count: data.stations.count)) { showAllStations.toggle() }
                        .buttonStyle(LinkButtonStyle())
                }
                Text(l10n.t("passport.stationsNote")).clack(.caption).foregroundStyle(Ink.text2)
            }
            Card {
                Text(l10n.t("passport.products")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Bars(rows: data.products, unit: unit, label: { l10n.t("products.\($0.key)") }, brand: { _ in nil }, lead: { _ in EmptyView() })
            }

            groupTitle(l10n.t("passport.records"))
            Card {
                records(data)
            }

            groupTitle(l10n.t("passport.moreStats"))
            delaysCard(data)
            co2Card(data)
        }
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2).padding(.top, 24).padding(.bottom, -10)
    }

    private func countryName(_ code: String) -> String {
        let key = "countries.\(code)"
        let name = l10n.t(key)
        return name == key ? code : name
    }

    // MARK: records and statistics

    private func records(_ data: Passport) -> some View {
        let r = data.records
        let unit = settings.distanceUnit
        let lang = settings.language
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12) {
            if let leg = r.longestDistance {
                RecordTile(label: l10n.t("passport.longestTrip"), value: Format.distance(leg.distanceM, unit: unit, language: lang), sub: "\(leg.from) → \(leg.to)", legId: leg.legId)
            }
            if let leg = r.longestDuration {
                RecordTile(label: l10n.t("passport.longestTime"), value: Format.duration(leg.minutes), sub: "\(leg.from) → \(leg.to)", legId: leg.legId)
            }
            if let leg = r.biggestDelay {
                RecordTile(label: l10n.t("passport.biggestDelay"), value: l10n.t("passport.minutesLate", count: leg.delayMin ?? 0), sub: "\(leg.from) → \(leg.to)", legId: leg.legId)
            }
            if let route = r.mostRiddenRoute {
                RecordTile(label: l10n.t("passport.mostRidden"), value: route.route, sub: l10n.t("passport.timesCount", count: route.count), legId: nil)
            }
            if let station = r.busiestStation {
                RecordTile(label: l10n.t("passport.busiestStation"), value: station.name, sub: l10n.t("passport.visitsCount", count: station.count), legId: nil)
            }
            if let leg = r.earliestDeparture {
                RecordTile(label: l10n.t("passport.earliest"), value: Format.time(leg.dep.ms, tz: Format.zone(leg.depTz), clock: settings.clock), sub: leg.from, legId: leg.legId)
            }
            if let leg = r.latestArrival {
                RecordTile(label: l10n.t("passport.latest"), value: Format.time(leg.arr.ms, tz: Format.zone(leg.arrTz), clock: settings.clock), sub: leg.to, legId: leg.legId)
            }
        }
    }

    private func delaysCard(_ data: Passport) -> some View {
        let d = data.delays
        let bands: [(key: String, count: Int, band: DelayBand)] = [
            ("on_time", d.bands.onTime, .onTime), ("slight", d.bands.slight, .slight), ("late", d.bands.late, .late), ("very_late", d.bands.veryLate, .veryLate),
        ]
        let total = bands.reduce(0) { $0 + $1.count }
        return Card {
            Text(l10n.t("passport.delays")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            if d.basedOn == 0 {
                Text(l10n.t("passport.noDelayData")).clack(.caption).foregroundStyle(Ink.text2)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(Int((d.onTimePct ?? 0).rounded()))%").clack(.passportBig).monospacedDigit().foregroundStyle(Ink.text)
                    Text(l10n.t("passport.onTime")).clack(.caption).foregroundStyle(Ink.text2)
                }
                SegmentedBar(segments: bands.map { .init(id: $0.key, count: $0.count, color: $0.band.fill) })
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bands, id: \.key) { band in
                        HStack(spacing: 4) {
                            Circle().fill(band.band.fill).frame(width: 8, height: 8)
                            Text("\(l10n.t("passport.bands.\(band.key)")) · \(band.count) (\(total > 0 ? Int((100 * Double(band.count) / Double(total)).rounded()) : 0)%)")
                        }
                        .clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], spacing: 12) {
                    RecordTile(label: l10n.t("passport.timeLost"), value: Format.duration(d.totalLateMin), sub: nil, legId: nil)
                    RecordTile(label: l10n.t("passport.averageDelay"), value: l10n.t("passport.minutesShort", ["n": d.averageMin.map { String(format: "%g", $0) } ?? "—"]), sub: nil, legId: nil)
                    if let worst = d.worst {
                        RecordTile(label: l10n.t("passport.worstDelay"), value: l10n.t("passport.minutesLate", count: worst.delayMin ?? 0), sub: "\(worst.from) → \(worst.to)", legId: worst.legId)
                    }
                    RecordTile(label: l10n.t("passport.cancellations"), value: String(d.cancellations), sub: nil, legId: nil)
                }
                Text(l10n.t("passport.basedOn", count: d.basedOn)).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }

    private func co2Card(_ data: Passport) -> some View {
        let c = data.co2
        let lang = settings.language
        let formatter = NumberFormatter()
        formatter.locale = Format.locale(lang)
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        func grouped(_ v: Double) -> String { formatter.string(from: NSNumber(value: v.rounded())) ?? String(Int(v.rounded())) }
        let mode = l10n.t("passport.co2Modes.\(c.comparison)")
        return Card {
            Text(l10n.t("passport.co2")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            (Text(grouped(c.savedKg)) + Text(" kg").font(TextRole.bigUnit.font).foregroundStyle(Ink.text2)).clack(.passportBig).monospacedDigit().foregroundStyle(Ink.text)
            Text(l10n.t("passport.co2Saved", ["mode": mode])).clack(.caption).foregroundStyle(Ink.text2)
            // Flying or a petrol car (owner feedback 2026-10-21).
            SegmentedControl(
                selection: Binding(get: { activeComparison }, set: { comparison = $0 }),
                options: Settings.co2Choices.map { ($0, $0 == .flight ? l10n.t("passport.co2Flying") : l10n.t("passport.co2Car")) }, small: true
            )
            (Text(l10n.t("passport.co2Detail", ["train": c.trainKg < 10 ? String(format: "%.1f", c.trainKg) : String(Int(c.trainKg.rounded())), "other": grouped(c.comparisonKg), "mode": mode]) + " ")
                + Text(.init("[\(l10n.t("passport.howWeCalculate"))](clack://about)")))
                .clack(.caption).foregroundStyle(Ink.text2).tint(Ink.accentInk)
                .environment(\.openURL, OpenURLAction { _ in
                    router.setPath([.about], for: .passport)
                    return .handled
                })
        }
    }
}

// MARK: pieces

private struct RecordTile: View {
    @Environment(L10n.self) private var l10n
    let label: String
    let value: String
    let sub: String?
    let legId: String?

    var body: some View {
        let body = Tile(label: label, value: value, sub: sub)
        if let legId { NavigationLink(value: AppRoute.trip(legId)) { body }.buttonStyle(.plain) } else { body }
    }
}

/// Horizontal bars: a label with its count and distance, and a track filled in proportion to the largest row.
private struct Bars<Lead: View>: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let rows: [Passport.CountRow]
    let unit: DistanceUnit
    let label: (Passport.CountRow) -> String
    /// The operator's brand colour (hex) for the bar; the accent when nil.
    let brand: (Passport.CountRow) -> String?
    @ViewBuilder var lead: (Passport.CountRow) -> Lead

    var body: some View {
        let most = max(1, rows.map(\.count).max() ?? 1)
        VStack(spacing: 12) {
            ForEach(rows, id: \.key) { row in
                HStack(spacing: 12) {
                    lead(row)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(label(row)).clack(.rowTitle).foregroundStyle(Ink.text)
                            Spacer(minLength: 0)
                            Text("\(l10n.t("passport.trainsCount", count: row.count)) · \(Format.distance(row.distanceM, unit: unit, language: app.settings.language))")
                                .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        }
                        ProgressBar(value: Double(row.count) / Double(most), color: brand(row).map { operatorColor($0, scheme: scheme) } ?? Ink.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }
}

/// Milestones: achieved medals (the newest six, or all), and the next ones to go for, greyed with a ring showing how far
/// along you are.
private struct MilestonesCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: Passport
    @State private var all = false
    @State private var shown = false
    /// Room for a two-line title under every medal (two caption lines, 18 pt each), so a medal whose title wraps sits
    /// at the same height as its neighbours (owner, 2026-10-24).
    @ScaledMetric(relativeTo: .footnote) private var titleHeight: CGFloat = 36

    var body: some View {
        let achieved = data.milestones.achieved
        let next = data.milestones.next
        // Top-aligned cells: the medals line up along each row whatever the length of the titles under them.
        let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 3)
        Card {
            Text(l10n.t("passport.milestones")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            if !achieved.isEmpty {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(achieved.prefix(all ? achieved.count : 6).enumerated()), id: \.offset) { index, milestone in
                        let label = l10n.milestoneLabel(milestone, language: app.settings.language)
                        let tile = VStack(spacing: 2) {
                            Medal(m: milestone)
                            title(label)
                            Text(milestone.at.map { Format.month($0.ms, tz: "Europe/Stockholm", language: app.settings.language) } ?? "").clack(.caption).foregroundStyle(Ink.text2)
                        }
                        .scaleEffect(shown || reduceMotion ? 1 : 0.6).opacity(shown || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .timingCurve(0.2, 1.4, 0.4, 1, duration: 0.45).delay(Double(index) * 0.06), value: shown)
                        if let legId = milestone.legId { NavigationLink(value: AppRoute.trip(legId)) { tile }.buttonStyle(.plain).accessibilityLabel(label) } else { tile }
                    }
                }
            }
            if achieved.count > 6 {
                Button(all ? l10n.t("passport.showFewer") : l10n.t("passport.showAllMilestones", count: achieved.count)) { all.toggle() }.buttonStyle(LinkButtonStyle())
            }
            if !next.isEmpty {
                Text(l10n.t("passport.nextMilestones")).clack(.captionUpper).foregroundStyle(Ink.text2)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(next.enumerated()), id: \.offset) { _, milestone in
                        let value = Int((milestone.value ?? 0).rounded(.down))
                        let formatter = NumberFormatter()
                        VStack(spacing: 2) {
                            Medal(m: milestone, locked: true)
                            title(l10n.milestoneLabel(milestone, language: app.settings.language))
                            Text(l10n.t("passport.progressOf", ["value": String(value), "target": String(Int(milestone.target))])).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(l10n.milestoneLabel(milestone, language: app.settings.language)): \(l10n.t("passport.progressOf", ["value": String(value), "target": String(Int(milestone.target))]))")
                        let _ = formatter
                    }
                }
            }
            Text(l10n.t("passport.milestonesNote")).clack(.caption).foregroundStyle(Ink.text2)
        }
        .onAppear { shown = true }
    }

    /// A medal's title: top-aligned in a box two lines tall, so the line under it starts at the same height too.
    private func title(_ text: String) -> some View {
        Text(text).clack(.caption).fontWeight(.bold).foregroundStyle(Ink.text).multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .top)
    }
}
