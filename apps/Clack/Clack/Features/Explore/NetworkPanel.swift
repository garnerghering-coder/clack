//
//  NetworkPanel.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Network status on Explore (the button beside the filters): per country how many trains are 10+ minutes late, the
/// corridors where most trains are, with the reasons the feeds give, and the late trains outside them. Read off the live
/// map (`GET /api/live/network`), so it is as fresh as the map. Status is written, never boxed (DESIGN.md).
struct NetworkPanel: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let status: NetworkStatus?
    let failed: Bool
    var onCorridor: (NetworkStatus.Corridor) -> Void
    var onTrain: (NetworkStatus.LateTrain) -> Void
    var onClose: () -> Void
    /// The content's own height: the card hugs it, up to 560 pt, then scrolls.
    @State private var contentHeight = 200.0

    var body: some View {
        ScrollView {
            content.onGeometryChange(for: Double.self) { $0.size.height } action: { contentHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: 460)
        .frame(height: min(contentHeight, 560))
        .background(Ink.glass).background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, 16).padding(.top, 64)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(l10n.t("network.title")).clack(.headline).foregroundStyle(Ink.text)
                Spacer(minLength: 8)
                if let status {
                    Text(l10n.t("network.updated", ["time": Format.time(status.at, tz: TimeZone.current.identifier, clock: app.settings.clock)]))
                        .clack(.micro).foregroundStyle(Ink.text3)
                }
            }
            if let status {
                countries(status)
                corridors(status)
                if !status.late.isEmpty { lateTrains(status) }
                Text(l10n.t("network.explain", ["min": String(status.lateMin)])).clack(.micro).foregroundStyle(Ink.text3)
            } else if failed {
                Text(l10n.t("network.failed")).clack(.body).foregroundStyle(Ink.text2)
            } else {
                Skeleton(height: 120)
            }
            ChipButton(text: l10n.t("common.done")) { onClose() }
        }
        .padding(16)
    }

    // MARK: countries

    private func countries(_ status: NetworkStatus) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(["SE", "NO", "DK", "FI"].filter { status.countries[$0] != nil }, id: \.self) { code in
                let c = status.countries[code]!
                HStack(spacing: 8) {
                    Flag(country: code, size: 18, decorative: true)
                    Text(l10n.t("countries.\(code)")).clack(.body).foregroundStyle(Ink.text)
                    Spacer(minLength: 8)
                    Text(l10n.t("network.countryLate", ["late": String(c.late), "trains": String(c.trains)]))
                        .clack(.caption).monospacedDigit()
                        .foregroundStyle(NetworkWording.countryInk(c))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: corridors

    @ViewBuilder
    private func corridors(_ status: NetworkStatus) -> some View {
        Text(l10n.t("network.corridors")).clack(.captionUpper).foregroundStyle(Ink.text2).padding(.top, 4)
        if status.corridors.isEmpty {
            Text(l10n.t("network.noCorridors")).clack(.body).foregroundStyle(Ink.onTimeInk)
        } else {
            ForEach(status.corridors) { c in
                Button { onCorridor(c) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(c.stations.joined(separator: " – ")).clack(.rowTitle).foregroundStyle(Ink.text).multilineTextAlignment(.leading)
                        Text(NetworkWording.corridorLine(c, l10n: l10n)).clack(.caption).monospacedDigit().foregroundStyle(Ink.lateInk)
                        Text(NetworkWording.reasons(c.causes, l10n: l10n)).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .hairlineBorder(radius: Radius.controlSm)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(l10n.t("network.showOnMap"))
            }
        }
    }

    // MARK: late trains

    @ViewBuilder
    private func lateTrains(_ status: NetworkStatus) -> some View {
        Text(l10n.t("network.lateTrains")).clack(.captionUpper).foregroundStyle(Ink.text2).padding(.top, 4)
        ForEach(status.late) { t in
            Button { onTrain(t) } label: {
                HStack(alignment: .top, spacing: 12) {
                    OperatorBadge(op: t.operatorId.flatMap { app.operatorsById[$0] }, size: .small)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text([t.operatorId.flatMap { app.operatorsById[$0]?.name }, t.number].compactMap { $0 }.joined(separator: " "))
                                .clack(.rowTitle).foregroundStyle(Ink.text)
                            Text(l10n.t("network.minLate", ["min": String(t.delayMin)])).clack(.delay).monospacedDigit()
                                .foregroundStyle(t.delayMin >= 30 ? Ink.veryLateInk : Ink.lateInk)
                        }
                        if let between = NetworkWording.between(t, l10n: l10n) {
                            Text(between).clack(.caption).foregroundStyle(Ink.text2)
                        }
                        if !t.causes.isEmpty {
                            Text(NetworkWording.reasons(t.causes.map { .init(src: $0.src, code: $0.code, text: $0.text, trains: 1) }, l10n: l10n, counted: false))
                                .clack(.caption).foregroundStyle(Ink.text2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(minHeight: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// The panel's wording, kept apart from the view so it can be read and tested on its own.
enum NetworkWording {
    /// A country's line is the late ink when one train in ten or more is late, otherwise plain.
    static func countryInk(_ c: NetworkStatus.Country) -> Color {
        c.trains > 0 && c.late * 10 >= c.trains ? Ink.lateInk : Ink.text2
    }

    /// "4 of 5 trains late · typically +18 min, up to +30"
    static func corridorLine(_ c: NetworkStatus.Corridor, l10n: L10n) -> String {
        l10n.t("network.corridorLine", ["late": String(c.late), "trains": String(c.trains), "median": String(c.medianDelay), "max": String(c.maxDelay)])
    }

    /// "Signal fault (3 trains) · Accident (1 train)", or that no feed says why.
    static func reasons(_ causes: [NetworkStatus.Cause], l10n: L10n, counted: Bool = true) -> String {
        let named = causes.compactMap { c -> String? in
            guard let text = DelayCauses.text(c.cause, translate: { l10n.t($0) }) else { return nil }
            return counted ? l10n.t("network.reasonCount", count: c.trains, ["reason": text, "count": String(c.trains)]) : text
        }
        guard !named.isEmpty else { return l10n.t("network.noReason") }
        return Array(NSOrderedSet(array: named)).compactMap { $0 as? String }.prefix(3).joined(separator: Format.separator)
    }

    /// "Between Växjö and Alvesta", or "Towards Alvesta" when the last stop isn't known.
    static func between(_ t: NetworkStatus.LateTrain, l10n: L10n) -> String? {
        switch (t.prev, t.next) {
        case let (a?, b?): l10n.t("network.between", ["a": a, "b": b])
        case let (nil, b?): l10n.t("network.towards", ["b": b])
        default: t.destination.map { l10n.t("network.towards", ["b": $0]) }
        }
    }
}
