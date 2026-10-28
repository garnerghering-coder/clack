//
//  StationNoticeCard.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Notices about the stations of this trip (where you get on and off, and so where you change): a lift out of order,
/// a closed walkway (owner, 2026-10-28). They aren't about the train, so they stay off its stop list and show here, for
/// these stations only. Each is shortened or translated on the phone when it isn't in the app's language; the
/// original is one tap away. Nothing when there are none.
struct StationNoticeCard: View {
    @Environment(L10n.self) private var l10n
    let leg: LegDetail
    @State private var open: Set<String> = []

    private var notices: [(line: CauseLine, source: String)] {
        var out: [(CauseLine, String)] = []
        for stop in leg.stops where stop.role == .board || stop.role == .alight {
            let causes = stop.allCauses
            for line in l10n.facilityLines(causes) where !out.contains(where: { $0.0 == line }) {
                out.append((line, DelayCauses.sourceName(causes.first { $0.isFacility }?.src ?? "")))
            }
        }
        return out
    }

    var body: some View {
        let list = notices
        if !list.isEmpty {
            AlertCard(tone: .info, icon: "info", title: l10n.t("notice.stationTitle"), dismissKey: "stations|\(leg.leg.id)|\(list.map(\.line.text).joined())") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(list, id: \.line) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(l10n.shown(item.line)).clack(.body).foregroundStyle(Ink.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if let original = item.line.original, original != item.line.text {
                                let shown = open.contains(item.line.text)
                                Button(l10n.t(shown ? "notice.hideOriginal" : "notice.showOriginal")) {
                                    if shown { open.remove(item.line.text) } else { open.insert(item.line.text) }
                                }
                                .buttonStyle(LinkButtonStyle())
                                if shown { Text(original).clack(.caption).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true) }
                            }
                        }
                    }
                    Text(l10n.t("notice.source", ["source": list.first?.source ?? ""])).clack(.caption).foregroundStyle(Ink.text3)
                }
            }
        }
    }
}
