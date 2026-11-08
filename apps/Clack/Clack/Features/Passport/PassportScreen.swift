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
    @Environment(PassportStore.self) private var store
    @State private var year: Int?
    @State private var mapOpen = false
    @State private var data: Passport?
    @State private var failed = false
    @State private var flavorIndex = 0
    @State private var sharing = false

    init() {
        #if DEBUG
        // `-share` opens the share sheet straight away, to check the cards; `-passportMap` the full-screen map.
        _sharing = State(initialValue: CommandLine.arguments.contains("-share"))
        _mapOpen = State(initialValue: CommandLine.arguments.contains("-passportMap"))
        #endif
    }

    private var settings: Settings { app.settings }
    /// Old settings may hold a comparison no longer offered; it shows as a petrol car.
    private var activeComparison: Co2Comparison { Settings.co2Choices.contains(settings.co2Comparison) ? settings.co2Comparison : .car1 }

    var body: some View {
        Page {
            PageHeader(title: l10n.t("passport.title")) {
                HStack(spacing: 8) {
                    if let data, data.totals.trains > 0 {
                        IconButton(icon: "system:square.and.arrow.up", label: l10n.t("share.title")) { sharing = true; Usage.shared.count(.feature, "passport.share") }
                    }
                    SettingsLink()
                }
            }
            if failed {
                Banner(kind: .error) { Text(l10n.t("passport.loadError")) }.countsError("passport.load")
            } else if let data {
                content(data)
            } else {
                Skeleton(height: 120)
            }
        }
        .refreshable { await load() }
        .toolbar(.hidden, for: .navigationBar)
        .task(id: "\(year.map(String.init) ?? "all")|\(settings.includeCommuter)|\(activeComparison.rawValue)") { await load() }
        .sheet(isPresented: $sharing) {
            if let data { ShareSheet(passport: data, year: year, commuter: settings.includeCommuter) { sharing = false } }
        }
    }

    private func load() async {
        do {
            data = try await app.client.passport(year: year, commuter: settings.includeCommuter, comparison: activeComparison)
            store.data = data
            store.year = year
            failed = false
        } catch {
            if data == nil { failed = true }
        }
    }

    // MARK: content

    @ViewBuilder
    private func content(_ data: Passport) -> some View {
        // The year chips scroll away with the page (owner, 2026-10-25: no bar following you down).
        YearChips(years: data.years, year: $year).padding(.horizontal, -16)
        Group {
            if !data.review.isEmpty {
                Button {
                    // The Past list itself, not whatever trip was left open on the Trips tab (user test 2026-11-07).
                    router.tripsPath = []
                    router.tripsTab = .past
                    router.tab = .trips
                } label: {
                    Banner { Text(l10n.t("passport.reviewBanner", count: data.review.count)).fontWeight(.semibold) }
                }
                .buttonStyle(.plain)
            }
            if PassportLogic.stage(journeys: data.totals.journeys) == .empty {
                welcoming(data)
            } else {
                full(data)
            }
        }
    }

    /// Nothing yet: say what is waiting rather than that it is empty, with the first medals to go for.
    private func welcoming(_ data: Passport) -> some View {
        VStack(spacing: 16) {
            Text(l10n.t("passport.emptyTitle")).clack(.headline).foregroundStyle(Ink.text)
            // The nearest medal is the hero, with its track and a first hair of yellow; the other two sit smaller
            // (designer, 2026-11-07: three grey medals read as locked content, not a starting line).
            if let hero = data.milestones.next.first {
                goal(hero, data, size: 112, titleRole: .rowTitle)
                let others = Array(data.milestones.next.dropFirst().prefix(2))
                if !others.isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        ForEach(Array(others.enumerated()), id: \.offset) { _, milestone in goal(milestone, data, size: 72, titleRole: .caption) }
                    }
                }
            }
            Text(l10n.t("passport.emptyHow")).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
            VStack(spacing: 12) {
                Button(l10n.t("trips.findTrain")) { router.openAdd() }.buttonStyle(.clack(.primary, wide: true))
                Button(l10n.t("trips.exploreTrains")) { router.tab = .explore }.buttonStyle(.clack(wide: true))
            }
            .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity).padding(.top, 32)
    }

    /// A medal still to earn, with its name and how far along it is.
    private func goal(_ milestone: Milestone, _ data: Passport, size: CGFloat, titleRole: TextRole) -> some View {
        let label = l10n.milestoneLabel(milestone, language: settings.language, home: data.home)
        let progress = l10n.t("passport.progressOf", ["value": String(Int((milestone.value ?? 0).rounded())), "target": String(Int(milestone.target))])
        return VStack(spacing: 4) {
            Medal(m: milestone, locked: true, size: size)
            Text(label).clack(titleRole).fontWeight(.bold).foregroundStyle(Ink.text).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Text(progress).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(progress)")
    }

    /// While there are only a few journeys: the nearest medal and how far there is to go.
    @ViewBuilder
    private func upNext(_ data: Passport) -> some View {
        if let next = data.milestones.next.first {
            let value = next.value ?? 0
            let label = l10n.milestoneLabel(next, language: settings.language, home: data.home)
            let left = l10n.t("passport.toGo", count: PassportLogic.toGo(next))
            Card {
                Text(l10n.t("passport.upNext")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                HStack(spacing: 16) {
                    Medal(m: next, locked: true, size: 64)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(label).clack(.rowTitle).foregroundStyle(Ink.text)
                        ProgressBar(value: min(1, value / next.target), color: Ink.accent).accessibilityHidden(true)
                        Text(left).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(label): \(left)")
            }
        }
    }

    /// The page as a few cards (owner, 2026-11-07, Flighty's way): the cover opens the breakdown, the map opens full
    /// screen, the milestones open every level; delays and CO₂ stay as they are. Collections and records live in the
    /// breakdown.
    @ViewBuilder
    private func full(_ data: Passport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NavigationLink(value: AppRoute.passportBreakdown) {
                PassportCard(data: data, year: year, flavorIndex: $flavorIndex)
            }
            .buttonStyle(.plain)
            .accessibilityHint(l10n.t("passport.breakdownHint"))
            if PassportLogic.stage(journeys: data.totals.journeys) == .starting { upNext(data) }
            Button { mapOpen = true } label: {
                MultiRouteMapView(
                    routes: PassportMap.routes(data, dark: app.colorScheme != .light), stations: PassportMap.stations(data),
                    railNetwork: settings.showRailNetwork, label: l10n.t("passport.mapLabel", count: data.totals.trains), heat: true
                )
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .hairlineBorder(radius: Radius.card)
                .overlay(alignment: .topTrailing) {
                    MapButtonFace(icon: "maximize-2").padding(8).allowsHitTesting(false)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(l10n.t("passport.mapLabel", count: data.totals.trains))
            .accessibilityHint(l10n.t("passport.mapOpenHint"))

            MilestonesCard(data: data)

            groupTitle(l10n.t("passport.moreStats"))
            delaysCard(data)
            co2Card(data)
        }
        .fullScreenCover(isPresented: $mapOpen) {
            PassportMapScreen(year: $year)
                .environment(app).environment(app.l10n).environment(store)
                .preferredColorScheme(app.colorScheme)
        }
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2).padding(.top, 24).padding(.bottom, -10)
    }

    // MARK: records and statistics

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
                    // Only when something was late: an early or on-time "worst" is no record (user test 2026-11-07:
                    // "Worst delay: −1 min late").
                    if let worst = d.worst, let delay = worst.delayMin, delay > 0 {
                        RecordTile(label: l10n.t("passport.worstDelay"), value: l10n.t("passport.minutesLate", count: delay), sub: "\(worst.from) → \(worst.to)", legId: worst.legId)
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
            // Flying or a petrol car (owner feedback 2026-10-21); the same setting as in Settings, saved (2026-11-07).
            SegmentedControl(
                selection: Binding(get: { activeComparison }, set: { value in Task { await app.update(SettingsPatch(co2Comparison: value)) } }),
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

/// Horizontal bars: a label with its count and distance, and a track filled in proportion to the largest row.
struct Bars<Lead: View>: View {
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

/// Milestones: the newest six medals and the next ones to go for, greyed with a ring showing how far along you are;
/// every level, earned and not, is on its own screen (owner, 2026-11-07).
private struct MilestonesCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: Passport
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
                    ForEach(Array(achieved.prefix(6).enumerated()), id: \.offset) { index, milestone in
                        let label = l10n.milestoneLabel(milestone, language: app.settings.language, home: data.home)
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
            let total = PassportLogic.ladder(data.milestones).reduce(0) { $0 + $1.rungs.count }
            NavigationLink(value: AppRoute.passportMilestones) {
                Text("\(l10n.t("passport.allMilestones")) · \(l10n.t("passport.earnedOf", ["earned": String(achieved.count), "total": String(total)]))")
            }
            .buttonStyle(LinkButtonStyle())
            if !next.isEmpty {
                Text(l10n.t("passport.nextMilestones")).clack(.captionUpper).foregroundStyle(Ink.text2)
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(next.enumerated()), id: \.offset) { _, milestone in
                        // Rounded as the card's km are (user test 2026-11-07: "345 km" on the card, "344 of 500" here).
                        let value = Int((milestone.value ?? 0).rounded())
                        let formatter = NumberFormatter()
                        VStack(spacing: 2) {
                            Medal(m: milestone, locked: true)
                            title(l10n.milestoneLabel(milestone, language: app.settings.language, home: data.home))
                            Text(l10n.t("passport.progressOf", ["value": String(value), "target": String(Int(milestone.target))])).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(l10n.milestoneLabel(milestone, language: app.settings.language, home: data.home)): \(l10n.t("passport.progressOf", ["value": String(value), "target": String(Int(milestone.target))]))")
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
