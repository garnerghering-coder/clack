//
//  TripDetailScreen.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Trip detail (DESIGN §6, product brief §7): the route map on top, then what matters at the stage you're in
/// (`TripDetailLogic.sections`): before departure, when and which platform; on the train, where it is and what's next;
/// after, how it went and what it did for your Passport. A disruption is at the top at every stage; the train, on board,
/// details and the activity log are under "About this train".
struct TripDetailScreen: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let id: String

    @State private var leg: LegDetail?
    @State private var live: LiveStateRow?
    @State private var missing = false
    /// Couldn't load and nothing kept on the phone (no connection the first time this trip was opened).
    @State private var unreachable = false
    @State private var fullRoute = false
    /// "About this train" is closed until you open it.
    @State private var aboutOpen = false
    @State private var busy = false
    @State private var toast: String?
    @State private var confirmDelete = false
    /// Typing the platform where you got on (`.dep`) or off (`.arr`), where no source has one.
    @State private var platformEnd: PlatformEnd = .dep
    @State private var askingPlatform = false
    @State private var typedPlatform = ""
    /// The route as the maps and the stop rail use it, decoded when the trip changes (not on every tick).
    @State private var geo: RouteGeo?

    var body: some View {
        GeometryReader { proxy in
            Group {
                if missing {
                    Page {
                        BackLink(label: router.backLabel(l10n))
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
                    .padding(.vertical, 12).padding(.horizontal, 16)
                    .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
                    .hairlineBorder(radius: Radius.input)
                    .clackShadow()
                    .padding(.horizontal, 16).padding(.top, 12)
                    // Reduce Motion: it fades instead of sliding down.
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .task(id: id) { await load() }
        .countsScreen("trip")
        .task(id: id) { await listen() }
        .onChange(of: leg, initial: true) { geo = leg.map(RouteGeo.init) }
        .task(id: toast) {
            guard toast != nil else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { toast = nil }
        }
        // Which end stays in `platformEnd`: the alert clears its own flag before the button's action runs.
        .alert(l10n.t("platform.title"), isPresented: $askingPlatform) {
            TextField(l10n.t("platform.title"), text: $typedPlatform)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            Button(l10n.t("common.save")) { Task { await savePlatform() } }
            Button(l10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(l10n.t(platformEnd == .arr ? "platform.messageArrival" : "platform.message"))
        }
        .confirmationDialog(l10n.t("detail.deleteConfirm"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(l10n.t("detail.delete"), role: .destructive) { Task { await remove() } }
            Button(l10n.t("common.close"), role: .cancel) {}
        }
        // Full-bleed: the map runs under where the bar would be; its own buttons float over it.
        .toolbar(.hidden, for: .navigationBar)
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
                let text = TripDetailLogic.eventText(l10n, shown, leg: leg.leg, stops: stops)
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { toast = text }
                // A delay or platform change is said out loud too (DESIGN §16).
                AccessibilityNotification.Announcement(text).post()
            }
        }
    }

    private func answer(_ answer: RideAnswer) async {
        if let updated = try? await app.client.answerRide(id, answer) { leg = updated }
    }

    /// Where a typed platform goes.
    enum PlatformEnd { case dep, arr }

    /// Asks for the platform at one end, only where no source has one (owner, 2026-10-25). Nil: not to be typed.
    private func platformAction(_ end: PlatformEnd, _ l: Leg) -> (() -> Void)? {
        let fromSource = end == .dep ? l.depPlatformFromSource : l.arrPlatformFromSource
        guard fromSource == false, l.status != .snapshotted else { return nil }
        return {
            typedPlatform = (end == .dep ? l.depPlatform : l.arrPlatform) ?? ""
            platformEnd = end
            askingPlatform = true
        }
    }

    private func savePlatform() async {
        Usage.shared.count(.feature, "trip.typePlatform")
        let end = platformEnd
        let text = typedPlatform.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = text.isEmpty ? nil : String(text.prefix(6))
        let patch = end == .dep ? LegPatch(depPlatform: .some(value)) : LegPatch(arrPlatform: .some(value))
        if let updated = try? await app.client.updateLeg(id, patch) { leg = updated }
    }

    private func refresh() async {
        busy = true
        if let updated = try? await app.client.refreshLeg(id) { leg = updated }
        busy = false
    }

    private func remove() async {
        if (try? await app.client.deleteLeg(id)) != nil {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            app.tripsChanged()
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
        .scrollBounceBehavior(.always)
        // Pull to refresh asks the sources for fresh times (a saved trip just reloads).
        .refreshable { await (detail.leg.status == .snapshotted ? load() : refresh()) }
        #if DEBUG
        // `-scrollTo stops` (or times, about, train, onboard, activity, details) scrolls there on launch, to check a
        // section; the last four open "About this train" first.
        .task {
            let args = CommandLine.arguments
            guard let index = args.firstIndex(of: "-scrollTo"), args.indices.contains(index + 1) else { return }
            if ["train", "onboard", "activity", "details", "about"].contains(args[index + 1]) { aboutOpen = true }
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
            // Back and the menu in one row, so neither lies over the other.
            HStack {
                MapButton(icon: "arrow-left", label: router.backLabel(l10n)) { dismiss() }
                    .accessibilityIdentifier("trip.back")
                Spacer(minLength: 0)
                moreMenu(detail.leg)
            }
            .padding(.horizontal, 16).padding(.top, top + 12)
            if detail.leg.isEstimatedGeometry {
                Text(l10n.t("detail.estimatedRoute"))
                    .clack(.caption).foregroundStyle(Ink.text)
                    .padding(.vertical, 4).padding(.horizontal, 12)
                    .background(Ink.glass, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
                    .hairlineBorder(radius: Radius.controlSm)
                    .frame(maxWidth: .infinity)
                    .padding(.top, top + 18)
                    // A label only: taps go through to the buttons beside it.
                    .allowsHitTesting(false)
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
            topInset: top + 48, bottomInset: 30,
            // On the train: the map follows it (DESIGN §9.5 Follow train).
            followTrain: TripDetailLogic.stage(detail.leg, live: live, shown: shown, now: Date.now.timeIntervalSince1970 * 1000) == .during
        )
        .frame(height: height)
    }

    private func routeGeo(_ detail: LegDetail) -> RouteGeo { geo?.id == detail.id ? geo! : RouteGeo(detail) }

    @ViewBuilder
    private func content(_ detail: LegDetail, shown: LiveStateRow?, tracking: Bool, stage: TripDetailLogic.Stage, now: Double) -> some View {
        let l = detail.leg
        let tz = l.origin?.tz ?? "Europe/Stockholm"
        VStack(alignment: .leading, spacing: 16) {
            Ticking(every: 1) { now in head(detail, now: now) }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(l.origin?.name ?? "") → \(l.destination?.name ?? "")")
                    .clack(.detailRoute).foregroundStyle(Ink.text).fixedSize(horizontal: false, vertical: true)
                if let schedDep = l.schedDep?.ms {
                    Text(Format.longDate(schedDep, tz: tz, language: app.settings.language)).clack(.body).foregroundStyle(Ink.text2)
                }
            }
            // Something wrong with this train or the change after it, at every stage: what happened, what to do, what
            // you're owed. Nothing when all is well.
            DisruptionCard(leg: detail)
            // Then what matters now (owner, 2026-10-24): before, when and which platform; on the train, where it is and
            // what's next; after, how it went. Everything else about the train is under "About this train".
            ForEach(TripDetailLogic.sections(stage), id: \.self) { part in
                section(part, detail, shown: shown, tracking: tracking, stage: stage)
            }
        }
    }

    @ViewBuilder
    private func section(_ part: TripDetailLogic.Section, _ detail: LegDetail, shown: LiveStateRow?, tracking: Bool, stage: TripDetailLogic.Stage) -> some View {
        let color = operatorColor(detail.leg.operator?.brandColor, scheme: scheme)
        switch part {
        case .countdown: Ticking(every: 1) { now in countdown(detail, now: now) }
        case .risk: RiskCard(leg: detail)
        case .live: Ticking(every: 1) { now in liveNow(detail, now: now) }
        case .result: result(detail)
        case .times: timesRow(detail, live: shown, tracking: tracking).id("times")
        case .stops: Ticking(every: 1) { now in stopsCard(detail, color: color, now: now) }.id("stops")
        case .connections: JourneyConnections(legId: detail.id, journeyId: detail.leg.journeyId)
        case .directions: directions(detail)
        case .alertsPrompt: AlertsPrompt(leg: detail.leg)
        case .about: about(detail, tracking: tracking)
        }
    }

    private func head(_ detail: LegDetail, now: Double) -> some View {
        let l = detail.leg
        let m = moment(detail, now: now)
        let live = m.shown, tracking = m.tracking, status = m.status
        // Where you sit, until the trip is over.
        let seat = m.stage == .after ? nil : Seat.label(l10n, coach: l.coach, seat: l.seat)
        return ServiceHeader(op: l.operator, number: l.trainNumber, size: .large, category: l.category, seat: seat) {
            if tracking, let live {
                LiveStatus(live: live, now: now)
            } else {
                StatusLine(statusKind(status), l10n.t("status.\(status.rawValue)"))
            }
        }
    }

    private func statusKind(_ status: LiveRules.TripStatus) -> StatusLine.Kind {
        switch status {
        case .planned: .upcoming
        case .approaching: .onItsWay
        case .cancelled: .cancelled
        case .boarding: .boarding
        case .live: .live
        case .completed: .arrived
        }
    }

    // MARK: before: when, and which platform

    @ViewBuilder
    private func countdown(_ detail: LegDetail, now: Double) -> some View {
        let m = moment(detail, now: now)
        let shown = m.shown, tracking = m.tracking
        let l = detail.leg
        let board = detail.stops.first { $0.role == .board }
        let derived = l.depDelayMin ?? (tracking ? Delay.minutes(advertised: l.schedDep?.ms, actual: board?.estimatedDep?.ms) : nil)
        let status = TripsLogic.countdownStatus(l10n, l, now: now)
        let platform = l.depPlatform.map { l10n.t("trips.platform", ["platform": $0]) } ?? l10n.t("detail.platformLater")
        VStack(alignment: .leading, spacing: 8) {
            // The countdown and the platform as one written line, and the delay when there is one.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                StatusLine(status.kind, l.canceled ? status.text : Format.join([status.text, platform]))
                if !l.canceled, derived != nil { DelayText(delay: derived) }
            }
            // The train started earlier and is on its way to where you get on: where it is, and when it gets there.
            if let shown, shown.status == .approaching, let board {
                // The status line already says "On its way"; this says when it reaches you.
                HStack(spacing: 8) {
                    Text(l10n.t("live.arrivesAtLabel")).clack(.body).foregroundStyle(Ink.text)
                    FlapTime(time: shown.eta?.ms, tz: board.tz, clock: app.settings.clock).clack(.body).foregroundStyle(Ink.text)
                    if shown.positionSource == .gps, !shown.localEstimate { Speedometer(kmh: shown.speedKmh, at: shown.positionAt?.ms, now: now).clack(.caption) }
                }
            }
            Text(shown.map { l10n.t("live.updated", ["ago": LiveRules.ago(l10n, then: $0.updatedAt.ms, now: now)]) } ?? l10n.t("detail.timetableOnly"))
                .clack(.caption).foregroundStyle(Ink.text2)
        }
    }

    /// "Directions to Stockholm C": Apple Maps, to the station you get on at.
    @ViewBuilder
    private func directions(_ detail: LegDetail) -> some View {
        if !detail.leg.canceled, let board = Directions.target(detail.stops), let url = Directions.appleMaps(lat: board.lat, lon: board.lon) {
            Link(destination: url) {
                HStack(spacing: 8) {
                    LucideIcon(name: "navigation", size: 16)
                    Text(l10n.t("detail.directions", ["station": board.name]))
                }
            }
            .buttonStyle(.clack())
        }
    }

    // MARK: during: where it is, what's next

    @ViewBuilder
    private func liveNow(_ detail: LegDetail, now: Double) -> some View {
        let m = moment(detail, now: now)
        if let shown = m.shown {
            Card {
                if TripDetailLogic.getOffNext(detail.stops, shown: shown, stage: m.stage), let alight = detail.stops.first(where: { $0.role == .alight }) {
                    HStack(spacing: 8) {
                        LucideIcon(name: "map-pin", size: 16).foregroundStyle(Ink.accentInk)
                        Text(l10n.t("detail.getOffNext", ["name": alight.name])).clack(.rowTitle).foregroundStyle(Ink.accentInk)
                    }
                    .accessibilityElement(children: .combine)
                }
                LiveModule(leg: detail.leg, live: shown, stops: detail.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) }, now: now)
            }
        }
    }

    // MARK: after: how it went

    @ViewBuilder
    private func result(_ detail: LegDetail) -> some View {
        let l = detail.leg
        let dtz = l.destination?.tz ?? "Europe/Stockholm"
        let arrived = l.actualArr?.ms
        Card {
            // Just arrived: welcome first.
            if !l.canceled, let at = arrived ?? l.schedArr?.ms, Date.now.timeIntervalSince1970 * 1000 - at < 60 * 60_000 {
                Text(l10n.t("progress.welcome", ["station": l.destination?.name ?? ""])).clack(.welcomeTitle).foregroundStyle(Ink.text)
            }
            // "Arrived 10:55" and the delay beside it.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(
                    l.canceled ? l10n.t("status.cancelled")
                        : arrived != nil ? l10n.t("trips.arrivedAt", ["time": Format.time(arrived, tz: dtz, clock: app.settings.clock)])
                        : l10n.t("detail.scheduledArrival", ["time": Format.time(l.schedArr?.ms, tz: dtz, clock: app.settings.clock)])
                )
                .clack(.headline).foregroundStyle(Ink.text)
                if !l.canceled, arrived != nil { DelayText(delay: l.arrDelayMin) }
            }
            if !l.canceled {
                Text(explanationText(arrived == nil ? nil : l.arrDelayMin)).clack(.caption).foregroundStyle(Ink.text2)
            }
            ride(l)
            // What the trip did for your Passport.
            if l.ride == .auto || l.ride == .confirmed { TripProgressView(legId: l.id, quietIfNothing: true) }
        }
    }

    /// Whether the trip counts: a check to answer, a way to correct it, or why it doesn't count.
    @ViewBuilder
    private func ride(_ l: Leg) -> some View {
        // Why it doesn't count (or needs a check); a trip that counts needs no line about it.
        if l.ride != .auto && l.ride != .confirmed {
            Text(l10n.t("record.state.\(l.ride.rawValue)", ["why": l10n.t("record.why.\(l.rideReason ?? "no_reports")")]))
                .clack(.stopName).foregroundStyle(l.ride == .review ? Ink.lateInk : Ink.text)
        }
        FlowLayout(spacing: 16, lineSpacing: 8) {
            if l.ride == .review {
                Button(l10n.t("record.yes")) { Task { await answer(.yes) } }.buttonStyle(.clack(.primary, small: true))
                Button(l10n.t("record.no")) { Task { await answer(.no) } }.buttonStyle(.clack(small: true))
            }
            if l.ride == .notTaken {
                Button(l10n.t("record.undo")) { Task { await answer(.undo) } }.buttonStyle(LinkButtonStyle())
            }
        }
        // A trip that counts leads to the Passport, as a row (correcting it is in the … menu).
        if l.ride == .auto || l.ride == .confirmed {
            Button {
                router.tab = .passport
            } label: {
                HStack(spacing: 12) {
                    LucideIcon(name: "stamp", size: 18).foregroundStyle(Ink.accentInk)
                    Text(l10n.t("detail.seePassport")).clack(.rowTitle).foregroundStyle(Ink.text)
                    Spacer(minLength: 8)
                    LucideIcon(name: "chevron-right", size: 16).foregroundStyle(Ink.text3)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: times

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
                canceled: l.canceled, onSetPlatform: platformAction(.dep, l)
            )
            TimeBlock(
                label: l10n.t("detail.arrival"), sched: schedArr, actual: l.actualArr?.ms ?? (tracking ? live?.arrivalEta?.ms : nil),
                tz: dtz, platform: l.arrPlatform, delay: l.arrDelayMin ?? (tracking ? live?.arrivalDelayMin : nil),
                canceled: l.canceled, extraDays: extraDays, onSetPlatform: platformAction(.arr, l)
            )
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

    // MARK: stops

    private func stopsCard(_ detail: LegDetail, color: Color, now: Double) -> some View {
        let m = moment(detail, now: now)
        let shown = m.shown, stage = m.stage
        let stops = TripDetailLogic.timelineStops(detail.stops, stage: stage, shown: shown, fullRoute: fullRoute)
        // How far along the line the train is, so the rail shows it between the stops too.
        let fills = TripDetailLogic.segmentFills(stops: stops, route: routeGeo(detail).route, shown: shown, stage: stage, now: now)
        let halves = TripDetailLogic.railHalves(stops: stops, fills: fills, showTrain: stage == .during)
        let hasHidden = fullRoute || stops.count < detail.stops.count
        return Card {
            Text(l10n.t("detail.stops")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            VStack(spacing: 0) {
                ForEach(Array(stops.enumerated()), id: \.element.id) { i, stop in
                    LegStopRow(
                        stop: stop, color: color, tense: TripDetailLogic.tense(of: stop, shown: shown, stage: stage),
                        above: halves[i].above, below: halves[i].below,
                        onSetPlatform: stop.role == .board ? platformAction(.dep, detail.leg) : stop.role == .alight ? platformAction(.arr, detail.leg) : nil
                    )
                }
            }
            if hasHidden {
                Button(fullRoute ? l10n.t("detail.hideFullRoute") : l10n.t("detail.showFullRoute")) { fullRoute.toggle() }
                    .buttonStyle(LinkButtonStyle())
            }
        }
    }

    // MARK: about this train

    /// One disclosure, closed at first: the train, on board, the details and the activity log.
    @ViewBuilder
    private func about(_ detail: LegDetail, tracking: Bool) -> some View {
        let l = detail.leg
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { aboutOpen.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Text(l10n.t("detail.aboutTrain")).clack(.rowTitle).foregroundStyle(Ink.text)
                    Spacer(minLength: 0)
                    LucideIcon(name: "chevron-down", size: 18).foregroundStyle(Ink.text2)
                        .rotationEffect(.degrees(aboutOpen ? 180 : 0))
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(l10n.t(aboutOpen ? "common.less" : "common.more"))
            .id("about")
            if aboutOpen {
                TrainCard(leg: detail) { leg = $0 }.id("train")
                Card {
                    Text(l10n.t("onboard.title")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    OnboardView(facts: l.onboard, operatorId: l.operator?.id, trainType: l.trainType)
                }
                .id("onboard")
                detailsCard(detail).id("details")
                if tracking || !detail.events.isEmpty {
                    ActivityLog(leg: l, events: detail.events, stops: detail.stops.map { StopName(stationId: $0.stationId, name: $0.name, tz: $0.tz) })
                        .id("activity")
                }
            }
        }
        .overlay(alignment: .top) { Rectangle().fill(Ink.hairline).frame(height: 1) }
    }

    private func detailsCard(_ detail: LegDetail) -> some View {
        let l = detail.leg
        let beyond = TripDetailLogic.beyondCountries(detail.stops)
        let dep = l.actualDep?.ms ?? l.schedDep?.ms
        let arr = l.actualArr?.ms ?? l.schedArr?.ms
        return Card(spacing: 12) {
            Text(l10n.t("detail.details")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            HStack(alignment: .top, spacing: 12) {
                Tile(
                    label: l10n.t("detail.distance"),
                    value: (l.isEstimatedGeometry ? "≈ " : "") + Format.distance(l.distanceM, unit: app.settings.distanceUnit, language: app.settings.language)
                )
                Tile(label: l10n.t("detail.duration"), value: (dep != nil && arr != nil) ? Format.duration((arr! - dep!) / 60_000) : Format.unknown)
            }
            SeatEditor(leg: l) { leg = $0 }
            if l.dataQuality != .full && !(l.dataQuality == .partial && !beyond.isEmpty) {
                Chip(text: l10n.t("detail.quality.\(l.dataQuality.rawValue)"))
            }
            if !beyond.isEmpty {
                let countries = beyond.map { code -> String in
                    let key = "countries.\(code)"
                    let name = l10n.t(key)
                    return name == key ? code : name
                }.joined(separator: ", ")
                Text(l10n.t("detail.beyondLiveData", ["countries": countries]))
                    .clack(.caption).foregroundStyle(Ink.text2)
            }
        }
    }

    /// The trip's less common actions, in the system's menu over the map: fresh times, "I didn't take this train"
    /// and deleting the trip.
    private func moreMenu(_ l: Leg) -> some View {
        Menu {
            if l.status != .snapshotted {
                Button { Task { await refresh() } } label: { Label(l10n.t("detail.refresh"), systemImage: "arrow.clockwise") }
                    .disabled(busy)
            }
            if l.ride == .auto || l.ride == .confirmed {
                Button { Task { await answer(.no) } } label: { Label(l10n.t("record.correctNo"), systemImage: "xmark.circle") }
            }
            Divider()
            Button(role: .destructive) { confirmDelete = true } label: { Label(l10n.t("detail.delete"), systemImage: "trash") }
        } label: {
            MapButtonFace(icon: "", symbol: "ellipsis")
        }
        .buttonStyle(.plain)
        .tint(Ink.text)
        .accessibilityLabel(l10n.t("detail.more"))
        .accessibilityIdentifier("trip.more")
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
    /// Asks for the platform when none is known (your own trip).
    var onSetPlatform: (() -> Void)?

    var body: some View {
        let changed = actual != nil && sched != nil && floor(actual! / 60_000) != floor(sched! / 60_000)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(label).clack(.captionUpper).foregroundStyle(Ink.text2).lineLimit(1)
                Spacer(minLength: 0)
                DelayText(delay: delay, canceled: canceled)
            }
            .frame(minHeight: 26)
            Text(Format.time(sched, tz: tz, clock: app.settings.clock))
                .clack(.struck).strikethrough().monospacedDigit().foregroundStyle(Ink.text3)
                .opacity(changed ? 1 : 0)
                .accessibilityHidden(!changed)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                SplitFlap(value: Format.time(actual ?? sched, tz: tz, clock: app.settings.clock), size: .time, intro: true)
                    .opacity(canceled ? 0.6 : 1)
                    .overlay { if canceled { Rectangle().fill(Ink.text).frame(height: 1.5) } }
                if extraDays > 0 { Text("+\(extraDays)").clack(.captionUpper).foregroundStyle(Ink.text2) }
            }
            HStack(spacing: 8) {
                if let platform {
                    Chip(text: l10n.t("trips.platform", ["platform": platform]))
                        .onTapGesture { onSetPlatform?() }
                } else if let onSetPlatform {
                    // Nothing knows it: a dash you can tap to say which.
                    Button(action: onSetPlatform) {
                        Label { Text(l10n.t("trips.platform", ["platform": "—"])) } icon: { LucideIcon(name: "plus", size: 12) }
                            .clack(.chip).foregroundStyle(Ink.text2)
                            .frame(minHeight: 44).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.t("platform.add"))
                    .accessibilityIdentifier("platform.add")
                } else {
                    Chip(text: l10n.t("trips.platform", ["platform": "—"])).foregroundStyle(Ink.text3)
                }
            }
        }
        .tileSurface()
    }
}

/// One stop of the trip's timeline (the shared `StopRow`): the rail in the operator's colour, where you got on and off,
/// the time coloured by delay once it is known, the platform; the name opens the station's board.
struct LegStopRow: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let stop: LegStop
    let color: Color
    var tense = TripDetailLogic.StopTense.past
    var above = TripDetailLogic.RailHalf()
    var below = TripDetailLogic.RailHalf()
    var onSetPlatform: (() -> Void)?

    var body: some View {
        let times = TripDetailLogic.stopTimes(stop)
        let ridden = stop.role.isRidden
        let causes = l10n.causeNotes(stop.allCauses)
        var notes: [StopRow.Note] = []
        if stop.role == .board { notes.append(.init(l10n.t(tense == .past ? "detail.gotOn" : tense == .present ? "detail.gettingOn" : "detail.willGetOn"), .accent)) }
        if stop.role == .alight { notes.append(.init(l10n.t(tense == .past ? "detail.gotOff" : tense == .present ? "detail.gettingOff" : "detail.willGetOff"), .accent)) }
        if ridden && stop.reportSource == nil { notes.append(.init(l10n.t("detail.noLiveData"))) }
        if !causes.isEmpty { notes.append(.init(Format.join(causes))) }
        let end = stop.role == .board || stop.role == .alight
        return StopRow(
            name: stop.name, emphasis: ridden ? .ridden : .dim, canceled: stop.canceled, notes: notes,
            rail: StopRail(color: color, big: end, ridden: ridden, startsHere: stop.role == .board, endsHere: stop.role == .alight, above: above, below: below),
            time: times.actual ?? times.sched, sched: times.sched, live: times.actual != nil, delay: times.delay,
            tz: stop.tz, clock: app.settings.clock, platform: stop.platform, platformChanged: stop.deviations.contains("Spårändrat") || stop.allCauses.contains(where: { DelayCauses.isPlatformChange($0) }),
            onSetPlatform: stop.platform == nil ? onSetPlatform : nil,
            onOpen: { router.push(.board(stationId: stop.stationId, arrivals: false)) },
            openLabel: l10n.t("board.openBoard", ["station": stop.name])
        )
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
