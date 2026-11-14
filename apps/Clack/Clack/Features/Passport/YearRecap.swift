//
//  YearRecap.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// "2026 in rail" (designer, 2026-11-14; owner: build it now): the year told in a few pages on the Passport's yellow,
/// from the year's own Passport (`GET /passport?year=`), ending on the share card. Only what your trips say; a page
/// with nothing to say is left out.
struct YearRecap: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.dismiss) private var dismiss
    let year: Int
    /// All-time milestones (they are counted over every year); the ones reached this year are this year's.
    let milestones: Passport.Milestones
    @State private var data: Passport?
    @State private var failed = false
    @State private var sharing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Ink.brandYellow.ignoresSafeArea()
            if let data {
                TabView {
                    ForEach(pages(data), id: \.self) { page in
                        pageView(page, data).padding(Space.xl)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))
            } else if failed {
                ErrorStateView(message: l10n.t("recap.failed"), retry: { await load() }).padding(Space.xl)
            } else {
                ProgressView().tint(Ink.onAccent)
            }
            Button { dismiss() } label: {
                LucideIcon(name: "x", size: 18).foregroundStyle(Ink.onAccent).frame(width: 44, height: 44)
            }
            .buttonStyle(.press(radius: 22))
            .accessibilityLabel(l10n.t("common.close"))
            .padding(Space.m)
        }
        .task { await load() }
        .sheet(isPresented: $sharing) {
            if let data { ShareSheet(passport: data, year: year, commuter: app.settings.includeCommuter) { sharing = false } }
        }
    }

    private enum Page: Hashable { case distance, trains, month, route, places, medals, share }

    private func pages(_ d: Passport) -> [Page] {
        var out: [Page] = [.distance, .trains]
        if d.flavor.busiestMonth != nil { out.append(.month) }
        if d.records.mostRiddenRoute != nil { out.append(.route) }
        out.append(.places)
        if !earnedThisYear.isEmpty { out.append(.medals) }
        out.append(.share)
        return out
    }

    /// The medals reached in this year, in its own months.
    private var earnedThisYear: [Milestone] {
        milestones.achieved.filter { m in
            guard let at = m.at?.ms else { return false }
            return Calendar(identifier: .gregorian).component(.year, from: Date(timeIntervalSince1970: at / 1000)) == year
        }
    }

    @ViewBuilder
    private func pageView(_ page: Page, _ d: Passport) -> some View {
        let t = d.totals
        VStack(alignment: .leading, spacing: Space.l) {
            Text(l10n.t("recap.title", ["year": String(year)])).clack(.captionUpper).foregroundStyle(Ink.onAccent.opacity(0.7))
            switch page {
            case .distance:
                big(Format.distance(t.distanceM, unit: app.settings.distanceUnit, language: app.settings.language))
                line(l10n.t("recap.distance"))
            case .trains:
                big(String(t.trains))
                line(l10n.t("recap.trains", ["journeys": String(t.journeys), "time": Format.duration(t.minutes, language: l10n.language)]))
            case .month:
                if let month = d.flavor.busiestMonth {
                    big(monthName(month.month))
                    line(l10n.t("recap.month", ["count": String(month.count)]))
                }
            case .route:
                if let route = d.records.mostRiddenRoute {
                    Text(verbatim: route.route).clack(.sheetTitle).foregroundStyle(Ink.onAccent).fixedSize(horizontal: false, vertical: true)
                    line(l10n.t("recap.route", ["count": String(route.count)]))
                }
            case .places:
                big(String(t.stations))
                line(l10n.t("recap.places", ["countries": String(t.countries)]))
                HStack(spacing: Space.s) {
                    ForEach(d.countries.map(\.code), id: \.self) { Flag(country: $0, size: 28, decorative: false) }
                }
            case .medals:
                big(String(earnedThisYear.count))
                line(l10n.t("recap.medals"))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 3), spacing: Space.m) {
                    ForEach(earnedThisYear.prefix(6), id: \.stampKey) { Medal(m: $0) }
                }
            case .share:
                big(l10n.t("recap.shareTitle"))
                line(l10n.t("recap.shareBody"))
                Button { sharing = true } label: {
                    Label { Text(l10n.t("common.share")) } icon: { LucideIcon(name: "share-2", size: 16) }
                }
                .buttonStyle(.clack(.secondary, wide: true))
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Space.xxxl)
    }

    private func big(_ text: String) -> some View {
        Text(text).clack(.passportDistance).monospacedDigit().foregroundStyle(Ink.onAccent)
            .lineLimit(2).minimumScaleFactor(0.6)
    }

    private func line(_ text: String) -> some View {
        Text(text).clack(.headline).foregroundStyle(Ink.onAccent).fixedSize(horizontal: false, vertical: true)
    }

    /// "2026-03" as "March".
    private func monthName(_ yyyymm: String) -> String {
        let parts = yyyymm.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]), (1...12).contains(m) else { return yyyymm }
        let formatter = DateFormatter()
        formatter.locale = Format.locale(app.settings.language)
        return formatter.standaloneMonthSymbols[m - 1].capitalized
    }

    private func load() async {
        failed = false
        do {
            data = try await app.client.passport(year: year, commuter: app.settings.includeCommuter, comparison: app.settings.co2Comparison)
        } catch {
            failed = true
        }
    }
}
