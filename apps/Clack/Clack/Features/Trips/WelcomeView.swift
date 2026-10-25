//
//  WelcomeView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The first time Clack opens (owner, 2026-10-25: value in the first minute, permissions only in context): the
/// wordmark, one line, and real trains leaving in the next hour that go into Trips with one tap, plus "Find your train".
/// No permission prompts here: location is asked only if they tap "Trains near you", alerts on a trip still ahead
/// (`AlertsPrompt`). Shown once (`FirstRun`).
struct WelcomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let onDone: () -> Void
    @State private var trains: [SoonTrain]?
    @State private var near = false
    @State private var adding: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Wordmark(fontSize: 40).padding(.top, 24)
                Text(l10n.t("firstRun.log")).clack(.body).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
                soon
                VStack(spacing: 12) {
                    Button {
                        onDone()
                        router.openAdd()
                    } label: {
                        Label { Text(l10n.t("firstRun.find")) } icon: { LucideIcon(name: "search", size: 18) }
                    }
                    .buttonStyle(.clack(.primary, wide: true))
                    Button(l10n.t("firstRun.skip")) { onDone() }.buttonStyle(LinkButtonStyle())
                }
                .padding(.top, 8)
            }
            // Room under "Not now" for the floating tab bar.
            .padding(.horizontal, 16).padding(.bottom, 120)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Ink.bg)
        .task { await load() }
    }

    @ViewBuilder private var soon: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.t(near ? "firstRun.nearTitle" : "firstRun.soonTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Spacer(minLength: 8)
                // Asked only when tapped: iOS's own prompt, then the trains from the stations nearest you.
                if !near && !LocationModel.shared.denied {
                    Button {
                        Task { await loadNear() }
                    } label: {
                        Label { Text(l10n.t("firstRun.nearYou")) } icon: { LucideIcon(name: "locate-fixed", size: 14) }
                    }
                    .buttonStyle(.clack(small: true))
                }
            }
            if let trains {
                if trains.isEmpty {
                    Text(l10n.t("firstRun.soonEmpty")).clack(.caption).foregroundStyle(Ink.text2)
                }
                ForEach(trains) { train in row(train) }
            } else {
                Skeleton(height: 64)
                Skeleton(height: 64)
            }
        }
    }

    private func row(_ t: SoonTrain) -> some View {
        let op = t.operatorId.flatMap { app.operatorsById[$0] }
        let tz = TimeZone.current.identifier
        return HStack(spacing: 12) {
            OperatorBadge(op: op, size: .medium)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(t.from.name) → \(t.to.name)").clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(1)
                Text(Format.join([
                    "\(Format.time(t.dep, tz: tz, clock: app.settings.clock))–\(Format.time(t.arr, tz: tz, clock: app.settings.clock))",
                    [op?.name, t.trainNumber].compactMap { $0 }.joined(separator: " "),
                ])).clack(.caption).foregroundStyle(Ink.text2).lineLimit(1)
            }
            Spacer(minLength: 8)
            Button {
                Task { await add(t) }
            } label: {
                if adding == t.id { ProgressView() } else { Text(l10n.t("firstRun.add")) }
            }
            .buttonStyle(.clack(.primary, small: true))
            .disabled(adding != nil)
            .accessibilityLabel(l10n.t("firstRun.addLabel", ["from": t.from.name, "to": t.to.name]))
        }
        .padding(12)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    private func load() async {
        // Already allowed: near you straight away, without asking anything.
        if LocationModel.shared.allowed, let here = await LocationModel.shared.current() {
            near = true
            trains = (try? await app.client.trainsSoon(lat: here.coordinate.latitude, lon: here.coordinate.longitude)) ?? []
            return
        }
        trains = (try? await app.client.trainsSoon()) ?? []
    }

    private func loadNear() async {
        guard let here = await LocationModel.shared.current() else { return }
        let found = (try? await app.client.trainsSoon(lat: here.coordinate.latitude, lon: here.coordinate.longitude)) ?? []
        if !found.isEmpty {
            near = true
            trains = found
        }
    }

    /// Saves the whole run as a planned trip and opens it.
    private func add(_ t: SoonTrain) async {
        adding = t.id
        defer { adding = nil }
        guard let saved = try? await app.client.createLeg(t.body) else { return }
        Usage.shared.count(.feature, "firstRun.addSuggested")
        app.tripsChanged()
        onDone()
        router.push(.trip(saved.id))
    }
}
