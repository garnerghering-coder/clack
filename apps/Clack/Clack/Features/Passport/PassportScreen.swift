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
                        IconActionButton(icon: "share-2", label: l10n.t("share.title")) { sharing = true }
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
                VStack(spacing: 10) {
                    Text(l10n.t("passport.emptyTitle")).clack(.headline).foregroundStyle(Ink.text)
                    Text(l10n.t("passport.emptyHow")).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Button(l10n.t("trips.findTrain")) { router.openAdd() }.buttonStyle(.clack(.primary))
                        Button(l10n.t("trips.exploreTrains")) { router.tab = .explore }.buttonStyle(.clack())
                    }
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
                Bars(rows: data.operators, unit: unit, label: { ops[$0.key]?.name ?? $0.key }, color: { MapStyle.opColor(ops[$0.key]?.brandColor, dark: true) }, lead: { OperatorBadge(op: ops[$0.key], size: .medium) })
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
                        HStack(spacing: 10) {
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
                FlowLayout(spacing: 6, lineSpacing: 6) {
                    ForEach(showAllStations ? data.stations : Array(data.stations.prefix(12))) { station in
                        NavigationLink(value: AppRoute.board(stationId: station.id, arrivals: false)) {
                            HStack(spacing: 6) {
                                Text(station.name).foregroundStyle(Ink.text)
                                Text("×\(station.count)").clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                            }
                            .font(ClackFont.inter(14))
                            .padding(.vertical, 6).padding(.horizontal, 10)
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
                Bars(rows: data.products, unit: unit, label: { l10n.t("products.\($0.key)") }, color: { _ in "accent" }, lead: { _ in EmptyView() })
            }

            groupTitle(l10n.t("passport.records"))
            Card {
                Text(l10n.t("passport.records")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                records(data)
            }

            groupTitle(l10n.t("passport.moreStats"))
            delaysCard(data)
            co2Card(data)
        }
    }

    private func groupTitle(_ title: String) -> some View {
        Text(title).clack(.sectionHeader).foregroundStyle(Ink.text2).padding(.top, 22).padding(.bottom, -10)
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
        let tz = "Europe/Stockholm"
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)], spacing: 10) {
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
                RecordTile(label: l10n.t("passport.earliest"), value: Format.time(leg.dep.ms, tz: tz, clock: settings.clock), sub: leg.from, legId: leg.legId)
            }
            if let leg = r.latestArrival {
                RecordTile(label: l10n.t("passport.latest"), value: Format.time(leg.arr.ms, tz: tz, clock: settings.clock), sub: leg.to, legId: leg.legId)
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
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(Int((d.onTimePct ?? 0).rounded()))%").clack(.passportBig).monospacedDigit().foregroundStyle(Ink.text)
                    Text(l10n.t("passport.onTime")).clack(.caption).foregroundStyle(Ink.text2)
                }
                HStack(spacing: 2) {
                    ForEach(bands.filter { $0.count > 0 }, id: \.key) { band in
                        Rectangle().fill(band.band.fill).frame(minWidth: 6).layoutPriority(Double(band.count))
                            .frame(maxWidth: .infinity)
                            .frame(width: nil)
                            .containerRelativeFrame(.horizontal) { width, _ in max(6, width * Double(band.count) / Double(max(total, 1))) }
                    }
                }
                .frame(height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(bands, id: \.key) { band in
                        HStack(spacing: 4) {
                            Circle().fill(band.band.fill).frame(width: 8, height: 8)
                            Text("\(l10n.t("passport.bands.\(band.key)")) · \(band.count) (\(total > 0 ? Int((100 * Double(band.count) / Double(total)).rounded()) : 0)%)")
                        }
                        .clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10, alignment: .top)], spacing: 10) {
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
            (Text(grouped(c.savedKg)) + Text(" kg").font(ClackFont.grotesk(22)).foregroundColor(Ink.text2)).clack(.passportBig).monospacedDigit().foregroundStyle(Ink.text)
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

/// The Passport's top card: a passport page (gradient, guilloche, sheen) that tilts and catches the light as you move the
/// phone. It has no touch handling, so the page scrolls from anywhere on it.
private struct PassportCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let data: Passport
    let year: Int?
    @Binding var flavorIndex: Int
    @State private var motion = MotionTilt()
    @State private var sheen = false

    var body: some View {
        let t = data.totals
        let unit = app.settings.distanceUnit
        let km = t.distanceM / 1000
        let shown = unit == .mi ? km / 1.609344 : km
        let formatter = NumberFormatter()
        let _ = { formatter.locale = Format.locale(app.settings.language); formatter.numberStyle = .decimal; formatter.maximumFractionDigits = 0 }()
        let flavors = flavorLines
        let ink = Ink.onAccent
        let soft = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255).opacity(0.62)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.t("passport.railPassport")).clack(.captionUpper).foregroundStyle(soft)
                    Text(year.map { l10n.t("passport.yearPassport", ["year": String($0)]) } ?? l10n.t("passport.allTimePassport"))
                        .font(ClackFont.inter(15, .heavy)).tracking(0.3).foregroundStyle(ink)
                }
                Spacer(minLength: 0)
                LucideIcon(name: "train-front", size: 22)
                    .foregroundStyle(Color.black.opacity(0.75))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.55), lineWidth: 2))
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 4).padding(2))
                    .accessibilityHidden(true)
            }
            (Text(formatter.string(from: NSNumber(value: shown.rounded())) ?? "0") + Text(" \(unit.rawValue)").font(ClackFont.grotesk(22)).foregroundColor(soft))
                .clack(.passportDistance).monospacedDigit().foregroundStyle(ink)
            if !flavors.isEmpty {
                Button { flavorIndex += 1 } label: {
                    Text(flavors[flavorIndex % flavors.count]).clack(.rowTitle).foregroundStyle(ink).multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
                .accessibilityHint(l10n.t("passport.nextFact"))
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile(String(t.trains), l10n.t("passport.trains"), soft: soft, ink: ink)
                tile(String(t.journeys), l10n.t("passport.journeys"), soft: soft, ink: ink)
                tile(Format.duration(t.minutes), l10n.t("passport.timeOnTrains"), soft: soft, ink: ink)
                tile(String(t.stations), l10n.t("passport.stations"), soft: soft, ink: ink)
            }
            .padding(.top, 6)
            // A machine-readable-zone look, spelled out from your own totals (decoration; nothing personal).
            Text(mrz(km: km))
                .font(.system(size: 11, design: .monospaced)).tracking(1.3).foregroundStyle(Color.black.opacity(0.45))
.lineLimit(1)
                .padding(.top, 8)
                .overlay(alignment: .top) { Rectangle().stroke(Color.black.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(height: 1) }
                .padding(.top, 4)
                .accessibilityHidden(true)
        }
        .padding(.top, 20).padding(.horizontal, 20).padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { cover }
        .clipShape(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous))
        .shadow(color: Color(hex: "#f8d64a")!.opacity(0.55), radius: 20, y: 14)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : motion.pitch), axis: (x: 1, y: 0, z: 0), perspective: 1 / 3)
        .rotation3DEffect(.degrees(reduceMotion ? 0 : motion.yaw), axis: (x: 0, y: 1, z: 0), perspective: 1 / 3)
        .onAppear { if !reduceMotion { motion.start() } }
        .onDisappear { motion.stop() }
        .onAppear { sheen = true }
    }

    /// A holographic foil: a rainbow that slides across the cover as the phone moves, strongest along the guilloche lines (like foil
    /// stamped into a real passport) with a faint wash over the rest. Still with Reduce Motion.
    private var foil: some View {
        let t = reduceMotion ? 0.5 : motion.shine
        let rainbow = LinearGradient(
            colors: [Color(hex: "#ff4fd8")!, Color(hex: "#7a5cff")!, Color(hex: "#27d3ff")!, Color(hex: "#39e58c")!, Color(hex: "#fff04a")!, Color(hex: "#ff9a3c")!, Color(hex: "#ff4fd8")!],
            startPoint: UnitPoint(x: t - 0.6, y: 0), endPoint: UnitPoint(x: t + 0.6, y: 1)
        )
        return ZStack {
            rainbow.opacity(0.24)
            rainbow.mask(Guilloche()).opacity(0.85)
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Signal yellow deepening to amber, lit from the top left like a passport cover under a lamp, with guilloche lines,
    /// holographic foil and a sheen.
    private var cover: some View {
        ZStack {
            CSSLinearGradient(angle: 155, stops: [
                .init(color: Color(hex: "#ffe169")!, location: 0), .init(color: Color(hex: "#f8d64a")!, location: 0.45), .init(color: Color(hex: "#eab21c")!, location: 1),
            ])
            CSSRadialGradient(rx: 0.9, ry: 0.9, cx: 1, cy: 1, stops: [.init(color: Color(hex: "#d99a00")!, location: 0), .init(color: Color(hex: "#d99a00")!.opacity(0), location: 0.6)])
            CSSRadialGradient(rx: 1.2, ry: 0.8, cx: 0, cy: 0, stops: [.init(color: Color(hex: "#fff3b0")!, location: 0), .init(color: Color(hex: "#fff3b0")!.opacity(0), location: 0.55)])
            Guilloche().opacity(0.16)
            foil
            GeometryReader { proxy in
                LinearGradient(stops: [.init(color: .clear, location: 0.3), .init(color: .white.opacity(0.75), location: 0.45), .init(color: .clear, location: 0.6)], startPoint: .leading, endPoint: .trailing)
                    .frame(width: proxy.size.width * 2.5)
                    .offset(x: sheen || reduceMotion ? -proxy.size.width * 2.5 * 0.45 + proxy.size.width * (reduceMotion ? 0.3 : motion.shine) : proxy.size.width * 0.4)
                    .blendMode(.overlay)
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.6).delay(0.3), value: sheen)
            }
        }
        .overlay(RoundedRectangle(cornerRadius: Radius.sheet, style: .continuous).strokeBorder(Color.white.opacity(0.35), lineWidth: 1).blendMode(.overlay))
    }

    private func tile(_ value: String, _ title: String, soft: Color, ink: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(ClackFont.inter(18, .bold)).monospacedDigit().foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).clack(.captionUpper).foregroundStyle(soft)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.08), in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
    }

    private func mrz(km: Double) -> String {
        let t = data.totals
        let text = "P<CLACK<<\(year.map(String.init) ?? "ALL")<<KM\(Int(km.rounded()))<<J\(t.journeys)<<S\(t.stations)<<C\(t.countries)"
        return String((text + String(repeating: "<", count: 44)).prefix(44))
    }

    /// The facts that rotate under the distance when tapped; ones with nothing worth saying are left out.
    private var flavorLines: [String] {
        let f = data.flavor
        let t = data.totals
        var out: [String] = []
        // Under one lap a share reads better than "0.04×"; tiny distances get no comparison at all.
        if f.earthLaps >= 1 { out.append(l10n.t("passport.flavor.earth", ["n": String(format: "%.1f", f.earthLaps)])) }
        else if f.earthLaps >= 0.01 { out.append(l10n.t("passport.flavor.earthPct", ["pct": String(Int((f.earthLaps * 100).rounded()))])) }
        if f.swedenLengths >= 0.05 { out.append(l10n.t("passport.flavor.sweden", ["n": String(format: "%.1f", f.swedenLengths)])) }
        if t.minutes > 0 { out.append(l10n.t("passport.flavor.time", ["time": Format.duration(t.minutes)])) }
        if let route = f.topRoute { out.append(l10n.t("passport.flavor.route", count: route.count, ["route": route.route])) }
        if let month = f.busiestMonth, let ms = Format.isoToNoonMs("\(month.month)-15") {
            out.append(l10n.t("passport.flavor.month", count: month.count, ["month": Format.month(ms, tz: "UTC", language: app.settings.language)]))
        }
        if f.lateMinutes >= 30 { out.append(l10n.t("passport.flavor.late", ["time": Format.duration(f.lateMinutes)])) }
        return out
    }
}

