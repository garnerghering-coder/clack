//
//  TrainDetailSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// A train opened in place (`Router.presentTrain`): a board row, a followed train or a disruption's "Live" tapped
/// anywhere but Explore. The same facts as Explore's train sheet (its route, stops, what's on board, follow, plan),
/// over the screen you're on, with "Show on live map" to go to Explore. Closing it leaves you where you were.
struct TrainDetailSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.colorScheme) private var scheme
    let request: Router.TrainRequest

    private enum Phase { case loading, notRunning, ready(TrainView) }

    @State private var phase = Phase.loading
    @State private var following = false
    @State private var busy = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date.timeIntervalSince1970 * 1000
            SheetFrame(title: title, onClose: close) {
                switch phase {
                case .loading:
                    Skeleton(height: 120)
                case .notRunning:
                    Text(l10n.t("liveMap.notRunningTitle")).clack(.body).foregroundStyle(Ink.text)
                    Text(l10n.t("liveMap.notRunningBody")).clack(.caption).foregroundStyle(Ink.text2)
                case .ready(let view):
                    content(view, now: now)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task(id: request.id) { await load() }
    }

    private var title: String {
        if case .ready(let view) = phase, let name = view.productName ?? view.operatorId.flatMap({ app.operatorsById[$0]?.name }) {
            return Format.service(name, view.number)
        }
        return l10n.t("liveMap.train", ["number": request.number])
    }

    private func close() { router.trainRequest = nil }

    private func load() async {
        // Refreshed every 30 s while it's open, so a running train's times keep up.
        while !Task.isCancelled {
            if let view = try? await app.client.train(number: request.number, date: request.date, key: request.key) {
                phase = .ready(view)
            } else if case .loading = phase {
                phase = .notRunning
            }
            if let follows = try? await app.client.follows() {
                following = follows.contains { $0.trainNumber == request.number && $0.serviceDate == request.date }
            }
            try? await Task.sleep(for: .seconds(30))
        }
    }

    @ViewBuilder
    private func content(_ view: TrainView, now: Double) -> some View {
        let op = view.operatorId.flatMap { app.operatorsById[$0] }
        let type = view.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        let stops = view.stops ?? []
        let first = stops.first, last = stops.last
        let anyLive = stops.contains { $0.actualArr != nil || $0.actualDep != nil || $0.estimatedArr != nil || $0.estimatedDep != nil }
        // The service is the sheet's title; under it, the operator's badge, the category and the route.
        HStack(spacing: 8) {
            OperatorBadge(op: op, size: .medium)
            if let product = view.product { Text(l10n.t("products.\(product)")).clack(.chip).foregroundStyle(Ink.text2) }
        }
        if let first, let last { Text("\(first.name) → \(last.name)").clack(.rowTitle).foregroundStyle(Ink.text) }
        VStack(alignment: .leading, spacing: 2) {
            TrainPicture(type: type, operatorId: view.operatorId, height: 54)
            Text(type?.name ?? l10n.t("liveMap.typeUnknown")).clack(.caption).foregroundStyle(Ink.text2)
        }
        Text(l10n.t(anyLive ? "train.liveTimes" : "train.timetableOnly")).clack(.caption).foregroundStyle(Ink.text2)
        actions(view)
        StopList(stops: view.stops.map { .list($0) } ?? .none, color: operatorColor(op?.brandColor, scheme: scheme), now: now)
        OnboardView(facts: nil, operatorId: view.operatorId, trainType: view.trainType, compact: true)
        if let first, let last {
            BuyTicket(trip: ExploreLogic.ticketTrip(operatorId: view.operatorId, number: view.number, from: first, to: last, trip: view.trip), inTrips: view.legId != nil)
        }
        if view.trip == nil { Text(l10n.t("board.notInTimetable")).clack(.caption).foregroundStyle(Ink.text2) }
    }

    @ViewBuilder
    private func actions(_ view: TrainView) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    Task { await toggleFollow(view) }
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: following ? "check" : "eye", size: 16)
                        Text(l10n.t(following ? "liveMap.following" : "liveMap.follow"))
                    }
                }
                .buttonStyle(.clack(wide: true))
                .disabled(busy)
                .accessibilityAddTraits(following ? .isSelected : [])
                if let legId = view.legId {
                    Button(l10n.t("liveMap.inYourTrips")) {
                        close()
                        router.push(.trip(legId))
                    }
                    .buttonStyle(.clack(.primary, wide: true))
                } else if let trip = view.trip {
                    Button(l10n.t("liveMap.plan")) {
                        close()
                        router.openAdd(AddTrainLink(tripKey: trip.key, date: trip.serviceDate))
                    }
                    .buttonStyle(.clack(.primary, wide: true))
                }
            }
            if view.live != nil {
                Button {
                    router.openTrain(number: view.number, date: view.date, key: view.trip?.key ?? request.key)
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: "map", size: 16)
                        Text(l10n.t("liveMap.showOnMap"))
                    }
                }
                .buttonStyle(LinkButtonStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func toggleFollow(_ view: TrainView) async {
        busy = true
        defer { busy = false }
        do {
            if following {
                try await app.client.unfollow(number: view.number, date: view.date)
            } else {
                let stops = view.stops ?? []
                let label = stops.first.flatMap { f in stops.last.map { "\(f.name) → \($0.name)" } }
                try await app.client.follow(FollowBody(trainNumber: view.number, serviceDate: view.date, operatorId: view.operatorId, label: label))
            }
            following.toggle()
        } catch {
            // Unchanged: the button shows the real state.
        }
    }
}
