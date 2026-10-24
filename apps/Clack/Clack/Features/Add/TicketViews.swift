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
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.openURL) private var openURL
    let trip: TicketTrip
    /// Already one of your trips: nothing to offer when you come back.
    var inTrips = false

    var body: some View {
        if let op = trip.operatorId.flatMap({ app.operatorsById[$0] }), let base = op.ticketUrl, trip.to.time >= Date.now.timeIntervalSince1970 * 1000 {
            let site = TicketPendingStore.host(of: base)
            let href = Tickets.href(base: base, deepLink: op.ticketDeepLink, trip: trip)
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    // Only to offer adding it when you're back; never taken as a purchase.
                    if !inTrips, trip.tripKey != nil, trip.serviceDate != nil {
                        TicketPendingStore.write(TicketPending(trip: trip, at: Date.now.timeIntervalSince1970 * 1000, site: site))
                    }
                    if let url = URL(string: href) { openURL(url) }
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: "external-link", size: 16)
                        Text(l10n.t("tickets.buyAt", ["site": site]))
                    }
                }
                .buttonStyle(.clack())
                Text(l10n.t("tickets.searchFor", [
                    "from": trip.from.name, "to": trip.to.name,
                    "day": Format.day(trip.from.time, tz: trip.from.tz, language: app.settings.language),
                    "time": Format.time(trip.from.time, tz: trip.from.tz, clock: app.settings.clock),
                    "train": [op.name, trip.trainNumber].compactMap { $0 }.joined(separator: " "),
                ]))
                .clack(.caption).foregroundStyle(Ink.text2)
            }
            .padding(.top, 8)
        }
    }
}

/// Back from an operator's site: offer (once) to add that train to your trips. Mounted once, in the app shell.
struct TicketReturnPrompt: View {
    enum Phase { case ask, saving, added, already, failed }

    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offer: TicketPending?
    @State private var phase = Phase.ask

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
        VStack(alignment: .leading, spacing: 8) {
            if phase == .ask || phase == .saving {
                Text(l10n.t("tickets.backTitle", ["site": offer.site])).clack(.rowTitle).foregroundStyle(Ink.text)
                Text(l10n.t("tickets.backBody", ["from": offer.trip.from.name, "to": offer.trip.to.name, "train": offer.trip.trainNumber ?? ""]))
                    .clack(.caption).foregroundStyle(Ink.text2)
                HStack(spacing: 8) {
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
        .padding(.vertical, 16).padding(.horizontal, 16)
        .frame(maxWidth: 560, alignment: .leading)
        .background(Ink.surface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        .clackShadow()
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        // Reduce Motion: it fades in instead of sliding up.
        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
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
