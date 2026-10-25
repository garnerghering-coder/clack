//
//  ClackApp.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

@main
struct ClackApp: App {
    @State private var app: AppModel
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        let model = AppModel()
        _app = State(initialValue: model)
        // From launch, also a launch in the background: iOS wakes the app to hand over the address of a trip card the
        // server started, and that has to reach the server before any screen appears.
        LiveActivityManager.shared.observe { model.client }
        // A silent push or a background refresh can wake the app with no screen: they refresh through this model.
        BackgroundRefresh.shared.attach(model)
        // Usage counts and Apple's crash reports, sent to Clack's own server (Settings > Usage data turns it off).
        Usage.shared.start { model.client }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                // `-design` opens the design gallery straight away (docs/SWIFT_PORT.md step 4).
                if CommandLine.arguments.contains("-design") {
                    NavigationStack { DesignGalleryView() }
                } else if CommandLine.arguments.contains("-activityGallery") {
                    // The trip card's faces in the island's shapes; `-simulateJourney 8` runs one on the island itself.
                    NavigationStack { ActivityGalleryView() }
                } else if CommandLine.arguments.contains("-widgetGallery") {
                    // The Home Screen widgets at their true sizes (WidgetGalleryView).
                    WidgetGalleryView()
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
            .id(app.epoch)
            .environment(app)
            .environment(app.l10n)
            .task { await app.load() }
            .task { OfflineMaps.configure() }        }
    }
}
