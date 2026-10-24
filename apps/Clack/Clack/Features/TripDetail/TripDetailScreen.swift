//
//  TripDetailScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Trip detail (DESIGN §6, product brief §7): the route map on top, then a card for the stage you're in (before
/// departure: countdown, platform, status; on the train: the live module; after: how it ended and the Passport), the
/// times, tiles, the stop timeline, the activity log and details.
struct TripDetailScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    let id: String

    @State private var leg: LegDetail?
    @State private var live: LiveStateRow?
    @State private var missing = false
    /// Couldn't load and nothing kept on the phone (no connection the first time this trip was opened).
    @State private var unreachable = false
    @State private var fullRoute = false
    @State private var explain = false
    @State private var busy = false
    @State private var toast: String?
    @State private var confirmDelete = false
    /// The route as the maps and the stop rail use it, decoded when the trip changes (not on every tick).
    @State private var geo: RouteGeo?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if missing {
                    Page {
                        BackLink(label: l10n.t("nav.trips"))
                        Text(l10n.t("detail.notFound")).clack(.body).foregroundStyle(Ink.text2)
                    }
                } else if let leg {
                    // The page ticks every 30 s; the status line, the stage card and the stop rail have their own
                    // one-second clocks (`Ticking`), so a second passing doesn't rebuild the whole page and its map.
                    Ticking(every: 30) { now in
                        detail(leg, now: now, proxy: proxy)
                    }
                } else {
                    Page {
                        if unreachable {
                            Text(l10n.t("offline.tripNotKept")).clack(.body).foregroundStyle(Ink.text2)
                        } else {
                            Skeleton(height: 120)
                        }
                    }
                }
            }
        }
        .background(Ink.bg)
        .overlay(alignment: .top) {
            if let toast {
                Text(toast)
                    .clack(.body).fontWeight(.semibold).foregroundStyle(Ink.text)
                    .padding(.vertical, 10).padding(.horizontal, 16)
                    .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    .hairlineBorder(radius: Radius.input)
                    .clackShadow()
                    .padding(.horizontal, 16).padding(.top, 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .task(id: id) { await load() }
        .task(id: id) { await listen() }
        .onChange(of: leg, initial: true) { geo = leg.map(RouteGeo.init) }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.easeOut(duration: 0.25)) { toast = nil }
        }
        .confirmationDialog(l10n.t("detail.deleteConfirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(l10n.t("detail.delete"), role: .destructive) { Task { await remove() } }
            Button(l10n.t("common.close"), role: .cancel) {}
        }
    }

    // MARK: loading

    private func load() async {
        do {
            let loaded = try await app.client.leg(id)
            leg = loaded
            live = loaded.leg.live
            unreachable = false
        } catch let error as APIError where error.status == 404 {
            missing = true
        } catch {
            // A refetch that fails (no connection) keeps what's on screen; only a trip that's gone says so.
            if leg == nil { unreachable = true }
        }
    }

    /// Every live tick: move the marker straight away, then refetch the leg so stop times and the log stay current.
    private func listen() async {
        for await update in app.live.updates() {
            guard update.legId == id else { continue }
            live = update.live
            await load()
            if let shown = update.events.first(where: { $0.type != .departed }), let leg {
                let stops = leg.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) }
                withAnimation(.easeOut(duration: 0.25)) { toast = TripDetailLogic.eventText(l10n, shown, leg: leg.leg, stops: stops) }
            }
        }
    }

    private func answer(_ answer: RideAnswer) async {
        if let updated = try? await app.client.answerRide(id, answer) { leg = updated }
    }

    private func refresh() async {
        busy = true
        if let updated = try? await app.client.refreshLeg(id) { leg = updated }
        busy = false
    }

    private func remove() async {
        if (try? await app.client.deleteLeg(id)) != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            dismiss()
        }
    }

    // MARK: the screen

    @ViewBuilder
    private func detail(_ detail: LegDetail, now: Double, proxy: GeometryProxy) -> some View {
        let m = moment(detail, now: now)
        let shown = m.shown
        let tracking = m.tracking
        let stage = m.stage
        let mapHeight = min(proxy.size.height * 0.55 + proxy.safeAreaInsets.top, 520)
        ScrollViewReader { scroller in
        ScrollView {
            VStack(spacing: 0) {
                mapArea(detail, tracking: tracking, height: mapHeight, top: proxy.safeAreaInsets.top)
                content(detail, shown: shown, tracking: tracking, stage: stage, now: now)
                    .padding(.top, 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                    .background(Ink.bg, in: UnevenRoundedRectangle(topLeadingRadius: Radius.sheet, topTrailingRadius: Radius.sheet))
                    .padding(.top, -24)
            }
        }
        .ignoresSafeArea(edges: .top)
        .scrollBounceBehavior(.basedOnSize)
        .refreshable { await load() }
        #if DEBUG
        // `-scrollTo stops` (or times, train, onboard, activity, details) scrolls there on launch, to check a section.
        .task {
            let args = CommandLine.arguments
            guard let index = args.firstIndex(of: "-scrollTo"), args.indices.contains(index + 1) else { return }
            try? await Task.sleep(for: .seconds(2))
            scroller.scrollTo(args[index + 1], anchor: .top)
        }
        #endif
        }
    }

    /// What the screen is showing at a moment: the live state (or the phone's estimate), whether it is tracking, the
    /// stage of the ride and the status word.
    private struct Moment {
        var shown: LiveStateRow?
        var tracking: Bool
        var stage: TripDetailLogic.Stage
        var status: LiveRules.TripStatus
    }

    private func moment(_ detail: LegDetail, now: Double) -> Moment {
        let shown = TripDetailLogic.shown(detail, live: live, now: now, offline: app.isOffline)
        return Moment(
            shown: shown, tracking: TripDetailLogic.isTracking(shown),
            stage: TripDetailLogic.stage(detail.leg, live: shown, shown: shown, now: now),
            status: LiveRules.statusKey(detail.leg, live: live, now: now)
        )
    }

    private func mapArea(_ detail: LegDetail, tracking: Bool, height: CGFloat, top: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            tripMap(detail, tracking: tracking, height: height, top: top)
            MapButton(icon: "arrow-left", label: l10n.t("nav.trips")) { dismiss() }
                .padding(.leading, 16).padding(.top, top + 12)
            if detail.leg.isEstimatedGeometry {
                Text(l10n.t("detail.estimatedRoute"))
                    .clack(.caption).foregroundStyle(Ink.text)
                    .padding(.vertical, 4).padding(.horizontal, 10)
                    .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .hairlineBorder(radius: Radius.controlSm)
                    .frame(maxWidth: .infinity)
                    .padding(.top, top + 18)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }

    /// The interactive route map: draw-on, the rail network per setting, the train marker and the split while tracking.
    @ViewBuilder
    private func tripMap(_ detail: LegDetail, tracking: Bool, height: CGFloat, top: CGFloat) -> some View {
        let geo = routeGeo(detail)
        let shown = TripDetailLogic.shown(detail, live: live, now: Date.now.timeIntervalSince1970 * 1000, offline: app.isOffline)
        let train: MapTrain? = (tracking ? shown : nil).flatMap { s in
            s.lat.flatMap { lat in s.lon.map { MapTrain(lat: lat, lon: $0, bearing: s.bearing, estimated: s.positionSource != .gps || s.localEstimate) } }
        }
        RouteMapView(
            color: MapStyle.opColor(detail.leg.operator?.brandColor, dark: scheme == .dark), route: geo.route, stops: geo.stops,
            animate: true, railNetwork: app.settings.showRailNetwork, train: train, fitTrain: shown?.status == .approaching, progress: tracking ? shown?.progress : nil,
            label: l10n.t("detail.mapLabel", ["from": detail.leg.origin?.name ?? "", "to": detail.leg.destination?.name ?? ""]),
            topInset: top + 48, bottomInset: 30
        )
        .frame(height: height)
    }

    private func routeGeo(_ detail: LegDetail) -> RouteGeo { geo?.id == detail.id ? geo! : RouteGeo(detail) }

    @ViewBuilder
    private func content(_ detail: LegDetail, shown: LiveStateRow?, tracking: Bool, stage: TripDetailLogic.Stage, now: Double) -> some View {
        let live = shown
        let l = detail.leg
        let tz = l.origin?.tz ?? "Europe/Stockholm"
        let dtz = l.destination?.tz ?? tz
        let color = operatorColor(l.operator?.brandColor, scheme: scheme)
        let schedDep = l.schedDep?.ms
        let schedArr = l.schedArr?.ms
        VStack(alignment: .leading, spacing: 16) {
            Ticking(every: 1) { now in head(detail, now: now) }
            Text("\(l.origin?.name ?? "") → \(l.destination?.name ?? "")")
                .clack(.detailRoute).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
            if let schedDep {
                Text(Format.longDate(schedDep, tz: tz, language: app.settings.language)).clack(.body).foregroundStyle(Ink.text2)
            }
            // Just arrived: welcome, and what the trip did for your Passport.
            if stage == .after, !l.canceled, now - (l.actualArr?.ms ?? schedArr ?? 0) < 60 * 60_000 {
                Card {
                    Text(l10n.t("progress.welcome", ["station": l.destination?.name ?? ""])).clack(.welcomeTitle).foregroundStyle(Ink.text)
                    Text(l10n.t("progress.welcomeBody", [
                        "time": Format.time(l.actualArr?.ms ?? schedArr, tz: dtz, clock: app.settings.clock),
                        "train": [l.operator?.name, l.trainNumber].compactMap { $0 }.joined(separator: " "),
                    ])).clack(.caption).foregroundStyle(Ink.text2)
                    TripProgressView(legId: l.id, quietIfNothing: true)
                }
            }
            // Something wrong with this train or the change after it: what happened, what to do, what you're owed.
            DisruptionCard(leg: detail)
            if stage == .before { RiskCard(leg: detail) }
            Ticking(every: 1) { now in stageCard(detail, now: now) }
            timesRow(detail, live: live, tracking: tracking).id("times")
            tiles(detail, live: live, tracking: tracking)
            if explain {
                Text(explanationText(l.arrDelayMin)).clack(.caption).foregroundStyle(Ink.text2)
            }
            JourneyConnections(legId: l.id, journeyId: l.journeyId)
            Ticking(every: 1) { now in stopsCard(detail, color: color, now: now) }.id("stops")
            TrainCard(leg: detail) { leg = $0 }.id("train")
            Card {
                Text(l10n.t("onboard.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                OnboardView(facts: l.onboard, operatorId: l.operator?.id, trainType: l.trainType)
            }
            .id("onboard")
            if tracking || !detail.events.isEmpty {
                ActivityLog(leg: l, events: detail.events, stops: detail.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) })
            }
            detailsCard(detail).id("details")
            actions(l)
        }
    }

    private func head(_ detail: LegDetail, now: Double) -> some View {
        let l = detail.leg
        let m = moment(detail, now: now)
        let live = m.shown, tracking = m.tracking, status = m.status
        return FlowLayout(spacing: 10, lineSpacing: 6) {
            OperatorBadge(op: l.operator, size: 32)
            Text([l.operator?.name, l.trainNumber].compactMap { $0 }.joined(separator: " ")).clack(.rowTitle).foregroundStyle(Ink.text)
            if let category = l.category { Chip(text: l10n.t("products.\(category)")) }
            if tracking, let live {
                LiveChip(live: live, now: now)
            } else {
                Text(l10n.t("status.\(status.rawValue)")).clack(.chip).foregroundStyle(statusColor(status))
            }
        }
    }

    private func statusColor(_ status: LiveRules.TripStatus) -> Color {
        switch status {
        case .planned, .approaching: Ink.accentInk
        case .cancelled: Ink.veryLate
        case .boarding: Ink.slight
        case .live: Ink.onTime
        case .completed: Ink.text2
        }
    }

    // MARK: the stage card

    @ViewBuilder
    private func stageCard(_ detail: LegDetail, now: Double) -> some View {
        let m = moment(detail, now: now)
        let live = m.shown, shown = m.shown, tracking = m.tracking, stage = m.stage
        let l = detail.leg
        let schedDep = l.schedDep?.ms
        let board = detail.stops.first { $0.role == .board }
        let dtz = l.destination?.tz ?? "Europe/Stockholm"
        Card {
            switch stage {
            case .before:
                let derived = l.depDelayMin ?? (tracking ? Delay.minutes(advertised: schedDep, actual: board?.estimatedDep?.ms) : nil)
                HStack(spacing: 8) {
                    Pill(text: TripsLogic.countdown(l10n, l, now: now))
                    if let platform = l.depPlatform {
                        Chip(text: l10n.t("trips.platform", ["platform": platform]))
                    } else {
                        Text(l10n.t("detail.platformLater")).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    if !l.canceled, derived != nil { DelayText(delay: derived) }
                }
                if l.canceled { Banner(kind: .error) { Text(l10n.t("detail.canceledBanner")) } }
                // The train started earlier and is on its way to where you get on: where it is, and when it gets there.
                if let shown, shown.status == .approaching, let board {
                    HStack(spacing: 8) {
                        Text(l10n.t("live.approachingTo", ["name": board.name])).clack(.rowTitle).foregroundStyle(Ink.text)
                        if shown.positionSource == .gps, !shown.localEstimate { Speedometer(kmh: shown.speedKmh, at: shown.positionAt?.ms, now: now).clack(.caption) }
                    }
                    HStack(spacing: 6) {
                        Text(l10n.t("live.arrivesAtLabel")).clack(.body).foregroundStyle(Ink.text)
                        FlapTime(time: shown.eta?.ms, tz: board.tz, clock: app.settings.clock).clack(.body).foregroundStyle(Ink.text)
                    }
                }
                Text(live.map { l10n.t("live.updated", ["ago": LiveRules.ago(l10n, then: $0.updatedAt.ms, now: now)]) } ?? l10n.t("detail.timetableOnly"))
                    .clack(.caption).foregroundStyle(Ink.text2)
            case .during:
                if let shown {
                    LiveModule(leg: l, live: shown, stops: detail.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) }, now: now)
                }
            case .after:
                let text: String = l.canceled ? l10n.t("status.cancelled")
                    : l.actualArr != nil ? l10n.t("trips.arrivedAt", ["time": Format.time(l.actualArr?.ms, tz: dtz, clock: app.settings.clock)])
                    : l10n.t("detail.scheduledArrival", ["time": Format.time(l.schedArr?.ms, tz: dtz, clock: app.settings.clock)])
                Text(text).clack(.rowTitle).foregroundStyle(Ink.text)
                Text(l.actualArr != nil ? l10n.t("detail.actualTimes") : l10n.t("detail.scheduledOnlyNote")).clack(.caption).foregroundStyle(Ink.text2)
                // Why it doesn't count (or needs a check); a trip that counts needs no line about it.
                if l.ride != .auto && l.ride != .confirmed {
                    Text(l10n.t("record.state.\(l.ride.rawValue)", ["why": l10n.t("record.why.\(l.rideReason ?? "no_reports")")]))
                        .clack(.stopName).foregroundStyle(l.ride == .review ? Ink.late : Ink.text)
                }
                HStack(spacing: 14) {
                    if l.ride == .review {
                        Button(l10n.t("record.yes")) { Task { await answer(.yes) } }.buttonStyle(.clack(.primary, small: true))
                        Button(l10n.t("record.no")) { Task { await answer(.no) } }.buttonStyle(.clack(small: true))
                    }
                    if l.ride == .auto || l.ride == .confirmed {
                        Button {
                            router.tab = .passport
                        } label: {
                            HStack(spacing: 4) {
                                LucideIcon(name: "stamp", size: 14)
                                Text(l10n.t("detail.seePassport"))
                            }
                        }
                        .buttonStyle(LinkButtonStyle())
                        Button(l10n.t("record.correctNo")) { Task { await answer(.no) } }.buttonStyle(LinkButtonStyle())
                    }
                    if l.ride == .notTaken {
                        Button(l10n.t("record.undo")) { Task { await answer(.undo) } }.buttonStyle(LinkButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: times and tiles

    private func timesRow(_ detail: LegDetail, live: LiveStateRow?, tracking: Bool) -> some View {
        let l = detail.leg
        let tz = l.origin?.tz ?? "Europe/Stockholm"
        let dtz = l.destination?.tz ?? tz
        let board = detail.stops.first { $0.role == .board }
        let schedDep = l.schedDep?.ms
        let schedArr = l.schedArr?.ms
        let extraDays = (schedDep != nil && schedArr != nil) ? Format.dayOffset(from: schedDep!, fromTz: tz, to: schedArr!, toTz: dtz) : 0
        return HStack(alignment: .top, spacing: 12) {
            TimeBlock(
                label: l10n.t("detail.departure"), sched: schedDep, actual: l.actualDep?.ms ?? (tracking ? board?.estimatedDep?.ms : nil),
                tz: tz, platform: l.depPlatform,
                delay: l.depDelayMin ?? (tracking ? Delay.minutes(advertised: schedDep, actual: board?.estimatedDep?.ms) : nil),
                canceled: l.canceled
            )
            TimeBlock(
                label: l10n.t("detail.arrival"), sched: schedArr, actual: l.actualArr?.ms ?? (tracking ? live?.arrivalEta?.ms : nil),
                tz: dtz, platform: l.arrPlatform, delay: l.arrDelayMin ?? (tracking ? live?.arrivalDelayMin : nil),
                canceled: l.canceled, extraDays: extraDays
            )
        }
    }

    private func tiles(_ detail: LegDetail, live: LiveStateRow?, tracking: Bool) -> some View {
        let l = detail.leg
        let dep = l.actualDep?.ms ?? l.schedDep?.ms
        let arr = l.actualArr?.ms ?? l.schedArr?.ms
        return HStack(spacing: 10) {
            Tile(
                title: l10n.t("detail.distance"),
                value: (l.isEstimatedGeometry ? "≈ " : "") + Format.distance(l.distanceM, unit: app.settings.distanceUnit, language: app.settings.language)
            )
            Tile(title: l10n.t("detail.duration"), value: (dep != nil && arr != nil) ? Format.duration((arr! - dep!) / 60_000) : "—")
            Button {
                explain.toggle()
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.t("detail.delay")).clack(.captionUpper).foregroundStyle(Ink.text2)
                    DelayText(delay: l.arrDelayMin ?? (tracking ? live?.arrivalDelayMin : nil), canceled: l.canceled)
                        .frame(minHeight: 22, alignment: .leading)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                .hairlineBorder(radius: Radius.card)
            }
            .buttonStyle(.plain)
        }
    }

    private func explanationText(_ arrDelay: Int?) -> String {
        switch TripDetailLogic.explanation(arrDelayMin: arrDelay) {
        case .unknown: l10n.t("delay.explainUnknown")
        case .late(let n): l10n.t("delay.explainLate", count: n)
        case .early(let n): l10n.t("delay.explainEarly", count: n)
        case .onTime: l10n.t("delay.explainOnTime")
        }
    }

    // MARK: stops, details, actions

    private func stopsCard(_ detail: LegDetail, color: Color, now: Double) -> some View {
        let m = moment(detail, now: now)
        let shown = m.shown, stage = m.stage
        let stops = TripDetailLogic.visibleStops(detail.stops, fullRoute: fullRoute)
        // How far along the line the train is, so the rail shows it between the stops too.
        let fills = TripDetailLogic.segmentFills(stops: stops, route: routeGeo(detail).route, shown: shown, stage: stage, now: now)
        let halves = TripDetailLogic.railHalves(stops: stops, fills: fills, showTrain: stage == .during)
        let hasHidden = detail.stops.contains { $0.role == .before || $0.role == .after }
        return Card {
            Text(l10n.t("detail.stops")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            VStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    StopRow(
                        stop: stop, color: color, tense: TripDetailLogic.tense(of: stop, shown: shown, stage: stage),
                        above: halves[i].above, below: halves[i].below
                    )
                }
            }
            if hasHidden {
                Button(fullRoute ? l10n.t("detail.hideFullRoute") : l10n.t("detail.showFullRoute")) { fullRoute.toggle() }
                    .buttonStyle(LinkButtonStyle())
            }
        }
    }

    private func detailsCard(_ detail: LegDetail) -> some View {
        let l = detail.leg
        let beyond = TripDetailLogic.beyondCountries(detail.stops)
        let borderAt = TripDetailLogic.borderStation(detail)
        return Card(spacing: 8) {
            if l.dataQuality != .full && !(l.dataQuality == .partial && !beyond.isEmpty) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Chip(text: l10n.t("detail.quality.\(l.dataQuality.rawValue)"))
                    Text(l10n.t("detail.qualityNote.\(l.dataQuality.rawValue)")).clack(.caption).foregroundStyle(Ink.text2)
                }
            }
            if !beyond.isEmpty {
                let countries = beyond.map { code -> String in
                    let key = "countries.\(code)"
                    let name = l10n.t(key)
                    return name == key ? code : name
                }.joined(separator: ", ")
                Text(l10n.t(borderAt != nil ? "detail.beyondLiveData" : "detail.beyondLiveDataNoReport", ["countries": countries, "station": borderAt ?? ""]))
                    .clack(.caption).foregroundStyle(Ink.text2)
            }
            if l.isEstimatedGeometry { Text(l10n.t("detail.estimatedDistance")).clack(.caption).foregroundStyle(Ink.text2) }
            Text(l10n.t("detail.source")).clack(.caption).foregroundStyle(Ink.text2)
        }
    }

    private func actions(_ l: Leg) -> some View {
        HStack(spacing: 10) {
            if l.status != .snapshotted {
                Button {
                    Task { await refresh() }
                } label: {
                    HStack(spacing: 8) {
                        LucideIcon(name: "refresh-cw", size: 16)
                        Text(l10n.t("detail.refresh"))
                    }
                }
                .buttonStyle(.clack())
                .disabled(busy)
            }
            Button {
                confirmDelete = true
            } label: {
                HStack(spacing: 8) {
                    LucideIcon(name: "trash", size: 16)
                    Text(l10n.t("detail.delete"))
                }
            }
            .buttonStyle(.clack(.danger))
        }
    }
}

/// One of the two time blocks: label and delay, the timetabled time struck through when it changed, the big flap time,
/// and the platform. Fixed rows so the two cards line up side by side.
struct TimeBlock: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let label: String
    let sched: Double?
    let actual: Double?
    let tz: String
    let platform: String?
    let delay: Int?
    let canceled: Bool
    var extraDays = 0

    var body: some View {
        let changed = actual != nil && sched != nil && floor(actual! / 60_000) != floor(sched! / 60_000)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(label).clack(.captionUpper).foregroundStyle(Ink.text2).lineLimit(1)
                Spacer(minLength: 0)
                DelayText(delay: delay, canceled: canceled)
            }
            .frame(minHeight: 26)
            Text(Format.time(sched, tz: tz, clock: app.settings.clock))
                .font(ClackFont.inter(14)).strikethrough().monospacedDigit().foregroundStyle(Ink.text3)
                .opacity(changed ? 1 : 0)
                .accessibilityHidden(!changed)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                SplitFlap(value: Format.time(actual ?? sched, tz: tz, clock: app.settings.clock), size: .time, intro: true)
                    .opacity(canceled ? 0.6 : 1)
                    .overlay { if canceled { Rectangle().fill(Ink.text).frame(height: 1.5) } }
                if extraDays > 0 { Text("+\(extraDays)").clack(.captionUpper).foregroundStyle(Ink.text2) }
            }
            HStack(spacing: 6) {
                if let platform { Chip(text: l10n.t("trips.platform", ["platform": platform])) } else { Chip(text: "–").hidden() }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
    }
}

