//
//  ExploreScreen.swift
//  Clack
//

import SwiftUI

/// The Explore tab (the live map). Empty until step 9.
struct ExploreScreen: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        Page {
            PageHeader(title: l10n.t("nav.explore")) { SettingsLink() }
        }
    }
}