private extension Double {
    func clamped(_ lower: Double, _ upper: Double) -> Double { Swift.min(Swift.max(self, lower), upper) }
}

/// Fine concentric lines, the security-print pattern on passports and banknotes.
private struct Guilloche: View {
    var body: some View {
        Canvas { context, size in
            let ink = Color(red: 120 / 255, green: 70 / 255, blue: 0)
            func rings(_ cx: Double, _ cy: Double, step: Double, alpha: Double) {
                let maxR = hypot(size.width * 1.8, size.height * 1.8)
                var r = step
                while r < maxR {
                    context.stroke(Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)), with: .color(ink.opacity(alpha)), lineWidth: 1)
                    r += step + 1
                }
            }
            rings(size.width * 0.78, size.height * 0.2, step: 9, alpha: 0.9)
            rings(size.width * 0.1, size.height * 0.95, step: 13, alpha: 0.7)
        }
        .mask(LinearGradient(colors: [.black, .black.opacity(0.35)], startPoint: .top, endPoint: .bottom))
        .allowsHitTesting(false)
    }
}

private struct RecordTile: View {
    @Environment(L10n.self) private var l10n
    let label: String
    let value: String
    let sub: String?
    let legId: String?

    var body: some View {
        let body = VStack(alignment: .leading, spacing: 2) {
            Text(label).clack(.captionUpper).foregroundStyle(Ink.text2)
            Text(value).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
            if let sub { Text(sub).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1) }
        }
        .padding(.vertical, 10).padding(.horizontal, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        if let legId { NavigationLink(value: AppRoute.trip(legId)) { body }.buttonStyle(.plain) } else { body }
    }
}

