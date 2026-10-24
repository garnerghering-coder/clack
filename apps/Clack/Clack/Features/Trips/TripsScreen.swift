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
            legs = try await client.legs()
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

    var body: some View {
        // The partition depends on the clock; once a minute is as often as anything on this screen changes class.
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date.timeIntervalSince1970 * 1000)
        }
        .task { await model.load(app.client) }
        .task(id: app.isOffline) { await model.loadDetails(app.client, now: Date.now.timeIntervalSince1970 * 1000) }
        .task { await model.loadFollows(app.client) }
        .task { await model.listen(app.live) }
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
                    IconLink(icon: "search", label: l10n.t("nav.stations"), value: AppRoute.stations)
                    IconButton(icon: "plus", label: l10n.t("nav.addTrain")) { router.openAdd() }
                    SettingsLink()
                }
            }
            SegmentedControl(
                selection: $router.tripsTab,
                options: [(TripsTab.upcoming, l10n.t("trips.upcoming")), (TripsTab.past, l10n.t("trips.past"))]
            )
            if model.failed {
                Banner(kind: .error) {
                    HStack(spacing: 6) {
                        Text(l10n.t("trips.loadError"))
                        Button(l10n.t("trips.retry")) { Task { await model.load(app.client) } }.buttonStyle(LinkButtonStyle())
                    }
                }
            }
            if model.legs == nil && !model.failed {
                VStack(spacing: 10) {
                    Skeleton()
                    Skeleton()
                    Skeleton()
                }
            }
            if let all = shown {
                if all.isEmpty {
                    emptyState
                    if router.tripsTab == .upcoming { FollowingSection(follows: model.follows) }
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

    private var emptyState: some View {
        VStack(spacing: 10) {
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
        if let hero {
            FeaturedCard(
                leg: hero.leg, state: hero.state, next: hero.state == .active ? TripsLogic.nextInJourney(all, after: hero.leg) : nil
            )
        } else {
            NothingAhead()
        }
        if hero != nil && upcoming.isEmpty { NothingAhead() }
        // A layover line between trips that meet at a station, including from the featured one.
        let rest = upcoming.filter { $0.id != hero?.leg.id }
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(rest.enumerated()), id: \.element.id) { index, leg in
                let before = index == 0 ? hero?.leg : rest[index - 1]
                if let before, TripsLogic.meets(before, leg) { Layover(a: before, b: leg) }
                LegRow(leg: leg, upcoming: true)
            }
        }
        FollowingSection(follows: model.follows)
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
                        if item.count > 1 { JourneyCard(legs: item) } else { LegRow(leg: item[0]) }
                    }
                }
            } header: {
                Text(month.label)
                    .clack(.sectionHeader).foregroundStyle(Ink.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12).padding(.bottom, 6)
                    .background(Ink.bg)
            }
        }
    }
}
