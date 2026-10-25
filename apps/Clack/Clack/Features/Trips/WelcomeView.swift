//
//  WelcomeView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The first time Clack opens (DESIGN §13): the wordmark and what Clack does in three lines, then a page asking for
/// alerts (owner, 2026-10-25: ask up front, so alerts and the trip card work from the first trip). No sign-up. Shown
/// once (`FirstRun`); the empty Trips screen under it has the ways to start.
struct WelcomeView: View {
    @Environment(L10n.self) private var l10n
    let onDone: () -> Void
    @State private var askingAlerts = false

    var body: some View {
        if askingAlerts {
            AlertsIntro(onDone: onDone)
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else {
            intro.transition(.opacity)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            Wordmark(fontSize: 44)
            Text(l10n.t("app.tagline")).clack(.splashTagline).foregroundStyle(Ink.text2)
            VStack(alignment: .leading, spacing: 16) {
                line("ticket", l10n.t("firstRun.log"))
                line("radar", l10n.t("firstRun.live"))
                line("stamp", l10n.t("firstRun.passport"))
            }
            Spacer(minLength: 0)
            Button(l10n.t("firstRun.continue")) {
                withAnimation(.easeInOut(duration: 0.3)) { askingAlerts = true }
            }
            .buttonStyle(.clack(.primary, wide: true))
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(Ink.bg)
        .accessibilityElement(children: .contain)
    }

    private func line(_ icon: String, _ text: String) -> some View {
        WelcomeLine(icon: icon, text: text)
    }
}

/// One line of what Clack does: an icon in the accent ink and a sentence.
private struct WelcomeLine: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            LucideIcon(name: icon, size: 20).foregroundStyle(Ink.accentInk)
            Text(text).clack(.body).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// "Know when your train changes": what alerts and the trip card do, then iOS's own question. Part of the welcome,
/// and shown once by itself to someone who had Clack before it asked (`FirstRun.showsAlertsIntro`). "Not now" leaves
/// the one-time card on an upcoming trip as the next chance.
struct AlertsIntro: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @AppStorage(FirstRun.alertsIntroSeenKey) private var seen = false
    let onDone: () -> Void
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            LucideIcon(name: "bell-ring", size: 48).foregroundStyle(Ink.accentInk)
            Text(l10n.t("alertsIntro.title")).clack(.welcomeTitle).foregroundStyle(Ink.text).accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 16) {
                WelcomeLine(icon: "map-pin", text: l10n.t("alertsIntro.platform"))
                WelcomeLine(icon: "triangle-alert", text: l10n.t("alertsIntro.delays"))
                WelcomeLine(icon: "smartphone", text: l10n.t("alertsIntro.live"))
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button(l10n.t("alertsIntro.allow")) { Task { await allow() } }
                    .buttonStyle(.clack(.primary, wide: true))
                    .disabled(busy)
                Button(l10n.t("alertsIntro.notNow")) { finish() }
                    .buttonStyle(.clack(wide: true))
                Text(l10n.t("alertsIntro.later")).clack(.caption).foregroundStyle(Ink.text2).frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(Ink.bg)
        .accessibilityElement(children: .contain)
    }

    /// iOS asks; alerts go on (the same as Settings' switch) only if it says yes.
    private func allow() async {
        busy = true
        if await app.notifications.requestPermission() { await app.update(SettingsPatch(notify: true)) }
        busy = false
        finish()
    }

    private func finish() {
        seen = true
        onDone()
    }
}
