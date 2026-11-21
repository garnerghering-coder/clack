//
//  NetworkLogScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Test builds only (Xcode and TestFlight, `BuildChannel`): the last requests and connection events (`NetworkLog`),
/// newest first, to see on the phone why a screen waited (a reused connection that never answered, a slow server, the
/// app leaving with a request open). Copy puts it all on the clipboard as text.
struct NetworkLogScreen: View {
    @Environment(L10n.self) private var l10n
    @State private var entries: [NetworkLog.Entry] = []

    var body: some View {
        Page {
            HStack(spacing: Space.m) {
                Button(l10n.t("networkLog.copy")) { UIPasteboard.general.string = NetworkLog.shared.text() }
                    .buttonStyle(.clack(wide: true))
                Button(l10n.t("networkLog.clear")) {
                    NetworkLog.shared.clear()
                    entries = []
                }
                .buttonStyle(.clack(wide: true))
            }
            Card(spacing: Space.s) {
                if entries.isEmpty {
                    Text(l10n.t("networkLog.empty")).clack(.body).foregroundStyle(Ink.text2)
                }
                ForEach(entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(entry.at, format: .dateTime.hour().minute().second()).clack(.micro).foregroundStyle(Ink.text2)
                        Text(entry.text).clack(.caption).foregroundStyle(Ink.text).monospaced()
                        if let connection = entry.connection {
                            Text(connection).clack(.caption).foregroundStyle(Ink.text2).monospaced()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
            }
        }
        .screenTitle(l10n.t("settings.test.networkLog"))
        // The log isn't observable (requests write to it from any thread): read it every second while open.
        .task {
            while !Task.isCancelled {
                let now = NetworkLog.shared.entries
                if now != entries { entries = now }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}
