//
//  AlertsPrompt.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// "Get alerts for this train?" (owner, 2026-10-24): once, on a trip still ahead, instead of asking for permission at
/// the first launch. "Turn on alerts" is the same as the switch in Settings: iOS asks, and alerts go on only if it
/// says yes. Answered or closed, it doesn't come back (`FirstRun.alertsAskedKey`).
struct AlertsPrompt: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let leg: Leg
    @AppStorage(FirstRun.alertsAskedKey) private var asked = false
    @State private var busy = false

    private static let dismissKey = "firstRun.alerts"

    var body: some View {
        let show = FirstRun.showsAlertsPrompt(
            stageBefore: true, canceled: leg.canceled, alertsOn: app.settings.notify, denied: app.notifications.denied,
            asked: asked || DismissedAlerts.contains(Self.dismissKey)
        )
        if show {
            AlertCard(tone: .info, icon: "clock", title: l10n.t("alertsPrompt.title"), dismissKey: Self.dismissKey) {
                Text(l10n.t("alertsPrompt.body")).clack(.body).foregroundStyle(Ink.text)
                Button {
                    Task { await turnOn() }
                } label: {
                    Text(l10n.t("alertsPrompt.turnOn"))
                }
                .buttonStyle(.clack(.primary, small: true))
                .disabled(busy)
            }
        }
    }

    private func turnOn() async {
        busy = true
        // The same as Settings' switch: on only if iOS says yes.
        if await app.notifications.requestPermission() { await app.update(SettingsPatch(notify: true)) }
        asked = true
        busy = false
    }
}