/// Horizontal bars: a label with its count and distance, and a track filled in proportion to the largest row.
private struct Bars<Lead: View>: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let rows: [Passport.CountRow]
    let unit: DistanceUnit
    let label: (Passport.CountRow) -> String
    /// A hex colour, or "accent".
    let color: (Passport.CountRow) -> String
    @ViewBuilder var lead: (Passport.CountRow) -> Lead

    var body: some View {
        let most = max(1, rows.map(\.count).max() ?? 1)
        VStack(spacing: 12) {
            ForEach(rows, id: \.key) { row in
                HStack(spacing: 12) {
                    lead(row)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(label(row)).clack(.rowTitle).foregroundStyle(Ink.text)
                            Spacer(minLength: 0)
                            Text("\(l10n.t("passport.trainsCount", count: row.count)) · \(Format.distance(row.distanceM, unit: unit, language: app.settings.language))")
                                .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3).fill(Ink.hairline)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(color(row) == "accent" ? Ink.accent : (Color(hex: color(row)) ?? Ink.accent))
                                    .frame(width: proxy.size.width * Double(row.count) / Double(most))
                            }
                        }
                        .frame(height: 6)
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

    var body: some View {
        let achieved = data.milestones.achieved
        let next = data.milestones.next
        let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]
        Card {
            Text(l10n.t("passport.milestones")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            if !achieved.isEmpty {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(achieved.prefix(all ? achieved.count : 6).enumerated()), id: \.offset) { index, milestone in
                        let label = l10n.milestoneLabel(milestone, language: app.settings.language)
                        let tile = VStack(spacing: 2) {
                            Medal(m: milestone)
                            Text(label).clack(.caption).fontWeight(.bold).foregroundStyle(Ink.text).multilineTextAlignment(.center)
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
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(Array(next.enumerated()), id: \.offset) { _, milestone in
                        let value = Int((milestone.value ?? 0).rounded(.down))
                        let formatter = NumberFormatter()
                        VStack(spacing: 2) {
                            Medal(m: milestone, locked: true)
                            Text(l10n.milestoneLabel(milestone, language: app.settings.language)).clack(.caption).fontWeight(.bold).foregroundStyle(Ink.text).multilineTextAlignment(.center)
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
}
