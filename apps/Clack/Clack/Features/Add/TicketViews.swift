//
//  TicketViews.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// "Buy ticket at sj.se" with the journey to search for underneath. Nothing when the operator has no site
/// (docs/swift-port/SCREENS.md §3.7). Buying happens on the operator's own site: no checkout, payments or affiliate
/// links in Clack.
struct BuyTicket: View {
    @Environment(L10n.self) private var l10n
    @Environment(\.openURL) private var openURL
    let trip: TicketTrip
    /// Already one of your trips: nothing to offer when you come back.
    var inTrips = false

    /// Where the ticket is bought (shown on the button's return prompt).
    private static let site = "omio.com"

    var body: some View {
        if trip.to.time >= Date.now.timeIntervalSince1970 * 1000 {
            VStack(alignment: .leading, spacing: Space.xs) {
                Button {
                    // Only to offer adding it when you're back; never taken as a purchase.
                    if !inTrips, trip.tripKey != nil, trip.serviceDate != nil {
                        TicketPendingStore.write(TicketPending(trip: trip, at: Date.now.timeIntervalSince1970 * 1000, site: Self.site))
                    }
                    openURL(Config.omioURL)
                } label: {
                    HStack(spacing: Space.s) {
                        LucideIcon(name: "external-link", size: 16)
                        Text(l10n.t("tickets.buyOmio"))
                    }
                }
                .buttonStyle(.clack())
                // The affiliate relationship, said plainly next to the button.
                Text(l10n.t("tickets.omioNote")).clack(.caption).foregroundStyle(Ink.text2)
            }
            .padding(.top, Space.s)
        }
    }
}

/// What the ticket prompt is showing, shared by the app shell so the prompt can be drawn inside the tab you're on
/// (above its tab bar) without three tabs each holding a copy.
@MainActor
@Observable
final class TicketReturnState {
    enum Phase { case ask, saving, added, already, failed }

    var offer: TicketPending?
    var phase = Phase.ask
}

/// Back from an operator's site: offer (once) to add that train to your trips. Drawn in the tab that's showing; its
/// state is the shell's `TicketReturnState`.
struct TicketReturnPrompt: View {
    typealias Phase = TicketReturnState.Phase

    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(TicketReturnState.self) private var state
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var offer: TicketPending? {
        get { state.offer }
        nonmutating set { state.offer = newValue }
    }

    private var phase: Phase {
        get { state.phase }
        nonmutating set { state.phase = newValue }
    }

    var body: some View {
        Group {
            if let offer { card(offer) }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            let now = Date.now.timeIntervalSince1970 * 1000
            if let pending = TicketPendingStore.offer(now: now) {
                offer = pending
                self.phase = .ask
            }
        }
    }

    private func card(_ offer: TicketPending) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if phase == .ask || phase == .saving {
                Text(l10n.t("tickets.backTitle", ["site": offer.site])).clack(.rowTitle).foregroundStyle(Ink.text)
                Text(l10n.t("tickets.backBody", ["from": offer.trip.from.name, "to": offer.trip.to.name, "train": offer.trip.trainNumber ?? ""]))
                    .clack(.caption).foregroundStyle(Ink.text2)
                HStack(spacing: Space.s) {
                    Spacer(minLength: 0)
                    Button(l10n.t("tickets.notNow")) { close() }.buttonStyle(.clack())
                    Button(l10n.t("tickets.addToTrips")) { Task { await add(offer) } }.buttonStyle(.clack(.primary)).disabled(phase == .saving)
                }
            } else {
                Text(phase == .added ? l10n.t("tickets.added") : phase == .already ? l10n.t("tickets.already") : l10n.t("tickets.failed"))
                    .clack(.rowTitle).foregroundStyle(Ink.text)
                HStack {
                    Spacer(minLength: 0)
                    Button(l10n.t("common.close")) { self.offer = nil }.buttonStyle(.clack())
                }
            }
        }
        .padding(Space.l)
        .frame(maxWidth: 560, alignment: .leading)
        .background(Ink.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, Space.m)
        .padding(.bottom, Space.m)
        // Reduce Motion: it fades in instead of sliding up.
        .transition(Motion.transition(from: .bottom, reduceMotion: reduceMotion))
        .accessibilityElement(children: .contain)
    }

    private func close() {
        TicketPendingStore.write(nil)
        offer = nil
    }

    private func add(_ offer: TicketPending) async {
        guard let key = offer.trip.tripKey, let date = offer.trip.serviceDate else { return close() }
        phase = .saving
        do {
            _ = try await app.client.createLeg(CreateLegBody(tripKey: key, serviceDate: date, fromSeq: offer.trip.from.seq, toSeq: offer.trip.to.seq))
            phase = .added
        } catch let error as APIError where error.status == 409 {
            phase = .already
        } catch {
            phase = .failed
        }
        TicketPendingStore.write(nil)
    }
}
