//
//  ClackApp.swift
//  Clack
//

import SwiftUI

@main
struct ClackApp: App {
    @State private var app = AppModel()

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
        }
    }
}
