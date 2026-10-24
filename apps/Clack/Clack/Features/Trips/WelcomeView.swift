//
//  WelcomeView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The first time Clack opens (DESIGN §13, owner 2026-10-24): one screen over the empty Trips tab, the wordmark, what
/// Clack does in three lines, and the two ways to start. No sign-up and no permission prompts; it is shown once
/// (`FirstRun`).
struct WelcomeView: View {
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 0)
            Wordmark(fontSize: 44, animateIn: true)
            Text(l10n.t("app.tagline")).clack(.splashTagline).foregroundStyle(Ink.text2)
            VStack(alignment: .leading, spacing: 16) {
                line("ticket", l10n.t("firstRun.log"))
                line("radar", l10n.t("firstRun.live"))
                line("stamp", l10n.t("firstRun.passport"))
            }
            Spacer(minLength: 0)
            VStack(spacing: 12) {
                Button {
                    onDone()
                    router.openAdd()
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: "plus", size: 18)
                        Text(l10n.t("trips.findTrain"))
                    }
                }
                .buttonStyle(.clack(.primary, wide: true))
                Button {
                    onDone()
                    router.tab = .explore
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: "compass", size: 18)
                        Text(l10n.t("trips.exploreTrains"))
                    }
                }
                .buttonStyle(.clack(wide: true))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 24)
        .frame(maxWidth: 560, maxHeight: .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .background(Ink.bg)
        .accessibilityElement(children: .contain)
    }

    private func line(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            LucideIcon(name: icon, size: 20).foregroundStyle(Ink.accentInk)
            Text(text).clack(.body).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
        }
    }
}