/// One stop of the timeline: a rail, a dot (the operator's colour where you got on and off), the name with its notes,
/// the time coloured by delay, and the platform.
struct StopRow: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let stop: LegStop
    let color: Color
    var tense = TripDetailLogic.StopTense.past
    var above = TripDetailLogic.RailHalf()
    var below = TripDetailLogic.RailHalf()

    var body: some View {
        let times = TripDetailLogic.stopTimes(stop)
        let ridden = stop.role.isRidden
        let deviations = stop.deviations.filter { $0 != "Spårändrat" }
        let platformChanged = stop.deviations.contains("Spårändrat")
        let actual = times.actual
        let band = DelayBand(delayMin: times.delay, canceled: stop.canceled)
        let showSched = actual != nil && times.sched != nil && floor(actual! / 60_000) != floor(times.sched! / 60_000)
        HStack(spacing: 10) {
            rail()
            VStack(alignment: .leading, spacing: 1) {
                NavigationLink(value: AppRoute.board(stationId: stop.stationId, arrivals: false)) {
                    Text(stop.name)
                        .font(ClackFont.inter(16, ridden ? .semibold : .medium)).foregroundStyle(ridden ? Ink.text : Ink.text3)
                        .strikethrough(stop.canceled).opacity(stop.canceled ? 0.6 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l10n.t("board.openBoard", ["station": stop.name]))
                if stop.role == .board { Text(l10n.t(tense == .past ? "detail.gotOn" : tense == .present ? "detail.gettingOn" : "detail.willGetOn")).clack(.caption).foregroundStyle(Ink.accentInk) }
                if stop.role == .alight { Text(l10n.t(tense == .past ? "detail.gotOff" : tense == .present ? "detail.gettingOff" : "detail.willGetOff")).clack(.caption).foregroundStyle(Ink.accentInk) }
                if ridden && stop.reportSource == nil { Text(l10n.t("detail.noLiveData")).clack(.caption).foregroundStyle(Ink.text2) }
                if !deviations.isEmpty { Text(deviations.joined(separator: " · ")).clack(.caption).foregroundStyle(Ink.text2) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            VStack(alignment: .trailing, spacing: 0) {
                // The stop's time on the tick board, like the big times; coloured by delay once it is known.
                SplitFlap(value: Format.time(actual ?? times.sched, tz: stop.tz, clock: app.settings.clock), size: .sm, colour: actual != nil ? band.ink : nil)
                    .opacity(stop.canceled ? 0.5 : 1)
                    .overlay { if stop.canceled { Rectangle().fill(Ink.text2).frame(height: 1.5) } }
                if showSched, let sched = times.sched {
                    Text(Format.time(sched, tz: stop.tz, clock: app.settings.clock))
                        .font(ClackFont.inter(12, .medium)).strikethrough().monospacedDigit().foregroundStyle(Ink.text3)
                }
            }
            HStack(spacing: 3) {
                Text(stop.platform ?? "").monospacedDigit()
                if platformChanged { LucideIcon(name: "repeat", size: 12).accessibilityLabel("Platform changed") }
            }
            .clack(.stopName).foregroundStyle(Ink.text2)
            .frame(width: 44, alignment: .trailing)
        }
        .frame(minHeight: 48)
    }

    private func rail() -> some View {
        StopRail(
            color: color, big: stop.role == .board || stop.role == .alight, ridden: stop.role.isRidden,
            startsHere: stop.role == .board, endsHere: stop.role == .alight, above: above, below: below
        )
    }
}

/// The vertical rail beside a stop. Where the train has been it is the operator's colour; the rest of the ride is a dotted
/// grey line still to go; stretches you didn't ride are a hairline. It starts at the middle of the stop you got on and
/// ends at the middle of the one you got off, and a small dot shows the train between stops while it's under way. The
/// trip's stop list and the Explore train sheet draw it the same way.
struct StopRail: View {
    let color: Color
    /// Where you got on or off (a bigger dot in the operator's colour).
    var big = false
    var ridden = true
    /// No line above (the first stop of the ride) or below (the last).
    var startsHere = false
    var endsHere = false
    var above = TripDetailLogic.RailHalf()
    var below = TripDetailLogic.RailHalf()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if startsHere { Color.clear.frame(maxHeight: .infinity) } else { half(above).frame(maxHeight: .infinity) }
                if endsHere { Color.clear.frame(maxHeight: .infinity) } else { half(below).frame(maxHeight: .infinity) }
            }
            .frame(width: 14)
            Circle()
                .fill(big ? color : (ridden ? (covered ? color : Ink.text) : Ink.text3))
                .frame(width: big ? 14 : 10, height: big ? 14 : 10)
                .overlay(Circle().strokeBorder(big ? Ink.text : Ink.bg, lineWidth: 2).padding(-2))
        }
        .frame(width: 20)
    }

    /// A stop the train has passed: the line below it has started to fill.
    private var covered: Bool { below.fill > 0 || above.fill >= 1 }

    private func half(_ half: TripDetailLogic.RailHalf) -> some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            ZStack(alignment: .top) {
                if half.ridden {
                    // Still to go: dotted.
                    Path { p in
                        p.move(to: CGPoint(x: 7, y: 0))
                        p.addLine(to: CGPoint(x: 7, y: h))
                    }
                    .stroke(Ink.text3, style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 5]))
                    if half.fill > 0 { color.frame(width: 2, height: h * half.fill).frame(maxWidth: .infinity) }
                } else {
                    Ink.hairline.frame(width: 2).frame(maxWidth: .infinity)
                }
                if let train = half.train {
                    Circle().fill(color).frame(width: 10, height: 10)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .frame(maxWidth: .infinity)
                        .offset(y: h * train - 5)
                }
            }
        }
    }
}

