//
//  ClackApp.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

@main
struct ClackApp: App {
    @State private var app = AppModel()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                // `-design` opens the design gallery straight away (docs/SWIFT_PORT.md step 4).
                if CommandLine.arguments.contains("-design") {
                    NavigationStack { DesignGalleryView() }
                } else {
                    RootView()
                }
                #else
                RootView()
                #endif
            }
            .environment(app)
            .environment(app.l10n)
            .task { await app.load() }
            .task { OfflineMaps.configure() }
        }
    }
}
