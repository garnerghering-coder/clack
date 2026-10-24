//
//  ActivityLog.swift
//  Clack
//

import ClackCore
import SwiftUI

/// What happened on the way, newest first (ActivityLog in Live.tsx).
struct ActivityLog: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: Leg
    let events: [LegEvent]
    let stops: [StopName]

    var body: some View {
        let tz = leg.origin?.tz ?? "Europe/Stockholm"
        Card {
            Text(l10n.t("activity.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            if events.isEmpty {
                Text(l10n.t("activity.empty")).clack(.caption).foregroundStyle(Ink.text2)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(events) { event in
                        let alarming = event.type == .cancelled || event.type == .shortTurned
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Format.time(event.ts.ms, tz: tz, clock: app.settings.clock))
                                .monospacedDigit().foregroundStyle(alarming ? Ink.veryLate : Ink.text2)
                                .frame(width: 56, alignment: .leading)
                            Text(TripDetailLogic.eventText(l10n, event, leg: leg, stops: stops)).foregroundStyle(alarming ? Ink.veryLate : Ink.text)
                        }
                        .clack(.body)
                    }
                }
            }
        }
    }
}