/// On a trip's page: the change into it and out of it, when it's part of a journey (ADDITIONS_01 C3).
struct JourneyConnections: View {
    @Environment(AppModel.self) private var app
    let legId: String
    let journeyId: String?
    @State private var legs: [Leg]?

    var body: some View {
        Group {
            if let legs, let i = legs.firstIndex(where: { $0.id == legId }) {
                VStack(spacing: 8) {
                    if i > 0, legs[i - 1].destination?.id == legs[i].origin?.id { ConnectionCard(a: legs[i - 1], b: legs[i]) }
                    if i < legs.count - 1, legs[i].destination?.id == legs[i + 1].origin?.id { ConnectionCard(a: legs[i], b: legs[i + 1]) }
                }
            }
        }
        .task(id: journeyId) {
            guard let journeyId else { return }
            legs = (try? await app.client.journey(journeyId))?.legs.map(\.leg)
        }
    }
}

/// A trip's route and stops as the maps draw them.
nonisolated struct RouteGeo: Equatable {
    var id: String
    var route: [LatLon]
    var stops: [MapStop]

    init(_ detail: LegDetail) {
        let geo = detail.mapRoute()
        id = detail.id
        route = geo.route
        stops = geo.stops
    }
}

/// A part of a screen that needs the clock: it is redrawn every `every` seconds with the time in milliseconds, and the
/// rest of the screen is not.
struct Ticking<Content: View>: View {
    let every: Double
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        TimelineView(.periodic(from: .now, by: every)) { context in
            content(context.date.timeIntervalSince1970 * 1000)
        }
    }
}
