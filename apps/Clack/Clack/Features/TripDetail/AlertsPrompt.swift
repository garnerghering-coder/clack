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
    /// Just switched on from here: the card gives way to the word that it took (user test 2026-11-07: "I pressed
    /// Allow and the thing I pressed disappeared. Did it take?").
    @State private var justOn = false

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
        } else if app.settings.notify, !leg.canceled {
            // Alerts are on for this train (and every other ahead): one line, and the way to what you get.
            NavigationLink(value: AppRoute.settings) {
                HStack(spacing: 8) {
                    LucideIcon(name: "bell", size: 16).foregroundStyle(Ink.accentInk)
                    Text(l10n.t(justOn ? "alertsPrompt.nowOn" : "alertsPrompt.on")).clack(.caption).foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    LucideIcon(name: "chevron-right", size: 14).foregroundStyle(Ink.text3)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(l10n.t("settings.title"))
        }
    }

    private func turnOn() async {
        busy = true
        // The same as Settings' switch: on only if iOS says yes.
        if await app.notifications.requestPermission() {
            await app.update(SettingsPatch(notify: true))
            Usage.shared.count(.feature, "alerts.on")
            justOn = true
        }
        asked = true
        busy = false
    }
}
