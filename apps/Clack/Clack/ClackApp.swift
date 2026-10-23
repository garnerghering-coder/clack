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
            ContentView()
                .environment(app)
                .task { await app.load() }
        }
    }
}
