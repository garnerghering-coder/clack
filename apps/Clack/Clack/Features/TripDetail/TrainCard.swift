//
//  TrainCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The train you rode (owner request 2026-10-21): illustration, type and a few facts. Types are typical guesses (no
/// open data says which vehicle ran), so they're labelled and the owner can correct them.
struct TrainCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: LegDetail
    let onChange: (LegDetail) -> Void
    @State private var picking = false
    @State private var saving = false

    var body: some View {
        let type = leg.leg.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        let source = leg.leg.trainTypeSource
        let operatorId = leg.leg.operator?.id
        Card(spacing: 12) {
            Text(l10n.t("train.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            if let type {
                ScrollView(.horizontal, showsIndicators: false) {
                    TrainPicture(type: type, operatorId: operatorId, height: 56, label: type.name).padding(.top, 8).padding(.bottom, 2)
                }
                HStack(spacing: 8) {
                    Text(type.name).clack(.headline).foregroundStyle(Ink.text)
                    Chip(text: l10n.t(source == .user ? "train.yourChoice" : source == .composition ? "train.planned" : "train.typical"))
                }
                Text(type.about).clack(.caption).foregroundStyle(Ink.text2)
                HStack(alignment: .top, spacing: 24) {
                    if let top = type.maxKmh { fact(l10n.t("train.topSpeed"), "\(top) km/h") }
                    if let since = type.since { fact(l10n.t("train.since"), String(since)) }
                    if let builder = type.builder { fact(l10n.t("train.builder"), builder) }
                }
            } else {
                Text(l10n.t("train.unknown")).clack(.caption).foregroundStyle(Ink.text2)
            }
            // How it usually runs at your stop, from Clack's own record (BUILDOUT O4); silent under four days.
            if let h = leg.leg.arrivalHistory, h.days >= 4, let station = leg.leg.destination?.name {
                VStack(alignment: .leading, spacing: 2) {
                    Text(h.highMin >= 5
                        ? l10n.t("train.usuallyLate", ["low": String(Int(h.lowMin)), "high": String(Int(h.highMin)), "station": station, "late": String(h.lateDays), "days": String(h.days)])
                        : l10n.t("train.usuallyOnTime", ["station": station, "ontime": String(h.onTimeDays), "days": String(h.days)]))
                        .clack(.caption).foregroundStyle(h.highMin >= 5 ? Ink.lateInk : Ink.onTimeInk)
                    Text(l10n.t("train.historySource")).clack(.micro).foregroundStyle(Ink.text3)
                }
            }
            Button(picking ? l10n.t("train.cancel") : l10n.t("train.change")) { picking.toggle() }
                .buttonStyle(LinkButtonStyle())
            if picking { picker(current: leg.leg.trainType, source: source, operatorId: operatorId) }
        }
    }

    private func fact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).clack(.captionUpper).foregroundStyle(Ink.text2)
            Text(value).clack(.rowTitle).monospacedDigit().foregroundStyle(Ink.text)
        }
    }

    /// The types to offer, in the order a person picks by looks (owner, 2026-10-29): the ones drawn in this
    /// operator's livery first, then the rest; the "X or Y" groups (for uncertain automatic types) are left out, and
    /// two types that would show the same drawing are offered once.
    private func pickable(current: String?, operatorId: String?) -> [TrainType] {
        var seen = Set<String>()
        return app.trainTypes
            .filter { !$0.name.contains(" or ") || $0.id == current }
            .sorted { a, b in
                let la = TrainArt.hasDetailedArt(typeId: a.id, operatorId: operatorId), lb = TrainArt.hasDetailedArt(typeId: b.id, operatorId: operatorId)
                return la != lb ? la : a.name < b.name
            }
            .filter { t in
                let p = TrainArt.picture(typeId: t.id, art: t.art, uncertain: false, operatorId: operatorId)
                return t.id == current || seen.insert("\(p.asset)|\(p.isStandIn)").inserted
            }
    }

    private func picker(current: String?, source: TrainTypeSource?, operatorId: String?) -> some View {
        VStack(spacing: 8) {
            ForEach(pickable(current: current, operatorId: operatorId)) { type in
                Button { choose(type.id) } label: {
                    HStack(spacing: 12) {
                        TrainPicture(type: type, operatorId: operatorId, height: 44).frame(width: 150, alignment: .leading)
                        Text(type.name).clack(.caption).foregroundStyle(Ink.text2)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 8).padding(.horizontal, 12)
                    .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .hairlineBorder(radius: Radius.controlSm, color: type.id == current ? Ink.accentLine : Ink.hairline)
                }
                .buttonStyle(.plain)
            }
            if source == .user {
                Button { choose(nil) } label: {
                    Text(l10n.t("train.resetTypical")).clack(.body).foregroundStyle(Ink.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                        .hairlineBorder(radius: Radius.controlSm)
                }
                .buttonStyle(.plain)
            }
        }
        .disabled(saving)
    }

    private func choose(_ id: String?) {
        saving = true
        Task {
            if let updated = try? await app.client.setTrainType(leg.id, id) {
                onChange(updated)
                picking = false
            }
            saving = false
        }
    }
}
