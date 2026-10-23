//
//  RootView.swift
//  Clack
//

import SwiftUI

/// The app's shell: the three tabs over a tab bar, the offline strip, and the launch splash (AppShell.tsx).
struct RootView: View {
    @Environment(AppModel.self) private var app
    @State private var router = Router()
    @State private var splashMinDone = false
    @State private var splashGone = false
    @State private var touched = false

    /// The splash goes once the settings have loaded (or failed to) and the tiles have had time to flip in.
    private var hideSplash: Bool { app.state != .loading && splashMinDone }

    var body: some View {
        ZStack(alignment: .top) {
            Ink.bg.ignoresSafeArea()
            Group {
                switch router.tab {
                case .trips: TripsScreen()
                case .explore: ExploreScreen()
                case .passport: PassportScreen()
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { TabBar(selection: $router.tab) }

            if app.isOffline {
                OfflineBanner().transition(.opacity)
            }
            if !splashGone {
                Splash()
                    .opacity(hideSplash ? 0 : 1)
                    .animation(.easeInOut(duration: 0.35), value: hideSplash)
                    .allowsHitTesting(!hideSplash)
            }
        }
        .environment(app.l10n)
        .preferredColorScheme(app.colorScheme)
        // Any touch before the landing rule has decided cancels it.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in touched = true })
        .onChange(of: router.tab) { _, tab in Landing.saveLastTab(tab) }
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            splashMinDone = true
        }
        .onChange(of: hideSplash) { _, hide in
            guard hide else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                splashGone = true
            }
        }
        .task { await land() }
    }

    /// Once per app start: open where it matters (a train running or about to leave opens Trips, else the tab you
    /// used last, else Explore), and never after you've touched anything.
    private func land() async {
        guard !app.hasLanded else { return }
        app.hasLanded = true
        let lastTab = Landing.readLastTab()
        do {
            let legs: [Leg] = try await app.client.get(["legs"])
            app.noteSuccess()
            let tab = Landing.resolve(
                legs: legs.map(Landing.LegTimes.init), now: Date.now.timeIntervalSince1970 * 1000, lastTab: lastTab
            )
            if !touched, tab != .trips, router.tab == .trips { router.tab = tab }
        } catch {
            app.noteFailure(error)
            if !touched, let lastTab, lastTab != .trips, router.tab == .trips { router.tab = lastTab }
        }
    }
}
