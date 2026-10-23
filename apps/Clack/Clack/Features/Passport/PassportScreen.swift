//
//  PassportScreen.swift
//  Clack
//

import SwiftUI

/// The Passport tab. Empty until step 12.
struct PassportScreen: View {
    @Environment(L10n.self) private var l10n

    var body: some View {
        NavigationStack {
            Page {
                PageHeader(title: l10n.t("nav.passport")) { SettingsLink() }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
