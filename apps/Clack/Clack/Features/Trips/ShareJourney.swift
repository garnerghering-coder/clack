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
    /// The link was just switched off: said in words, since nothing else changes on screen.
    var stopped = false
    /// What a live link does, asked before the first one is made (once per phone).
    var explaining = false
    static let explainedKey = "clack.share.explained"

    var isShared: Bool { token != nil }

    func refresh(_ app: AppModel, journeyId: String?, legId: String) async {
        let link = try? await app.client.currentShare(journeyId: journeyId, legId: journeyId == nil ? legId : nil)
        token = link?.token
    }

    /// Makes the link (or finds the one there is) and opens the share sheet with it, the words saying the whole
    /// journey and when it arrives (user test 2026-11-07: "I wanted 'Dad arrives Oslo S 15:47, Vy 388' and I got a
    /// sentence about a town she's never heard of").
    func share(_ app: AppModel, journeyId: String?, legId: String, legs: [Leg]) async {
        failed = false
        do {
            let link = try await app.client.shareJourney(journeyId: journeyId, legId: journeyId == nil ? legId : nil)
            guard let text = link.url, let url = URL(string: text) else { failed = true; return }
            token = link.token
            Usage.shared.count(.feature, "share.make")
            sheet = ShareSheetItem(text: Self.text(app, legs: legs), url: url)
        } catch {
            failed = true
        }
    }

    /// "Jönköping C → Oslo S, Sat 7 Nov. Arrives 15:47 (Vy 388). Follow my train live:"
    static func text(_ app: AppModel, legs: [Leg]) -> String {
        let sorted = legs.sorted { ($0.schedDep?.ms ?? 0) < ($1.schedDep?.ms ?? 0) }
        guard let first = sorted.first, let last = sorted.last else { return app.l10n.t("share.textPlain") }
        let from = first.origin?.name ?? "", to = last.destination?.name ?? ""
        let tz = last.destination?.tz ?? first.origin?.tz ?? Format.defaultZone
        let arrival = last.actualArr?.ms ?? last.live?.arrivalEta?.ms ?? last.schedArr?.ms
        let train = [last.operator?.name, last.trainNumber].compactMap { $0 }.joined(separator: " ")
        guard let dep = first.schedDep?.ms, let arrival else { return app.l10n.t("share.text", ["from": from, "to": to]) }
        return app.l10n.t(train.isEmpty ? "share.textArrivesNoTrain" : "share.textArrives", [
            "from": from, "to": to, "day": Format.day(dep, tz: first.origin?.tz ?? tz, language: app.settings.language),
            "time": Format.time(arrival, tz: tz, clock: app.settings.clock), "train": train,
        ])
    }

    /// Switches the link off: it stops working and its followers stop hearing about the journey.
    func stop(_ app: AppModel) async {
        guard let token else { return }
        try? await app.client.stopSharing(token: token)
        self.token = nil
        stopped = true
    }
}

extension View {
    /// Presents the share sheet for a `JourneyShare`, its failure, and the word that sharing has stopped.
    func journeyShareSheet(_ share: JourneyShare, l10n: L10n) -> some View {
        @Bindable var share = share
        return sheet(item: $share.sheet) { item in
            ActivitySheet(items: [item.text, item.url]).presentationDetents([.medium, .large])
        }
        .alert(l10n.t("share.failed"), isPresented: $share.failed) {
            Button(l10n.t("common.close"), role: .cancel) {}
        }
        .alert(l10n.t("share.stoppedTitle"), isPresented: $share.stopped) {
            Button(l10n.t("common.close"), role: .cancel) {}
        } message: {
            Text(l10n.t("share.stoppedBody"))
        }
    }
}

/// The share control of a trip or a journey, in the navigation bar (the system draws the button). Tapping makes the
/// link and opens the share sheet, after saying once what a live link is; while the journey is shared it is a menu
/// with "Stop sharing" too.
struct ShareControl: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let share: JourneyShare
    let journeyId: String?
    let legId: String
    /// The trains the words describe: the whole journey when there is one.
    let legs: [Leg]

    var body: some View {
        @Bindable var share = share
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
        .accessibilityLabel(l10n.t("share.action"))
        .accessibilityIdentifier("share.journey")
        // Plain words before the first live link (user test 2026-11-07: nobody knew a press had started ongoing
        // sharing). Once per phone.
        .alert(l10n.t("share.explainTitle"), isPresented: $share.explaining) {
            Button(l10n.t("share.explainGo")) {
                UserDefaults.standard.set(true, forKey: JourneyShare.explainedKey)
                Task { await share.share(app, journeyId: journeyId, legId: legId, legs: legs) }
            }
            Button(l10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(l10n.t("share.explainBody"))
        }
    }

    private func start() {
        if !share.isShared && !UserDefaults.standard.bool(forKey: JourneyShare.explainedKey) {
            share.explaining = true
            return
        }
        Task { await share.share(app, journeyId: journeyId, legId: legId, legs: legs) }
    }

    private var glyph: some View {
        LucideIcon(name: "system:square.and.arrow.up", size: 18)
    }
}

/// On a trip's page while its live link is out: that it is, and the way to stop it.
struct SharingRow: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let share: JourneyShare

    var body: some View {
        HStack(spacing: 8) {
            LucideIcon(name: "link", size: 16).foregroundStyle(Ink.accentInk)
            Text(l10n.t("share.sharingNow")).clack(.caption).foregroundStyle(Ink.text2)
            Spacer(minLength: 8)
            Button(l10n.t("share.stop")) { Task { await share.stop(app) } }.buttonStyle(LinkButtonStyle())
        }
        .padding(.horizontal, 12)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .hairlineBorder(radius: Radius.input)
        .accessibilityElement(children: .combine)
    }
}
