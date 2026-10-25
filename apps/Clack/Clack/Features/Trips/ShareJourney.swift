//
//  ShareJourney.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI
import UIKit

/// What the system share sheet is given for a journey: a line of words and the link.
struct ShareSheetItem: Identifiable {
    let text: String
    let url: URL
    var id: String { url.absoluteString }
}

/// The system's share sheet (Messages, Mail, copy…).
struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

/// Sharing one journey by link (owner, 2026-10-25): makes the link, hands it to the share sheet, and can switch it off.
/// The screen that shows it holds one of these, loads `refresh` when it opens and presents `sheet`.
@MainActor
@Observable
final class JourneyShare {
    /// The live link's token, when the journey is shared now.
    private(set) var token: String?
    var sheet: ShareSheetItem?
    var failed = false

    var isShared: Bool { token != nil }

    func refresh(_ app: AppModel, journeyId: String?, legId: String) async {
        let link = try? await app.client.currentShare(journeyId: journeyId, legId: journeyId == nil ? legId : nil)
        token = link?.token
    }

    /// Makes the link (or finds the one there is) and opens the share sheet with it.
    func share(_ app: AppModel, journeyId: String?, legId: String, from: String, to: String) async {
        failed = false
        do {
            let link = try await app.client.shareJourney(journeyId: journeyId, legId: journeyId == nil ? legId : nil)
            guard let text = link.url, let url = URL(string: text) else { failed = true; return }
            token = link.token
            Usage.shared.count(.feature, "share.make")
            sheet = ShareSheetItem(text: app.l10n.t("share.text", ["from": from, "to": to]), url: url)
        } catch {
            failed = true
        }
    }

    /// Switches the link off: it stops working and its followers stop hearing about the journey.
    func stop(_ app: AppModel) async {
        guard let token else { return }
        try? await app.client.stopSharing(token: token)
        self.token = nil
    }
}

extension View {
    /// Presents the share sheet for a `JourneyShare`, and its failure.
    func journeyShareSheet(_ share: JourneyShare, l10n: L10n) -> some View {
        @Bindable var share = share
        return sheet(item: $share.sheet) { item in
            ActivitySheet(items: [item.text, item.url]).presentationDetents([.medium, .large])
        }
        .alert(l10n.t("share.failed"), isPresented: $share.failed) {
            Button(l10n.t("common.close"), role: .cancel) {}
        }
    }
}

/// The share control of a trip or a journey: a round button (the system's glass in a bar, the map's glass over a map).
/// Tapping makes the link and opens the share sheet; while the journey is shared it is a menu with "Stop sharing" too.
struct ShareControl: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let share: JourneyShare
    let journeyId: String?
    let legId: String
    let from: String
    let to: String
    /// Over a map: drawn like the map's other buttons. In a navigation bar the system draws it.
    var overMap = false

    var body: some View {
        Group {
            if share.isShared {
                Menu {
                    Button { start() } label: { Label(l10n.t("share.action"), systemImage: "square.and.arrow.up") }
                    Button(role: .destructive) { Task { await share.stop(app) } } label: { Label(l10n.t("share.stop"), systemImage: "xmark.circle") }
                } label: { glyph }
            } else {
                Button { start() } label: { glyph }
            }
        }
        .buttonStyle(.plain)
        .tint(Ink.text)
        .accessibilityLabel(l10n.t("share.action"))
        .accessibilityIdentifier("share.journey")
    }

    private func start() {
        Task { await share.share(app, journeyId: journeyId, legId: legId, from: from, to: to) }
    }

    @ViewBuilder
    private var glyph: some View {
        if overMap {
            MapButtonFace(icon: "share-2", pressed: share.isShared)
        } else {
            LucideIcon(name: "share-2", size: 18).foregroundStyle(Ink.text)
        }
    }
}
