//
//  TripsScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// What the Trips screen holds: the legs, the follows, and live updates merged into the legs as they arrive.
@MainActor
@Observable
final class TripsModel {
    private(set) var legs: [Leg]?
    private(set) var failed = false
    private(set) var follows: [Follow] = []
    /// The kept details (stops and route) of the trips in the next day and a half, so they can be estimated offline.
    private var details: [String: LegDetail] = [:]

    func load(_ client: APIClient) async {
        failed = false
        do {
            let first = legs == nil
            legs = try await client.legs()
            // Asked on a launch where a trip has already ended, not the moment one is added (user test 2026-11-07:
            // the dialog came up on top of adding a past trip, and once mid long-press after Settings).
            if first { UsageAsk.shared.check(legs ?? []) }
        } catch {
            failed = true
        }
    }

    /// Fetches (online) or reads from the phone's copy (offline) the details of trips that are running or leave within 36 hours.
    func loadDetails(_ client: APIClient, now: Double) async {
        for leg in legs ?? [] where !leg.canceled && leg.actualArr == nil {
            guard let dep = leg.schedDep?.ms, let arr = leg.schedArr?.ms, dep - now < 36 * 3_600_000, arr > now - 3_600_000 else { continue }
            if let detail = try? await client.leg(leg.id) { details[leg.id] = detail }
        }
    }

    /// The legs with an estimate in place of live state that has stopped coming (or that never came, offline).
    func estimated(_ all: [Leg], offline: Bool, now: Double) -> [Leg] {
        all.map { leg in
            guard let estimate = OfflineEstimate.live(for: leg, detail: details[leg.id], offline: offline, now: now) else { return leg }
            var copy = leg
            copy.live = estimate
            return copy
        }
    }

    func loadFollows(_ client: APIClient) async {
        follows = (try? await client.follows()) ?? []
    }

    /// A live tick: merge the new live state into the list, so the featured card moves without a reload.
    func listen(_ hub: LiveHub) async {
        for await update in hub.updates() {
            guard var all = legs, let index = all.firstIndex(where: { $0.id == update.legId }) else { continue }
            all[index].live = update.live
            legs = all
        }
    }

    /// Deletes a trip from the list (the hold menu on a card); the list is read again by the caller.
    func delete(_ leg: Leg, _ client: APIClient) async -> Bool {
        guard (try? await client.deleteLeg(leg.id)) != nil else { return false }
        TicketStore.shared.detach(legId: leg.id)
        legs = legs?.filter { $0.id != leg.id }
        return true
    }

    func answer(_ leg: Leg, _ answer: RideAnswer, _ client: APIClient) async {
        guard let detail = try? await client.answerRide(leg.id, answer), var all = legs,
              let index = all.firstIndex(where: { $0.id == leg.id }) else { return }
        all[index].ride = detail.leg.ride
        all[index].rideReason = detail.leg.rideReason
        legs = all
    }
}

enum TripsTab: String, Hashable {
    case upcoming, past
}


