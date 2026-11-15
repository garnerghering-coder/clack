//
//  YearRecap.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// "Your 2025 in rail" (owner, 2026-11-15: "visual, interactive, engaging, make it more"; only for a year that's over):
/// the year as a story on the Passport's yellow. Tap the right half for the next page, the left half for the one
/// before, on every page (a month or the Share button keeps its own tap); hold to pause; each page moves on by itself after a while. Only what your trips say; a page with nothing to say is
/// left out. From the year's own Passport (`GET /passport?year=`, with its months and firsts).
struct YearRecap: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let year: Int
    /// All-time milestones (they are counted over every year); the ones reached in this year are this year's.
    let milestones: Passport.Milestones
    @State private var data: Passport?
    @State private var failed = false
    /// Why it failed (the phone offline, or the server), for the error's cause line.
    @State private var failure: APIError.Kind?
    @State private var sharing = false
    @State private var index = 0
    /// How far the page's own timer has run, 0…1; held, it stops.
    @State private var progress = 0.0
    @State private var holding = false
    /// The page has been shown: its numbers count up and its stamps press in once.
    @State private var shown = false
    /// Which way the last page change went (+1 on, -1 back): the new page comes in from that side.
    @State private var direction = 1
    /// The half just tapped, washed briefly.
    @State private var flash: Side?
    /// A hold just paused the page: the tap that ends it doesn't also turn the page.
    @State private var held = false
    @State private var width: CGFloat = 0

    private enum Side { case left, right }

    /// How long a page stays before moving on by itself.
    private static let pageSeconds = 7.0

    var body: some View {
        ZStack(alignment: .top) {
            Ink.brandYellow.ignoresSafeArea()
            if let data {
                let pages = pages(data)
                let page = pages[min(index, pages.count - 1)]
                ZStack {
                    pressWash
                    accessibilityZones(count: pages.count)
                    pageView(page, data)
                        .id(page)
                        .padding(.horizontal, Space.xl).padding(.top, Space.xxxl + Space.xl).padding(.bottom, Space.xl)
                        // A cross-fade with a few points' nudge from the side it came from (a long slide left a faint
                        // copy of the page behind); the old page only fades.
                        .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(x: CGFloat(direction) * 16)), removal: .opacity))
                }
                .contentShape(Rectangle())
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
                // The halves are behind everything: a tap anywhere that isn't a month or a button pages, left half
                // back, right half on (the controls' own taps win over this one).
                .onTapGesture(coordinateSpace: .local) { point in tap(at: point, count: pages.count) }
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.25)
                        .onEnded { _ in holding = true; held = true }
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onEnded { _ in
                            holding = false
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(300))
                                held = false
                            }
                        }
                )
                segments(count: pages.count)
            } else if failed {
                ErrorStateView(message: l10n.t("recap.failed"), kind: failure ?? app.connectionKind, retry: { await load() }).padding(Space.xl)
            } else {
                ProgressView().tint(Ink.onAccent).frame(maxHeight: .infinity)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                LucideIcon(name: "x", size: 18).foregroundStyle(Ink.onAccent).frame(width: 44, height: 44)
            }
            .buttonStyle(.press(radius: 22))
            .accessibilityLabel(l10n.t("common.close"))
            .padding(.top, Space.l).padding(.trailing, Space.s)
        }
        .task { await load() }
        // The page's timer: a tick a tenth of a second, still while held or while the share sheet is up.
        .task(id: data == nil) {
            guard data != nil else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !holding, !sharing, let data else { continue }
                progress += 0.1 / Self.pageSeconds
                if progress >= 1 {
                    if index < pages(data).count - 1 { go(to: index + 1, count: pages(data).count) } else { progress = 1 }
                }
            }
        }
        .onAppear { shown = true }
        .haptic(.selection, trigger: index)
        .haptic(.snap, trigger: holding, condition: { _, now in now })
        .sheet(isPresented: $sharing) {
            if let data { ShareSheet(passport: data, year: year, commuter: app.settings.includeCommuter) { sharing = false } }
        }
    }

    // MARK: moving between pages

    private func go(to next: Int, count: Int) {
        let target = max(0, min(count - 1, next))
        guard target != index else { progress = 0; return }
        direction = target > index ? 1 : -1
        shown = false
        withMotion(.layout, reduceMotion: reduceMotion) { index = target }
        progress = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            shown = true
        }
    }

    /// A tap's half decides: the left half goes back, the right half goes on. A tap that ends a hold does neither.
    private func tap(at point: CGPoint, count: Int) {
        guard !held else { held = false; return }
        let side: Side = point.x < width / 2 ? .left : .right
        flash = side
        go(to: index + (side == .left ? -1 : 1), count: count)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))
            withMotion(.tap, reduceMotion: reduceMotion) { if flash == side { flash = nil } }
        }
    }

    /// The tapped half, washed in ink for a moment.
    private var pressWash: some View {
        HStack(spacing: 0) {
            Ink.onAccent.opacity(flash == .left ? 0.06 : 0)
            Ink.onAccent.opacity(flash == .right ? 0.06 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Previous and Next for VoiceOver, one half each (taps are handled by the page's own tap, above).
    private func accessibilityZones(count: Int) -> some View {
        HStack(spacing: 0) {
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(l10n.t("recap.previous"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { go(to: index - 1, count: count) }
            Color.clear
                .accessibilityElement()
                .accessibilityLabel(l10n.t("recap.next"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { go(to: index + 1, count: count) }
        }
        .allowsHitTesting(false)
    }

    /// One segment a page, the current one filling.
    private func segments(count: Int) -> some View {
        HStack(spacing: Space.xs) {
            ForEach(0..<count, id: \.self) { i in
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: Radius.bar).fill(Ink.onAccent.opacity(0.2))
                        RoundedRectangle(cornerRadius: Radius.bar).fill(Ink.onAccent)
                            .frame(width: g.size.width * (i < index ? 1 : i == index ? progress : 0))
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, Space.l).padding(.top, Space.s).padding(.trailing, Space.xxxl)
        .accessibilityElement()
        .accessibilityLabel(l10n.t("recap.pageOf", ["n": String(index + 1), "count": String(count)]))
    }

    // MARK: pages

    private enum Page: Hashable { case distance, months, firsts, route, trains, medals, records, share }

    private func pages(_ d: Passport) -> [Page] {
        var out: [Page] = [.distance]
        if (d.months ?? []).contains(where: { $0.trains > 0 }) { out.append(.months) }
        if let f = d.firsts, f.stations > 0 || !f.countries.isEmpty { out.append(.firsts) }
        if d.records.mostRiddenRoute != nil || d.records.busiestStation != nil { out.append(.route) }
        if !trainTypes(d).isEmpty { out.append(.trains) }
        if !earnedThisYear.isEmpty { out.append(.medals) }
        if d.records.longestDistance != nil { out.append(.records) }
        out.append(.share)
        return out
    }

    /// The medals reached in this year.
    private var earnedThisYear: [Milestone] {
        milestones.achieved.filter { m in
            guard let at = m.at?.ms else { return false }
            return Calendar(identifier: .gregorian).component(.year, from: Date(timeIntervalSince1970: at / 1000)) == year
        }
    }

    private func trainTypes(_ d: Passport) -> [(type: TrainType, count: Int, operatorId: String?)] {
        d.trainTypes.compactMap { row in
            app.trainTypes.first { $0.id == row.key }.map { ($0, row.count, nil) }
        }
    }

    @ViewBuilder
    private func pageView(_ page: Page, _ d: Passport) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Text(l10n.t("recap.title", ["year": String(year)])).clack(.captionUpper).foregroundStyle(Ink.onAccent.opacity(0.7))
            switch page {
            case .distance: distance(d)
            case .months: months(d)
            case .firsts: firsts(d)
            case .route: route(d)
            case .trains: trains(d)
            case .medals: medals
            case .records: records(d)
            case .share: share
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: page == .share || page == .months ? .contain : .combine)
    }

    /// The km count up over the year's map.
    private func distance(_ d: Passport) -> some View {
        let km = d.totals.distanceM
        return VStack(alignment: .leading, spacing: Space.l) {
            big(Format.distance(shown ? km : 0, unit: app.settings.distanceUnit, language: app.settings.language))
                .contentTransition(.numericText(value: shown ? km : 0))
                .animation(reduceMotion ? nil : .easeOut(duration: 1.4), value: shown)
            line(l10n.t("recap.distance", ["year": String(year)]))
            line(l10n.t("recap.trains", ["journeys": String(d.totals.journeys), "time": Format.duration(d.totals.minutes, language: l10n.language)]), prefix: String(d.totals.trains))
            MultiRouteMapView(routes: PassportMap.routes(d, dark: false), stations: PassportMap.stations(d), label: l10n.t("passport.mapLabel", count: d.totals.trains), heat: true)
                .frame(maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .opacity(shown ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.3), value: shown)
                .environment(\.colorScheme, .light)
                // A picture here: a tap on it pages like anywhere else.
                .allowsHitTesting(false)
        }
    }

    /// All twelve months as tiles, the picked one (the busiest to start) filled; tap a month for its numbers.
    @State private var pickedMonth: String?

    private func months(_ d: Passport) -> some View {
        let all = RecapMonth.year(year, d.months, language: app.settings.language)
        let busiest = all.max { $0.trains < $1.trains }.flatMap { $0.trains > 0 ? $0 : nil }
        let picked = pickedMonth.flatMap { key in all.first { $0.key == key } } ?? busiest
        return VStack(alignment: .leading, spacing: Space.l) {
            Text(l10n.t("recap.monthsTitle")).clack(.sheetTitle).foregroundStyle(Ink.onAccent)
            if let picked {
                VStack(alignment: .leading, spacing: Space.l) {
                    big(picked.long)
                    line(l10n.t("recap.monthPick", ["month": picked.long, "count": String(picked.trains), "distance": Format.distance(picked.distanceM, unit: app.settings.distanceUnit, language: app.settings.language)]))
                }
                .accessibilityElement(children: .combine)
            }
            RecapMonthGrid(
                months: all, highlighted: picked?.key, grow: shown ? 1 : 0,
                label: { m in l10n.t("recap.monthCell", count: m.trains, ["month": m.long]) },
                onPick: { m in
                    withMotion(.tap, reduceMotion: reduceMotion) { pickedMonth = m.key }
                    progress = 0
                }
            )
            .animation(reduceMotion ? nil : .spring(duration: 0.8, bounce: 0.2), value: shown)
            .haptic(.snap, trigger: pickedMonth, condition: { _, now in now != nil })
            Text(l10n.t("recap.monthHint")).clack(.caption).foregroundStyle(Ink.onAccent.opacity(0.7))
        }
    }

    /// New countries' flags stamp in one by one; how many stations were new.
    private func firsts(_ d: Passport) -> some View {
        let f = d.firsts ?? .init(stations: 0, countries: [])
        return VStack(alignment: .leading, spacing: Space.l) {
            if f.stations > 0 {
                big(String(f.stations))
                line(l10n.t("recap.newStations"))
            }
            if !f.countries.isEmpty {
                Text(l10n.t("recap.firstCountries")).clack(.sheetTitle).foregroundStyle(Ink.onAccent).padding(.top, Space.l)
                HStack(spacing: Space.l) {
                    ForEach(Array(f.countries.enumerated()), id: \.element) { i, code in
                        VStack(spacing: Space.xs) {
                            Flag(country: code, size: 56, decorative: true)
                            Text(l10n.t("countries.\(code)")).clack(.caption).foregroundStyle(Ink.onAccent)
                        }
                        .scaleEffect(shown || reduceMotion ? 1 : 1.6)
                        .opacity(shown || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(duration: 0.45, bounce: 0.35).delay(0.25 + Double(i) * 0.25), value: shown)
                    }
                }
            }
        }
    }

    private func route(_ d: Passport) -> some View {
        VStack(alignment: .leading, spacing: Space.l) {
            if let route = d.records.mostRiddenRoute {
                Text(verbatim: route.route).clack(.pageTitle).foregroundStyle(Ink.onAccent).fixedSize(horizontal: false, vertical: true)
                line(l10n.t("recap.route", count: route.count))
            }
            if let station = d.records.busiestStation {
                Text(verbatim: station.name).clack(.pageTitle).foregroundStyle(Ink.onAccent).padding(.top, Space.xl)
                line(l10n.t("recap.station", ["count": String(station.count)]))
            }
        }
    }

    /// The drawings of the trains ridden, most first.
    private func trains(_ d: Passport) -> some View {
        let list = trainTypes(d)
        return VStack(alignment: .leading, spacing: Space.l) {
            Text(l10n.t("recap.trainsTitle")).clack(.sheetTitle).foregroundStyle(Ink.onAccent)
            ForEach(Array(list.prefix(5).enumerated()), id: \.element.type.id) { i, t in
                HStack(spacing: Space.m) {
                    TrainPicture(type: t.type, operatorId: t.operatorId, height: 40)
                        .frame(width: 150, alignment: .leading)
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(t.type.name).clack(.rowTitle).foregroundStyle(Ink.onAccent).lineLimit(2)
                        Text(l10n.t("recap.times", ["count": String(t.count)])).clack(.caption).monospacedDigit().foregroundStyle(Ink.onAccent.opacity(0.7))
                    }
                }
                .offset(x: shown || reduceMotion ? 0 : 40)
                .opacity(shown || reduceMotion ? 1 : 0)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(Double(i) * 0.12), value: shown)
            }
        }
    }

    /// The year's medals press in, one after another (the Passport's stamp, signature 4).
    private var medals: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            big(String(earnedThisYear.count))
            line(l10n.t("recap.medals", ["year": String(year)]))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 3), spacing: Space.m) {
                ForEach(Array(earnedThisYear.prefix(9).enumerated()), id: \.element.stampKey) { i, m in
                    Medal(m: m, size: 84)
                        .scaleEffect(shown || reduceMotion ? 1 : 1.25)
                        .opacity(shown || reduceMotion ? 1 : 0)
                        .animation(reduceMotion ? nil : .spring(duration: 0.4, bounce: 0.3).delay(0.2 + Double(i) * 0.15), value: shown)
                }
            }
        }
        .haptic(.success, trigger: shown, condition: { _, now in now && !earnedThisYear.isEmpty })
    }

    private func records(_ d: Passport) -> some View {
        let r = d.records
        return VStack(alignment: .leading, spacing: Space.l) {
            Text(l10n.t("recap.recordsTitle")).clack(.sheetTitle).foregroundStyle(Ink.onAccent)
            if let longest = r.longestDistance {
                record(l10n.t("recap.longest"), Format.distance(longest.distanceM, unit: app.settings.distanceUnit, language: app.settings.language), "\(longest.from) → \(longest.to)")
            }
            if let early = r.earliestDeparture {
                record(l10n.t("recap.earliest"), Format.time(early.dep.ms, tz: early.depTz ?? Format.defaultZone, clock: app.settings.clock), "\(early.from) → \(early.to)")
            }
            if let late = r.latestArrival {
                record(l10n.t("recap.latest"), Format.time(late.arr.ms, tz: late.arrTz ?? Format.defaultZone, clock: app.settings.clock), "\(late.from) → \(late.to)")
            }
            if let worst = r.biggestDelay, let delay = worst.delayMin {
                record(l10n.t("recap.mostLate"), Format.delay(delay), "\(worst.from) → \(worst.to)")
            }
        }
    }

    private func record(_ label: String, _ value: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(label).clack(.captionUpper).foregroundStyle(Ink.onAccent.opacity(0.7))
            Text(value).clack(.bigTime).monospacedDigit().foregroundStyle(Ink.onAccent)
            Text(verbatim: detail).clack(.caption).foregroundStyle(Ink.onAccent).lineLimit(2)
        }
    }

    private var share: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            big(l10n.t("recap.shareTitle"))
            line(l10n.t("recap.shareBody"))
            Button { sharing = true } label: {
                Label { Text(l10n.t("common.share")) } icon: { LucideIcon(name: "share-2", size: 16) }
            }
            .buttonStyle(.clack(.secondary, wide: true))
        }
    }

    // MARK: pieces

    private func big(_ text: String) -> some View {
        Text(text).clack(.passportDistance).monospacedDigit().foregroundStyle(Ink.onAccent)
            .lineLimit(2).minimumScaleFactor(0.6)
    }

    private func line(_ text: String, prefix: String? = nil) -> some View {
        ((prefix.map { Text(verbatim: "\($0) ").fontWeight(.heavy) } ?? Text(verbatim: "")) + Text(text))
            .clack(.headline).foregroundStyle(Ink.onAccent).fixedSize(horizontal: false, vertical: true)
    }

    private func load() async {
        failed = false
        do {
            data = try await app.client.passport(year: year, commuter: app.settings.includeCommuter, comparison: app.settings.co2Comparison)
        } catch {
            failure = APIError.classify(error)
            failed = true
        }
    }
}
