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
    /// The list on screen is the phone's kept copy, not yet refreshed (with when it was last fresh).
    private(set) var savedAt: Double?
    private(set) var follows: [Follow] = []
    /// The kept details (stops and route) of the trips in the next day and a half, so they can be estimated offline.
    private var details: [String: LegDetail] = [:]

    func load(_ client: APIClient) async {
        failed = false
        // The kept copy first, so the list is there at once on a slow connection (owner, 2026-11-14: "give the user
        // stuff to have while the rest loads in"); the server's answer replaces it in place.
        if legs == nil, let kept: [Leg] = await client.saved(["legs"]) {
            legs = kept
            savedAt = SavedAt.at("legs")
        }
        do {
            let first = legs == nil
            legs = try await client.legs()
            savedAt = nil
            SavedAt.mark("legs")
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

    /// Deletes a trip: it leaves the list at once, and comes back if the server refuses (polish pass 1: the row
    /// waited for the server and a failure said nothing).
    func delete(_ leg: Leg, _ client: APIClient) async -> Bool {
        let before = legs
        legs = legs?.filter { $0.id != leg.id }
        guard (try? await client.deleteLeg(leg.id)) != nil else {
            legs = before
            return false
        }
        TicketStore.shared.detach(legId: leg.id)
        return true
    }

    /// Answers a trip's ride check; false when the server couldn't be reached.
    func answer(_ leg: Leg, _ answer: RideAnswer, _ client: APIClient) async -> Bool {
        guard let detail = try? await client.answerRide(leg.id, answer) else { return false }
        guard var all = legs, let index = all.firstIndex(where: { $0.id == leg.id }) else { return true }
        all[index].ride = detail.leg.ride
        all[index].rideReason = detail.leg.rideReason
        legs = all
        return true
    }
}

/// The places Trips can be scrolled to from elsewhere.
enum TripsAnchor: String, Hashable {
    case reviews, history
}


/// Trips home (DESIGN §4; one scroll since polish pass 1, designer 2026-11-14): the train you're on, or the next one,
/// pinned at the top as the featured card; then the other trips ahead as compact rows; trips to check; then history
/// by month, each month with its totals. No Upcoming/Past switch: it was louder than the trips it filtered.
struct TripsScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(Toaster.self) private var toaster
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
        .statusBarBackdrop()
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
        .motion(.appear, value: welcomeSeen)
        // Trips already there (an update, or a new phone with the same id): no welcome, now or later.
        .onChange(of: model.legs?.isEmpty) { _, empty in if empty == false { welcomeSeen = true } }
        .task(id: app.tripsVersion) { await model.load(app.client) }
        .alert(l10n.t("detail.deleteRouteConfirm", ["route": "\(deleting?.origin?.name ?? "") → \(deleting?.destination?.name ?? "")"]), isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button(l10n.t("detail.delete"), role: .destructive) {
                if let leg = deleting {
                    Task {
                        if await model.delete(leg, app.client) {
                            app.tripsChanged()
                        } else {
                            toaster.show(l10n.t("trips.deleteFailed"), isError: true)
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
        let shown = model.legs.map { model.estimated($0, offline: app.isOffline, now: now) }
        let legs = shown ?? []
        let (upcoming, past) = TripsLogic.partition(legs, now: now)
        let hero = TripsLogic.hero(upcoming: upcoming, past: past, now: now)
        ScrollViewReader { scroller in
            Page {
                PageHeader(title: l10n.t("trips.title")) {
                    HStack(spacing: Space.s) {
                        IconButton(icon: "plus", label: l10n.t("nav.addTrain")) { router.openAdd() }
                        SettingsLink()
                    }
                }
                // Kept trips on screen and the refresh failed: said with their age, and a way to try again; never
                // "Couldn't load your trips" over a full list (polish pass 1).
                if model.failed, model.legs != nil {
                    HStack(spacing: Space.s) {
                        FreshnessLine(updatedAt: model.savedAt ?? SavedAt.at("legs") ?? Date.now.timeIntervalSince1970 * 1000, failed: true, clock: app.settings.clock)
                        Spacer(minLength: Space.s)
                        Button(l10n.t("common.tryAgain")) { Task { await model.load(app.client) } }.buttonStyle(LinkButtonStyle())
                    }
                    .countsError("trips.load")
                } else if model.failed {
                    ErrorStateView(message: l10n.t("trips.loadError"), retry: { await model.load(app.client) }).countsError("trips.load")
                } else if let at = model.savedAt {
                    FreshnessLine(updatedAt: at, clock: app.settings.clock)
                }
                FollowedJourneysSection()
                if model.legs == nil && !model.failed {
                    // Shaped like what comes: the featured card, then two rows (polish pass 1: three 64 pt bars).
                    VStack(spacing: Space.l) {
                        Skeleton(height: 300, radius: Radius.card)
                        Skeleton(height: 84, radius: Radius.card)
                        Skeleton(height: 84, radius: Radius.card)
                    }
                }
                if let all = shown {
                    if all.isEmpty {
                        EmptyStateView(
                            icon: "train-front", title: l10n.t("trips.emptyTitle"), message: l10n.t("trips.emptyBody"),
                            action: (l10n.t("trips.findTrain"), { router.openAdd() }),
                            link: (l10n.t("trips.exploreTrains"), { router.tab = .explore })
                        )
                        FollowingSection(follows: unshared(model.follows))
                    } else {
                        list(all, upcoming: upcoming, past: past, hero: hero)
                    }
                }
            }
            .refreshable {
                await model.load(app.client)
                await model.loadFollows(app.client)
            }
            .modifier(SwipeContainer())
            .onChange(of: router.tripsScrollTarget, initial: true) { _, target in
                guard let target else { return }
                Task {
                    // Once the list is laid out.
                    try? await Task.sleep(for: .milliseconds(300))
                    withAnimation(Motion.layout.animation) { scroller.scrollTo(target.rawValue, anchor: .top) }
                    router.tripsScrollTarget = nil
                }
            }
        }
    }

    /// The trains you follow on their own: not the ones that belong to a journey you follow (its card has them).
    private func unshared(_ follows: [Follow]) -> [Follow] {
        let covered = Set(app.followed.journeys.flatMap(SharedLogic.followBodies).map { "\($0.trainNumber)|\($0.serviceDate)" })
        return follows.filter { !covered.contains("\($0.trainNumber)|\($0.serviceDate)") }
    }

    @ViewBuilder
    private func list(_ all: [Leg], upcoming: [Leg], past: [Leg], hero: (leg: Leg, state: TripsLogic.HeroState)?) -> some View {
        // The featured card carries its whole journey; every other journey is one row.
        let heroJourney = hero.map { TripsLogic.journey(of: $0.leg, in: all) } ?? []
        if let hero {
            FeaturedCard(
                leg: hero.leg, state: hero.state, next: hero.state == .active ? TripsLogic.nextInJourney(all, after: hero.leg) : nil,
                journey: heroJourney
            )
        } else {
            NothingAhead()
        }
        let shown = Set(heroJourney.map(\.id))
        let next = TripsLogic.journeys(upcoming.filter { !shown.contains($0.id) })
        if !next.isEmpty {
            sectionTitle(l10n.t("trips.next"))
            ForEach(Array(next.enumerated()), id: \.element.first?.id) { index, item in
                // A layover line between separate trips that still meet at a station.
                let before = index == 0 ? heroJourney.last : next[index - 1].last
                if item.count == 1, let before, TripsLogic.meets(before, item[0]) { Layover(a: before, b: item[0]) }
                row(item, upcoming: true)
            }
        }
        let toCheck = past.filter { $0.ride == .review }
        if !toCheck.isEmpty {
            sectionTitle(l10n.t("trips.toCheck")).id(TripsAnchor.reviews.rawValue)
            ForEach(toCheck) { leg in
                ReviewCard(leg: leg) { answer in
                    if !(await model.answer(leg, answer, app.client)) { toaster.show(l10n.t("common.couldntSave"), isError: true) }
                }
            }
        }
        FollowingSection(follows: unshared(model.follows))
        let history = past.filter { !shown.contains($0.id) }
        ForEach(Array(TripsLogic.months(history, language: app.settings.language).enumerated()), id: \.element.label) { index, month in
            Section {
                ForEach(month.items, id: \.first?.id) { item in row(item, upcoming: false) }
            } header: {
                monthHeader(month).id(index == 0 ? TripsAnchor.history.rawValue : "month-\(month.label)")
            }
        }
    }

    /// A journey's compact row, or a single trip's, with the same actions on a swipe and a hold, in the same order:
    /// Share, then Delete (owner, 2026-11-14). A journey's row opens the journey, where its trains can be deleted.
    @ViewBuilder
    private func row(_ item: [Leg], upcoming: Bool) -> some View {
        if item.count > 1 {
            JourneyCard(legs: item)
                .contextMenu { shareButton(item) }
                .modifier(TripSwipe { shareButton(item) })
                .modifier(LandsWhenAdded(ids: item.map(\.id)))
        } else {
            JourneyCard(legs: item, upcoming: upcoming)
                .contextMenu { actions(item[0]) }
                .modifier(TripSwipe { actions(item[0]) })
                .modifier(LandsWhenAdded(ids: [item[0].id]))
        }
    }

    @ViewBuilder
    private func actions(_ leg: Leg) -> some View {
        shareButton([leg])
        Button(role: .destructive) { deleting = leg } label: { Label(l10n.t("detail.delete"), systemImage: "trash") }
    }

    private func shareButton(_ legs: [Leg]) -> some View {
        ShareLink(item: shareText(legs)) { Label(l10n.t("common.share"), systemImage: "square.and.arrow.up") }
    }

    /// "Stockholm C → Göteborg C, Fri 17 Oct · SJ 523 (with Clack)".
    private func shareText(_ legs: [Leg]) -> String {
        guard let first = legs.first, let last = legs.last else { return "" }
        let train = legs.count == 1 ? Format.service(first.operator?.name, first.trainNumber) : l10n.t("journey.label", count: legs.count)
        return l10n.t("trips.shareText", [
            "route": "\(first.origin?.name ?? "") → \(last.destination?.name ?? "")",
            "day": first.schedDep.map { Format.day($0.ms, tz: TripsLogic.tz(first), language: app.settings.language) } ?? "",
            "train": train.isEmpty ? "" : Format.separator + train,
        ])
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text).clack(.sectionHeader).foregroundStyle(Ink.text2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Space.s)
            .accessibilityAddTraits(.isHeader)
    }

    /// "October 2026", and the month's trips and distance (designer, 2026-11-14: "give month headers a job").
    private func monthHeader(_ month: TripsLogic.MonthGroup) -> some View {
        let count = month.tripCount == 1 ? l10n.t("trips.journeysCountOne") : l10n.t("trips.journeysCount", ["count": String(month.tripCount)])
        let distance = month.distanceM > 0 ? Format.distance(month.distanceM, unit: app.settings.distanceUnit, language: app.settings.language) : nil
        return HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(month.label).clack(.sectionHeader).foregroundStyle(Ink.text2)
            Spacer(minLength: Space.s)
            Text(Format.join([count, distance])).clack(.caption).monospacedDigit().foregroundStyle(Ink.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.m).padding(.bottom, Space.s)
        .background(Ink.bg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Swipe actions on a row of the Trips list: iOS 27 lets them work outside a `List` (a `LazyVStack` in a scroll
/// view), so they're there from iOS 27; before, the hold menu has the same actions.
private struct TripSwipe<Actions: View>: ViewModifier {
    @ViewBuilder var actions: Actions

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.swipeActions(edge: .trailing, allowsFullSwipe: false) { actions }
        } else {
            content
        }
    }
}

private struct SwipeContainer: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content.swipeActionsContainer()
        } else {
            content
        }
    }
}