/// Trips home (DESIGN §4, product brief §5): Upcoming | Past. Upcoming leads with one featured card (route map on
/// top, the journey under it) for the train you're on, else the next one; the rest are compact rows. Past is grouped
/// by month.
struct TripsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @State private var model = TripsModel()
    /// The welcome has been shown (`FirstRun`).
    @AppStorage(FirstRun.welcomeSeenKey) private var welcomeSeen = false
    /// A trip held in the list, about to be deleted (the alert asks first).
    @State private var deleting: Leg?

    var body: some View {
        // The partition depends on the clock; once a minute is as often as anything on this screen changes class.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date.timeIntervalSince1970 * 1000)
        }
        .toolbar(.hidden, for: .navigationBar)
        // The first time, over the empty list: what Clack does and how to start.
        .overlay {
            // Also when the list couldn't be fetched yet on a new phone: the welcome, not a red "Couldn't load" as
            // the first screen (user test 2026-11-07: two testers' first screen, with the dev server restarting).
            if FirstRun.showsWelcome(seen: welcomeSeen, legs: model.legs?.count) || (!welcomeSeen && model.failed && model.legs == nil) {
                WelcomeView { welcomeSeen = true }
                    .onDisappear { welcomeSeen = true }
                    .transition(.opacity)
            }
        }
        // Trips already there (an update, or a new phone with the same id): no welcome, now or later.
        .onChange(of: model.legs?.isEmpty) { _, empty in if empty == false { welcomeSeen = true } }
        .task(id: app.tripsVersion) { await model.load(app.client) }
        .alert(l10n.t("detail.deleteRouteConfirm", ["route": "\(deleting?.origin?.name ?? "") → \(deleting?.destination?.name ?? "")"]), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(l10n.t("detail.delete"), role: .destructive) {
                if let leg = deleting {
                    Task {
                        if await model.delete(leg, app.client) {
                            UINotificationFeedbackGenerator().notificationOccurred(.warning)
                            app.tripsChanged()
                        }
                    }
                }
            }
            Button(l10n.t("common.cancel"), role: .cancel) {}
        }
        .task(id: app.isOffline) { await model.loadDetails(app.client, now: Date.now.timeIntervalSince1970 * 1000) }
        .task { await model.loadFollows(app.client) }
        .task { await model.listen(app.live) }
        // The journeys you follow: fetched now and kept fresh while Trips shows.
        .task {
            while !Task.isCancelled {
                await app.followed.load(app)
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    @ViewBuilder
    private func content(now: Double) -> some View {
        @Bindable var router = router
        let shown = model.legs.map { model.estimated($0, offline: app.isOffline, now: now) }
        let legs = shown ?? []
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)
        Page {
            PageHeader(title: l10n.t("trips.title")) {
                HStack(spacing: 8) {
                    IconButton(icon: "plus", label: l10n.t("nav.addTrain")) { router.openAdd() }
                    SettingsLink()
                }
            }
            TripsSegmentedControl(
                selection: $router.tripsTab,
                options: [(TripsTab.upcoming, l10n.t("trips.upcoming")), (TripsTab.past, l10n.t("trips.past"))]
            )
            if model.failed {
                Banner(kind: .error) {
                    HStack(spacing: 8) {
                        Text(l10n.t("trips.loadError"))
                        Button(l10n.t("trips.retry")) { Task { await model.load(app.client) } }.buttonStyle(LinkButtonStyle())
                    }
                }
                .countsError("trips.load")
            }
            if router.tripsTab == .upcoming { FollowedJourneysSection() }
            if model.legs == nil && !model.failed {
                VStack(spacing: 12) {
                    Skeleton()
                    Skeleton()
                    Skeleton()
                }
            }
            if let all = shown {
                if all.isEmpty {
                    emptyState
                    if router.tripsTab == .upcoming { FollowingSection(follows: unshared(model.follows)) }
                } else if router.tripsTab == .upcoming {
                    upcomingTab(all, upcoming: upcoming, hero: hero)
                } else {
                    pastTab(past)
                }
            }
        }
        .refreshable {
            await model.load(app.client)
            await model.loadFollows(app.client)
        }
    }

    /// The trains you follow on their own: not the ones that belong to a journey you follow (its card has them).
    private func unshared(_ follows: [Follow]) -> [Follow] {
        let covered = Set(app.followed.journeys.flatMap(SharedLogic.followBodies).map { "\($0.trainNumber)|\($0.serviceDate)" })
        return follows.filter { !covered.contains("\($0.trainNumber)|\($0.serviceDate)") }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            DottedLine()
            Text(l10n.t("trips.emptyTitle")).clack(.headline).foregroundStyle(Ink.text)
            Text(l10n.t("trips.emptyBody")).clack(.body).foregroundStyle(Ink.text2).multilineTextAlignment(.center)
            EmptyActions()
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 48)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func upcomingTab(_ all: [Leg], upcoming: [Leg], hero: (leg: Leg, state: TripsLogic.HeroState)?) -> some View {
        // The featured card carries its whole journey; every other journey is one card, as in Past (owner, 2026-10-25).
        let heroJourney = hero.map { TripsLogic.journey(of: $0.leg, in: all) } ?? []
        if let hero {
            FeaturedCard(
                leg: hero.leg, state: hero.state, next: hero.state == .active ? TripsLogic.nextInJourney(all, after: hero.leg) : nil,
                journey: heroJourney
            )
        } else {
            NothingAhead()
        }
        if hero != nil && upcoming.isEmpty { NothingAhead() }
        let shown = Set(heroJourney.map(\.id))
        let items = TripsLogic.journeys(upcoming.filter { !shown.contains($0.id) })
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.element.first?.id) { index, item in
                // A layover line between separate trips that still meet at a station.
                let before = index == 0 ? heroJourney.last : items[index - 1].last
                if item.count == 1, let before, TripsLogic.meets(before, item[0]) { Layover(a: before, b: item[0]) }
                if item.count > 1 { JourneyCard(legs: item) } else { LegRow(leg: item[0], upcoming: true).contextMenu { holdMenu(item[0]) } }
            }
        }
        FollowingSection(follows: unshared(model.follows))
    }

    /// Holding a trip in the list (user test 2026-11-07: "deleting a trip is open → … → Delete"; "no context menu
    /// anywhere"): open it, or delete it.
    @ViewBuilder
    private func holdMenu(_ leg: Leg) -> some View {
        Button { router.push(.trip(leg.id)) } label: { Label(l10n.t("add.viewTrip"), systemImage: "arrow.up.right") }
        Button(role: .destructive) { deleting = leg } label: { Label(l10n.t("detail.delete"), systemImage: "trash") }
    }

    @ViewBuilder
    private func pastTab(_ past: [Leg]) -> some View {
        ForEach(past.filter { $0.ride == .review }) { leg in
            ReviewCard(leg: leg) { answer in await model.answer(leg, answer, app.client) }
        }
        if past.isEmpty { Text(l10n.t("trips.noPast")).clack(.body).foregroundStyle(Ink.text2) }
        ForEach(TripsLogic.months(past, language: app.settings.language), id: \.label) { month in
            Section {
                VStack(spacing: 8) {
                    ForEach(month.items, id: \.first?.id) { item in
                        if item.count > 1 { JourneyCard(legs: item) } else { LegRow(leg: item[0]).contextMenu { holdMenu(item[0]) } }
                    }
                }
            } header: {
                Text(month.label)
                    .clack(.sectionHeader).foregroundStyle(Ink.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12).padding(.bottom, 8)
                    .background(Ink.bg)
            }
        }
    }
}
