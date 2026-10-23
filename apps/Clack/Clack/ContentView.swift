//
//  ContentView.swift
//  Clack
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        LegsListView()
    }
}

#Preview {
    ContentView()
        .environment(AppModel())
}
