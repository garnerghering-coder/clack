//
//  RiskCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Journey risk on an upcoming trip (owner, 2026-10-22): warnings from what can be observed, each saying what it's
/// based on, and never called a prediction. Nothing shows when the evidence is weak (Risk.tsx).
struct RiskCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: LegDetail
    @State private var risk: LegRisk?
    @State private var next: Leg?

    var body: some View {
        content
            .task(id: leg.id) {
                // On open and every 5 minutes.
                while !Task.isCancelled {
                    if let fresh = try? await app.client.legRisk(leg.id) { risk = fresh }
                    try? await Task.sleep(for: .seconds(300))
                }
            }
            .task(id: leg.leg.journeyId) {
                guard let journeyId = leg.leg.journeyId, let journey = try? await app.client.journey(journeyId) else { return }
                let legs = journey.legs.map(\.leg)
                let i = legs.firstIndex { $0.id == leg.id }
                let n = i.flatMap { $0 + 1 < legs.count ? legs[$0 + 1] : nil }
                next = n?.origin?.id == leg.leg.destination?.id ? n : nil
            }
    }

    @ViewBuilder
    private var content: some View {
        if let risk, !risk.warnings.isEmpty {
            let nowWarn = risk.warnings.contains { $0.kind != "train_pattern" }
            // A short planned change is what a late-running line puts at risk.
            let change = next.map { Int((($0.schedDep?.ms ?? 0) - (leg.leg.schedArr?.ms ?? 0)) / 60_000) }
            let changeAtRisk = nowWarn && (change ?? 99) < 10
            AlertCard(
                tone: .watch, icon: "activity", title: l10n.t(nowWarn ? "risk.titleNow" : "risk.titlePattern"),
                dismissKey: "risk:\(leg.id):\(risk.warnings.map(\.kind).joined(separator: ","))"
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(risk.warnings.enumerated()), id: \.offset) { _, warning in
                        (Text(l10n.t("risk.kind.\(warning.kind)")).fontWeight(.semibold).foregroundStyle(Ink.text2) + Text(" ") + Text(line(warning)))
                            .clack(.body).foregroundStyle(Ink.text)
                    }
                    if changeAtRisk, let next, let change {
                        Text(l10n.t("risk.change", ["min": String(change), "station": next.origin?.name ?? ""]))
                            .clack(.body).foregroundStyle(Ink.text)
                    }
                }
                InfoNote(
                    l10n.t("risk.honest", ["time": Format.time(risk.checkedAt.ms, tz: Format.zone(leg.leg.origin?.tz), clock: app.settings.clock)]),
                    more: l10n.t("risk.honestMore")
                )
            }
        }
    }

    private func number(_ value: Double) -> String { String(Int(value.rounded())) }

    private func line(_ warning: RiskWarning) -> String {
        switch warning {
        case .routeNow(let trains, let late, let canceled, let median, let window):
            l10n.t("risk.routeNow", ["late": String(late), "trains": String(trains), "canceled": String(canceled), "median": number(median), "window": number(window)])
        case .ahead(let station, let toward, let trains, let late, let delays, let window):
            l10n.t("risk.ahead", ["trains": String(trains), "station": station, "toward": toward, "window": number(window), "late": String(late), "delays": delays.map(String.init).joined(separator: ", ")])
        case .stationNow(let station, let trains, let late, let median, let window):
            l10n.t("risk.stationNow", ["station": station, "late": String(late), "trains": String(trains), "median": number(median), "window": number(window)])
        case .trainPattern(let station, let days, let lateDays, let median):
            l10n.t("risk.pattern", ["station": station, "late": String(lateDays), "days": String(days), "median": number(median)])
        case .unknown:
            ""
        }
    }
}
