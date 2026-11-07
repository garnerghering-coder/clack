//
//  PassportMapScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The Passport's map full screen (owner, 2026-11-07: "a super useful and cool graphic hidden as one little box"): every
/// stretch ridden in one ink, heavier where ridden more, stations growing with their visits; pan and zoom; the year
/// chips, which change the Passport behind it too.
struct PassportMapScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(PassportStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Binding var year: Int?

    var body: some View {
        ZStack {
            Ink.mapBg.ignoresSafeArea()
            if let data = store.data {
                MultiRouteMapView(
                    routes: PassportMap.routes(data, dark: app.colorScheme != .light), stations: PassportMap.stations(data),
                    railNetwork: app.settings.showRailNetwork, label: l10n.t("passport.mapLabel", count: data.totals.trains),
                    interactive: true, heat: true
                )
                .ignoresSafeArea()
            }
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    if let data = store.data {
                        YearChips(years: data.years, year: $year)
                    }
                    Spacer(minLength: 0)
                    IconButton(icon: "system:xmark", label: l10n.t("common.close")) { dismiss() }
                        .padding(.trailing, 16)
                }
                .padding(.top, 8)
                Spacer()
                if let data = store.data {
                    Text(l10n.t("passport.mapLabel", count: data.totals.trains))
                        .clack(.caption).foregroundStyle(Ink.text2)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                        .padding(.bottom, 12)
                }
            }
        }
        .countsScreen("passport.map")
    }
}
