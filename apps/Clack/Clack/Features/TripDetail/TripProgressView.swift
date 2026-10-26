//
//  TripProgressView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// What a trip did for your Passport (owner, 2026-10-22): after adding a past trip, and on arriving. Milestones it
/// unlocked pop in, the families it moved fill from where they were to where they are, and its firsts are named.
/// Counted trips only; a trip that doesn't count yet says why (TripProgress.tsx).
struct TripProgressView: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let legId: String
    var quietIfNothing = false
    /// Progress already worked out (a whole journey's), instead of the trip's own.
    var given: TripProgress?
    @State private var progress: TripProgress?
    @State private var shown = false

    private static let countryNames = ["SE": "Sweden", "NO": "Norway", "DK": "Denmark", "DE": "Germany", "FI": "Finland"]

    var body: some View {
        Group {
            if let progress { content(progress) }
        }
        .task(id: legId) {
            if let given {
                progress = given
            } else {
                progress = try? await app.client.tripProgress(legId)
            }
            try? await Task.sleep(for: .milliseconds(120))
            shown = true
        }
    }

    @ViewBuilder
    private func content(_ p: TripProgress) -> some View {
        if !p.counted {
            if !quietIfNothing { Text(l10n.t("progress.notCounted")).clack(.caption).foregroundStyle(Ink.text2) }
        } else {
            let firsts = firstsList(p)
            if !(quietIfNothing && p.unlocked.isEmpty && p.moved.isEmpty && firsts.isEmpty) {
                VStack(spacing: 12) {
                    if !p.unlocked.isEmpty {
                        VStack(spacing: 8) {
                            Text(p.unlocked.count == 1 ? l10n.t("progress.unlockedOne") : l10n.t("progress.unlocked", count: p.unlocked.count))
                                .clack(.captionUpper).foregroundStyle(Ink.text2)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 120), spacing: 8, alignment: .top)], spacing: 16) {
                                ForEach(Array(p.unlocked.enumerated()), id: \.offset) { index, milestone in
                                    VStack(spacing: 2) {
                                        Medal(m: milestone, size: 84)
                                        Text(l10n.milestoneLabel(milestone, language: app.settings.language, home: p.home ?? app.settings.homeCountry?.rawValue))
                                            .clack(.caption).fontWeight(.bold).foregroundStyle(Ink.text).multilineTextAlignment(.center)
                                    }
                                    .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                                    .opacity(shown || reduceMotion ? 1 : 0)
                                    .animation(reduceMotion ? nil : .timingCurve(0.2, 1.4, 0.4, 1, duration: 0.6).delay(0.4 + Double(index) * 0.12), value: shown)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    if !firsts.isEmpty {
                        FlowLayout(spacing: 16, lineSpacing: 8) {
                            ForEach(firsts, id: \.self) { Chip(text: $0, accent: true) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !p.moved.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(Array(p.moved.enumerated()), id: \.offset) { _, moved in movedRow(moved, home: p.home) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func firstsList(_ p: TripProgress) -> [String] {
        guard let firsts = p.firsts else { return [] }
        var out = firsts.stations.map { l10n.t("progress.firstStation", ["name": $0]) }
        if let operatorId = firsts.operator {
            out.append(l10n.t("progress.firstOperator", ["name": app.operatorsById[operatorId]?.name ?? operatorId]))
        }
        out += firsts.countries.map { code in
            let fallback = Self.countryNames[code] ?? code
            let key = "countries.\(code)"
            let name = l10n.t(key)
            return l10n.t("progress.firstCountry", ["name": name == key ? fallback : name])
        }
        return out
    }

    private func movedRow(_ moved: TripProgress.Moved, home: String?) -> some View {
        let reached = moved.after >= moved.target
        func fraction(_ v: Double) -> Double { min(1, v / moved.target) }
        return VStack(spacing: 4) {
            HStack {
                Text(l10n.milestoneLabel(Milestone(family: moved.family, target: moved.target, at: nil, legId: nil, value: nil), language: app.settings.language, home: home ?? app.settings.homeCountry?.rawValue))
                    .clack(.banner).fontWeight(.semibold).foregroundStyle(Ink.text)
                Spacer(minLength: 0)
                Text(reached ? l10n.t("progress.reached") : l10n.t("passport.progressOf", ["value": String(Int(moved.after.rounded(.down))), "target": String(Int(moved.target))]))
                    .clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
            }
            ProgressBar(value: fraction(moved.after), color: Ink.accent, previous: fraction(moved.before), animateIn: true)
                .accessibilityHidden(true)
        }
    }
}
