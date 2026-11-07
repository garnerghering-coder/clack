//
//  MilestonesScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Every milestone (owner, 2026-11-07): each family as a row of its levels, the earned ones in colour with their month
/// and their trip, the rest greyed with how far along you are. Milestones are all-time, whatever year the Passport shows.
struct MilestonesScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(PassportStore.self) private var store
    @State private var loaded: Passport?
    @State private var failed = false
    /// Room for a two-line title under every medal, so a medal whose title wraps sits level with its neighbours.
    @ScaledMetric(relativeTo: .footnote) private var titleHeight: CGFloat = 36

    private var data: Passport? { store.data ?? loaded }

    var body: some View {
        Page {
            if let data {
                let ladder = PassportLogic.ladder(data.milestones)
                let earned = ladder.reduce(0) { $0 + $1.earned }
                let total = ladder.reduce(0) { $0 + $1.rungs.count }
                Text(l10n.t("passport.earnedOf", ["earned": String(earned), "total": String(total)])).clack(.headline).foregroundStyle(Ink.text)
                ForEach(ladder, id: \.family) { family in
                    Card {
                        HStack(alignment: .firstTextBaseline) {
                            Text(familyName(family.family)).clack(.sectionHeader).foregroundStyle(Ink.text2)
                            Spacer(minLength: 0)
                            Text("\(family.earned)/\(family.rungs.count)").clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(family.rungs, id: \.milestone.target) { rung in rungView(rung, home: data.home) }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                }
                Text(l10n.t("passport.milestonesNote")).clack(.caption).foregroundStyle(Ink.text2)
            } else if failed {
                Text(l10n.t("passport.loadError")).clack(.body).foregroundStyle(Ink.text2)
            } else {
                Skeleton(height: 120)
            }
        }
        .screenTitle(l10n.t("passport.milestones"))
        .countsScreen("passport.milestones")
        .task {
            guard store.data == nil else { return }
            do {
                loaded = try await app.client.passport(year: nil, commuter: app.settings.includeCommuter, comparison: app.settings.co2Comparison)
            } catch {
                failed = true
            }
        }
    }

    @ViewBuilder
    private func rungView(_ rung: PassportLogic.Rung, home: String?) -> some View {
        let m = rung.milestone
        let label = l10n.milestoneLabel(m, language: app.settings.language, home: home)
        let line: String = rung.earned
            ? (m.at.map { Format.month($0.ms, tz: "Europe/Stockholm", language: app.settings.language) } ?? "")
            : l10n.t("passport.progressOf", ["value": String(Int((m.value ?? 0).rounded())), "target": String(Int(m.target))])
        let tile = VStack(spacing: 2) {
            Medal(m: m, locked: !rung.earned, size: 72)
            Text(label).clack(.caption).fontWeight(.bold).foregroundStyle(Ink.text).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: titleHeight, alignment: .top)
            Text(line).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
        }
        .frame(width: 104)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(line)")
        if rung.earned, let legId = m.legId {
            NavigationLink(value: AppRoute.trip(legId)) { tile }.buttonStyle(.plain)
        } else {
            tile
        }
    }

    private func familyName(_ family: MilestoneFamily) -> String {
        switch family {
        case .unknown(let raw): raw
        default: l10n.t("passport.family.\(family.rawValue)")
        }
    }
}
