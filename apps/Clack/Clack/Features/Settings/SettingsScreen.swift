//
//  SettingsScreen.swift
//  Clack
//

import SwiftUI

/// The gear in a tab's header: opens Settings.
struct SettingsLink: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        NavigationLink {
            SettingsScreen()
        } label: {
            LucideIcon(name: "settings", size: 20)
                .foregroundStyle(Ink.text)
                .frame(width: 44, height: 44)
                .background(Ink.surfaceRaised, in: Circle())
                .overlay(Circle().strokeBorder(Ink.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.t("nav.settings"))
    }
}

/// Settings. Empty until step 13; in Debug builds it links to the design gallery.
struct SettingsScreen: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        Page {
            BackLink()
            PageHeader(title: l10n.t("settings.title"))
            #if DEBUG
            NavigationLink("Design") { DesignGalleryView() }
                .buttonStyle(.clack(wide: true))
            #endif
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}
