//
//  RootView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The app's shell: the three tabs over a tab bar, the offline strip, and the launch splash (AppShell.tsx).
struct RootView: View {
    @Environment(AppModel.self) private var app
    @State private var router = Router()
    @State private var splashMinDone = false
    @State private var splashGone = false
    /// Someone who had Clack before the welcome asked about alerts: the alerts page once, by itself.
    @State private var askAlerts = false
    @Environment(\.scenePhase) private var scenePhase

    /// The splash goes once the settings have loaded (or failed to) and the tiles have had time to flip in.
    private var hideSplash: Bool { app.state != .loading && splashMinDone }

    var body: some View {
        ZStack(alignment: .top) {
            Ink.bg.ignoresSafeArea()
            // The system's tab bar (Liquid Glass on iOS 26). Each tab keeps its screen and stack while you're on another,
            // so Explore's map and trains are there the moment you come back.
            TabView(selection: $router.tab) {
                stack(.trips) { TripsScreen() }
                    .tabItem { tabLabel(.trips, icon: "train-front") }
                    .tag(PrimaryTab.trips)
                stack(.explore) { ExploreScreen() }
                    .tabItem { tabLabel(.explore, icon: "compass") }
                    .tag(PrimaryTab.explore)
                stack(.passport) { PassportScreen() }
                    .tabItem { tabLabel(.passport, icon: "stamp") }
                    .tag(PrimaryTab.passport)
            }
            .tint(Ink.accentInk)

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
                    .animation(.easeInOut(duration: 0.25), value: hideSplash)
                    .allowsHitTesting(!hideSplash)
                    .accessibilityIdentifier("splash")
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
        // A train tapped anywhere but Explore opens here, over the screen you're on (`Router.presentTrain`).
        .sheet(item: $router.trainRequest) { request in
            TrainDetailSheet(request: request)
                .environment(app)
                .environment(app.l10n)
                .environment(router)
                .preferredColorScheme(app.colorScheme)
        }
        .sheet(item: $router.ticketFile) { file in
            TicketImportSheet(file: file)
                .environment(app)
                .environment(app.l10n)
                .environment(router)
                .preferredColorScheme(app.colorScheme)
        }
        .onOpenURL { url in openURL(url) }
        .preferredColorScheme(app.colorScheme)
        .fullScreenCover(isPresented: Binding(get: { askAlerts && splashGone }, set: { askAlerts = $0 })) {
            AlertsIntro { askAlerts = false }
                .environment(app)
                .environment(app.l10n)
                .preferredColorScheme(app.colorScheme)
        }
        // The end of a journey: held back until the splash is gone and the Add sheet is closed.
        .fullScreenCover(item: Binding(
            get: { splashGone && router.addRequest == nil ? app.arrivals.pending : nil },
            set: { if $0 == nil { app.arrivals.dismiss() } }
        )) { moment in
            ArrivalScreen(moment: moment)
                .environment(app)
                .environment(app.l10n)
                .environment(router)
        }
        // Alerts: tell the server this phone's address whenever it changes or alerts are switched on.
        .task(id: "\(scenePhase == .active)|\(app.settings.notify)|\(app.notifications.token ?? "")|\(app.notifications.startToken ?? "")") {
            guard scenePhase == .active else { return }
            await app.notifications.refresh()
            await app.notifications.sync(app.client, enabled: app.settings.notify)
            LiveActivityManager.shared.resume()
        }
        // Tapping an alert opens what it is about. On a cold start the tap arrives before this view does, so it is
        // read when the view appears too.
        .onAppear {
            openAlert()
            #if DEBUG
            // `-url <clack://...>` opens a link as if it had been tapped.
            let args = CommandLine.arguments
            if let at = args.firstIndex(of: "-url"), at + 1 < args.count, let url = URL(string: args[at + 1]),
               let link = DeepLink.parse(url) {
                router.open(link, app: app)
            }
            // `-simulateJourney <seconds>` runs the Debug trip card journey (TestAlertsModel.launch).
            _ = TestAlertsModel.launch
            #endif
        }
        .onChange(of: app.notifications.openRequest) { _, _ in openAlert() }
        // Watches for a journey ending while the app is in front.
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await app.arrivals.run(app)
        }
        // Anything the person opens or switches before the landing rule has decided cancels it. (A zero-distance drag
        // over the whole app did this before; it took taps from the tab bar, the segmented control and menus.)
        .modifier(TouchWatch(router: router))
        .task {
            // The flip takes about 0.7 s; the splash is gone by about 1 s.
            try? await Task.sleep(for: .milliseconds(700))
            #if DEBUG
            // `-holdSplash` keeps the splash on screen, to look at it.
            if CommandLine.arguments.contains("-holdSplash") { return }
            #endif
            // The logos get a moment more (0.3 s at most, and none if the load failed); a badge without its logo yet
            // shows initials and the logo fades in.
            var waited = 0
            while app.state != .failed && !app.logosSettled && waited < 3 {
                try? await Task.sleep(for: .milliseconds(100))
                waited += 1
            }
            splashMinDone = true
        }
        .onChange(of: hideSplash) { _, hide in
            guard hide else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                splashGone = true
            }
        }
        .task { await land() }
        #if DEBUG
        // `-ticket <path>` opens a file as if it had been shared to Clack.
        .task {
            if let at = CommandLine.arguments.firstIndex(of: "-ticket"), at + 1 < CommandLine.arguments.count {
                try? await Task.sleep(for: .seconds(2))
                openTicket(URL(fileURLWithPath: CommandLine.arguments[at + 1]))
            }
        }
        #endif
    }

    private func openAlert() {
        guard let link = app.notifications.openRequest else { return }
        app.notifications.openRequest = nil
        router.open(link, app: app)
    }

    /// A `clack://` link (a widget, the trip card) opens its screen; one the app doesn't know opens nothing. Anything
    /// else is a file shared to Clack.
    private func openURL(_ url: URL) {
        if url.scheme?.lowercased() == DeepLink.scheme {
            if let link = DeepLink.parse(url) { router.open(link, app: app) }
            return
        }
        openTicket(url)
    }

    /// A file shared to Clack ("Open in Clack"): copied at once, since the system's copy may go away, then read.
    private func openTicket(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)")
        guard (try? FileManager.default.copyItem(at: url, to: copy)) != nil else { return }
        router.addRequest = nil
        router.ticketFile = TicketFile(url: copy, name: url.lastPathComponent)
    }

    /// A tab's label: its name and its Lucide icon (the thin cut, as before).
    private func tabLabel(_ tab: PrimaryTab, icon: String) -> some View {
        Label {
            Text(app.l10n.t("nav.\(tab.rawValue)"))
        } icon: {
            Image("lucide-\(icon)-thin", bundle: ClackDesignBundle.bundle).renderingMode(.template)
        }
    }

    /// One tab's stack: its root screen, and whatever has been pushed onto it (kept when you switch tabs).
    private func stack<Root: View>(_ tab: PrimaryTab, @ViewBuilder root: () -> Root) -> some View {
        NavigationStack(path: Binding(get: { router.path(for: tab) }, set: { router.setPath($0, for: tab) })) {
            root()
                .appDestinations()
        }
        .modifier(NoBottomEdgeEffect())
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
            let welcomeDue = FirstRun.holdsLanding(seen: UserDefaults.standard.bool(forKey: FirstRun.welcomeSeenKey), legs: legs.count)
            await app.notifications.refresh()
            // Clack's alerts switch comes with the settings: wait for them (a failed load says nothing).
            while app.state == .loading { try? await Task.sleep(for: .milliseconds(100)) }
            askAlerts = app.state != .failed && FirstRun.showsAlertsIntro(
                notDetermined: app.notifications.authorization == .notDetermined,
                allowedButOff: app.notifications.authorization == .authorized && !app.settings.notify,
                introSeen: UserDefaults.standard.bool(forKey: FirstRun.alertsIntroSeenKey), welcomeDue: welcomeDue
            )
            // A new phone stays on Trips for the welcome.
            if welcomeDue { return }
            let tab = Landing.resolve(
                legs: legs.map(Landing.LegTimes.init), now: Date.now.timeIntervalSince1970 * 1000, lastTab: lastTab
            )
            if !router.touched, tab != .trips, router.tab == .trips { router.tab = tab }
        } catch {
            if !router.touched, let lastTab, lastTab != .trips, router.tab == .trips { router.tab = lastTab }
        }
    }
}

/// Notes that the person has done something (switched a tab or a list, opened a screen or the Add sheet), so the
/// landing rule leaves them where they are; and remembers the tab.
private struct TouchWatch: ViewModifier {
    let router: Router

    func body(content: Content) -> some View {
        content
            .onChange(of: router.tab) { _, tab in
                Landing.saveLastTab(tab)
                router.touched = true
            }
            .onChange(of: router.tripsTab) { router.touched = true }
            .onChange(of: router.tripsPath.count + router.explorePath.count + router.passportPath.count) { router.touched = true }
            .onChange(of: router.addRequest == nil) { router.touched = true }
    }
}

/// No dark fade behind the tab bar (owner, 2026-10-25: "a black box outside the bubble"): content runs to the bottom
/// edge and only the glass bubble has a backing. iOS 26 and later; nothing to hide before.
private struct NoBottomEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            content
        }
    }
}
