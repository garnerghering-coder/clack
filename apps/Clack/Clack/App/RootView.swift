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
            // The screens get the space above the tab bar, so full-bleed ones (the maps) end at it.
            VStack(spacing: 0) {
                ZStack {
                    // Explore is built at launch and kept: its map, trains and where you were are there the moment
                    // you open it, instead of starting from scratch each time.
                    stack(.explore) { ExploreScreen() }
                        .opacity(router.tab == .explore ? 1 : 0)
                        .allowsHitTesting(router.tab == .explore)
                        .accessibilityHidden(router.tab != .explore)
                    switch router.tab {
                    case .trips: stack(.trips) { TripsScreen() }
                    case .explore: EmptyView()
                    case .passport: stack(.passport) { PassportScreen() }
                    }
                }
                TabBar(selection: $router.tab)
            }

            if app.isOffline {
                OfflineBanner().transition(.opacity)
            }
            VStack {
                Spacer()
                TicketReturnPrompt().padding(.bottom, 64)
            }
            if !splashGone {
                Splash()
                    .opacity(hideSplash ? 0 : 1)
                    .animation(.easeInOut(duration: 0.35), value: hideSplash)
                    .allowsHitTesting(!hideSplash)
            }
        }
        .environment(app.l10n)
        .environment(router)
        // Text can be held and selected, as anywhere on iOS (the controls turn it off for themselves).
        .textSelection(.enabled)
        .sheet(item: $router.addRequest) { request in
            AddTrainSheet(request: request)
                .environment(app)
                .environment(app.l10n)
                .environment(router)
                .preferredColorScheme(app.colorScheme)
        }
        .preferredColorScheme(app.colorScheme)
        // Any touch before the landing rule has decided cancels it.
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in touched = true })
        .onChange(of: router.tab) { _, tab in Landing.saveLastTab(tab) }
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            #if DEBUG
            // `-holdSplash` keeps the splash on screen, to look at it.
            if CommandLine.arguments.contains("-holdSplash") { return }
            #endif
            // The logos come in while the splash is up (at most 2.5 s more), so no badge appears empty.
            var waited = 0
            while !app.logosSettled && waited < 25 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
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

    /// One tab's stack: its root screen, and whatever has been pushed onto it (kept when you switch tabs).
    private func stack<Root: View>(_ tab: PrimaryTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: Binding(get: { router.path(for: tab) }, set: { router.setPath($0, for: tab) })) {
            root()
                .toolbar(.hidden, for: .navigationBar)
                .appDestinations()
        }
    }

    /// Once per app start: open where it matters (a train running or about to leave opens Trips, else the tab you
    /// used last, else Explore), and never after you've touched anything.
    private func land() async {
        guard !app.hasLanded else { return }
        app.hasLanded = true
        #if DEBUG
        // A `-tab` launch argument says where to look; the landing rule leaves it alone.
        if CommandLine.arguments.contains("-tab") { return }
        #endif
        let lastTab = Landing.readLastTab()
        do {
            let legs: [Leg] = try await app.client.get(["legs"])
            let tab = Landing.resolve(
                legs: legs.map(Landing.LegTimes.init), now: Date.now.timeIntervalSince1970 * 1000, lastTab: lastTab
            )
            if !touched, tab != .trips, router.tab == .trips { router.tab = tab }
        } catch {
            if !touched, let lastTab, lastTab != .trips, router.tab == .trips { router.tab = lastTab }
        }
    }
}
