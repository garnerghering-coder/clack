//
//  WelcomeView.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// The first time Clack opens (owner, 2026-10-25: value in the first minute, permissions only in context): the
/// wordmark, one line, and real trains leaving in the next hour that go into Trips with one tap, plus "Find a train".
/// No permission prompts here: location is asked only if they tap "Trains near you", alerts on a trip still ahead
/// (`AlertsPrompt`). Shown once (`FirstRun`).
struct WelcomeView: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let onDone: () -> Void
    @State private var trains: [SoonTrain]?
    /// The departures couldn't be fetched (said as such, not as "no trains").
    @State private var failed = false
    @State private var near = false
    @State private var adding: String?
    @State private var askingLocation = false
    @State private var locating = false
    @Environment(Toaster.self) private var toaster

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Wordmark(fontSize: 40).padding(.top, Space.xl)
                Text(l10n.t("firstRun.log")).clack(.body).foregroundStyle(Ink.text2).fixedSize(horizontal: false, vertical: true)
                // The search first, where the thumb goes (user test 2026-11-07: the brightest things were five Add
                // buttons for trains nobody was taking; the welcome moved under a finger as the list loaded).
                VStack(spacing: Space.m) {
                    Button {
                        onDone()
                        router.openAdd()
                    } label: {
                        Label { Text(l10n.t("firstRun.find")) } icon: { LucideIcon(name: "search", size: 18) }
                    }
                    .buttonStyle(.clack(.primary, wide: true))
                    Button(l10n.t("firstRun.skip")) { onDone() }.buttonStyle(LinkButtonStyle())
                }
                soon
            }
            // The scroll view's own safe area clears the floating tab bar (it was a fixed 120 pt before polish pass 1).
            .padding(.horizontal, Space.l).padding(.bottom, Space.xl)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Ink.bg)
        .task { await load() }
    }

    @ViewBuilder private var soon: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack {
                Text(l10n.t(near ? "firstRun.nearTitle" : "firstRun.soonTitle")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                Spacer(minLength: Space.s)
                // Asked only when tapped, after one sentence in Clack's words, then iOS's own prompt.
                if !near && !LocationModel.shared.denied {
                    Button {
                        if LocationModel.shared.allowed { Task { await loadNear() } } else { askingLocation = true }
                    } label: {
                        Label { Text(l10n.t("firstRun.nearYou")) } icon: { LucideIcon(name: "locate-fixed", size: 14) }
                    }
                    .buttonStyle(.clack(small: true))
                    .disabled(locating)
                }
            }
            if let trains {
                if failed {
                    // A failure is said as one, with a way to try again; never as "no trains".
                    ErrorStateView(message: l10n.t("firstRun.soonFailed"), retry: { await load() })
                } else if trains.isEmpty {
                    Text(l10n.t("firstRun.soonEmpty")).clack(.caption).foregroundStyle(Ink.text2)
                }
                ForEach(trains) { train in row(train) }
            } else {
                // Two rows shaped like the real ones, so the list doesn't move when the trains arrive.
                ForEach(0..<2, id: \.self) { _ in
                    Placeholder {
                        rowLayout(op: nil, title: "Stockholm C → Göteborg C", detail: "08:03–10:51 · SJ 523") { EmptyView() }
                    }
                }
            }
        }
        .motion(.appear, value: trains == nil)
        .alert(l10n.t("firstRun.nearAskTitle"), isPresented: $askingLocation) {
            Button(l10n.t("firstRun.nearAskYes")) { Task { await loadNear() } }
            Button(l10n.t("firstRun.skip"), role: .cancel) {}
        } message: {
            Text(l10n.t("firstRun.nearAskBody"))
        }
    }

    private func row(_ t: SoonTrain) -> some View {
        let op = t.operatorId.flatMap { app.operatorsById[$0] }
        let tz = TimeZone.current.identifier
        return rowLayout(
            op: op,
            title: "\(t.from.name) → \(t.to.name)",
            detail: Format.join([
                "\(Format.time(t.dep, tz: tz, clock: app.settings.clock))–\(Format.time(t.arr, tz: tz, clock: app.settings.clock))",
                [op?.name, t.trainNumber].compactMap { $0 }.joined(separator: " "),
            ])
        ) {
            Button {
                Task { await add(t) }
            } label: {
                if adding == t.id { ProgressView() } else { Text(l10n.t("firstRun.add")) }
            }
            // Secondary: these are offers, not the way in.
            .buttonStyle(.clack(small: true))
            .disabled(adding != nil)
            .accessibilityLabel(l10n.t("firstRun.addLabel", ["from": t.from.name, "to": t.to.name]))
        }
    }

    /// One suggested train: the badge, the route (two lines before it truncates), the times (never truncated), and
    /// the Add button. The placeholder draws the same layout, so nothing moves when the trains arrive.
    private func rowLayout<Trailing: View>(op: Operator?, title: String, detail: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        AdaptiveStack(horizontalAlignment: .leading, spacing: Space.m) {
            HStack(spacing: Space.m) {
                OperatorBadge(op: op, size: .medium)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(verbatim: title).clack(.rowTitle).foregroundStyle(Ink.text).lineLimit(2)
                    Text(verbatim: detail).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Space.s)
            trailing()
        }
        .padding(Space.m)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }

    private func load() async {
        // Already allowed: near you straight away, without asking anything.
        if LocationModel.shared.allowed, let here = await LocationModel.shared.current() {
            near = true
            let found = try? await app.client.trainsSoon(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
            failed = found == nil
            trains = found ?? []
            return
        }
        let found = try? await app.client.trainsSoon()
        failed = found == nil
        trains = found ?? []
    }

    /// The trains from the stations nearest you. Whatever happens is said: no position, nothing near, or a failure.
    private func loadNear() async {
        locating = true
        defer { locating = false }
        guard let here = await LocationModel.shared.current() else {
            if !LocationModel.shared.denied { toaster.show(l10n.t("firstRun.nearNoPosition"), isError: true) }
            return
        }
        do {
            let found = try await app.client.trainsSoon(lat: here.coordinate.latitude, lon: here.coordinate.longitude)
            if found.isEmpty {
                toaster.show(l10n.t("firstRun.nearEmpty"))
            } else {
                near = true
                failed = false
                trains = found
            }
        } catch {
            toaster.show(l10n.t("firstRun.soonFailed"), isError: true)
        }
    }

    /// Saves the whole run as a planned trip and opens it; a failure is said, and the row stays.
    private func add(_ t: SoonTrain) async {
        adding = t.id
        defer { adding = nil }
        guard let saved = try? await app.client.createLeg(t.body) else {
            toaster.show(l10n.t("liveAdd.failed"), isError: true)
            return
        }
        Usage.shared.count(.feature, "firstRun.addSuggested")
        app.tripsChanged()
        onDone()
        router.push(.trip(saved.id))
    }
}
