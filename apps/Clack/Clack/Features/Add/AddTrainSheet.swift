//
//  AddTrainSheet.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI

/// Add a train (DESIGN §5): date, one smart search field, results, "Where did you get on and off?", saved. A
/// full-height sheet over everything (AddTripPage.tsx).
struct AddTrainSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    let request: Router.AddRequest
    @State private var model = AddTrainModel()

    var body: some View {
        SheetFrame(title: l10n.t("add.title"), onClose: { router.closeAdd() }) {
            content
        }
        .environment(model)
        .task { await model.loadPopular(app.client) }
        .task {
            if let link = request.link { await model.prefill(link, app.client) }
        }
        .task(id: model.searchKey) { await model.runSearch(app.client) }
        .task(id: model.response?.history) { await model.waitForHistory() }
        .task(id: model.response?.journeysPending == true) { await model.waitForJourneys() }
        #if DEBUG
        // `-addPickJourney`: opens the first planned journey once the list is in (to look at its page).
        .task(id: model.journeys?.count ?? -1) {
            if CommandLine.arguments.contains("-addPickJourney"), model.pickedJourney == nil, let first = model.journeys?.first { model.pickedJourney = first }
        }
        #endif
        .task(id: model.date) { await model.prepareHistory(app.client) }
        .sensoryFeedback(.success, trigger: model.saved?.id)
    }

    @ViewBuilder
    private var content: some View {
        if let saved = model.saved {
            DoneStep(leg: saved) { model.reset() }
        } else if model.manual {
            ManualTripStep(date: model.date, from: model.interpretation?.from, to: model.interpretation?.to) { model.manual = false } onSaved: { model.didSave($0, app.client); app.tripsChanged() }
        } else if let journey = model.pickedJourney {
            PlannedJourneyStep(journey: journey) { model.pickedJourney = nil } onSaved: { model.didSave($0, app.client); app.tripsChanged() }
        } else if let connection = model.pickedConnection {
            ConfirmConnectionStep(connection: connection) { model.pickedConnection = nil } onSaved: { model.didSave($0, app.client); app.tripsChanged() }
        } else if let picked = model.picked {
            ConfirmStep(
                result: picked, originChosen: model.originChosen, backLabel: model.openedWithTrip ? l10n.t("common.back") : nil,
                onBack: { model.openedWithTrip ? router.closeAdd() : (model.picked = nil) }, onSaved: { model.didSave($0, app.client); app.tripsChanged() }
            )
        } else {
            SearchStep()
        }
    }
}

// MARK: search

private struct SearchStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(AddTrainModel.self) private var model
    @FocusState private var focused: Bool
    @State private var showJourneyFilters = false

    var body: some View {
        @Bindable var model = model
        DateRow(date: $model.date, tz: Format.zone(country: model.interpretation?.from?.country))
        SearchField(text: $model.query, prompt: l10n.t("add.placeholder"), focus: $focused)
            .onAppear { focused = true }
            // Searching gives the results the whole screen: the keyboard and the station suggestions go away.
            .onSubmit {
                focused = false
                model.searchAgain()
            }

        if model.query.isEmpty {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                Text(l10n.t("add.examples")).clack(.caption).foregroundStyle(Ink.text2)
                ForEach(AddTrainLogic.examples, id: \.self) { example in
                    ChipButton(text: example) { model.query = example }
                }
            }
        }
        if model.searchFailed { Banner(kind: .error) { Text(l10n.t("add.searchError")) }.countsError("add.search") }

        if model.query.isEmpty {
            Text(l10n.t("add.popular")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            stationList(model.popular)
        } else if let response = model.response {
            results(response)
        } else if model.loading {
            VStack(spacing: 12) {
                Skeleton(height: 120)
                Skeleton(height: 120)
            }
        }
    }

    private func pick(_ station: StationHit) {
        model.query = AddTrainLogic.query(afterPicking: station, query: model.query, interpretation: model.interpretation)
        focused = true
    }

    private func stationList(_ stations: [StationHit]) -> some View {
        VStack(spacing: 0) {
            ForEach(stations) { station in StationRow(station: station) { pick(station) } }
        }
    }

    /// Above the journeys: how many there are, which filters are on, and the Filters button (as Explore's), which opens
    /// the two choices in a small sheet. Filters are set rarely, so they don't take the results' space (owner, 2026-10-28).
    private func journeyFilterBar(count: Int) -> some View {
        let active = (model.maxChanges < 2 ? 1 : 0) + (model.minComfort > 0 && model.maxChanges > 0 ? 1 : 0)
        let summary = [
            model.maxChanges < 2 ? l10n.t(["add.changesNone", "add.changesOne", "add.changesTwo"][model.maxChanges]) : nil,
            model.minComfort > 0 && model.maxChanges > 0 ? l10n.t(["add.comfortAny", "add.comfortNormal", "add.comfortRelaxed"][model.minComfort]) : nil,
        ].compactMap { $0 }.joined(separator: Format.separator)
        return HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("add.journeyCount", count: count)).clack(.rowTitle).foregroundStyle(Ink.text)
                if !summary.isEmpty { Text(summary).clack(.caption).foregroundStyle(Ink.text2) }
            }
            Spacer(minLength: 8)
            ChipButton(text: active > 0 ? l10n.t("add.filtersOn", ["n": String(active)]) : l10n.t("liveMap.filters"), active: active > 0) {
                showJourneyFilters = true
            }
            .accessibilityHint(l10n.t("add.filtersHint"))
        }
        .sheet(isPresented: $showJourneyFilters) {
            JourneyFilterSheet(model: model) { showJourneyFilters = false }
                .presentationDetents([.height(model.maxChanges > 0 ? 300 : 190)])
        }
    }

    @ViewBuilder
    private func results(_ response: SearchResponse) -> some View {
        if response.journeysPending == true {
            // The planner is building the day: the direct trains now, the journeys with changes in a moment.
            HStack(spacing: 8) {
                ProgressView()
                Text(l10n.t("add.journeysPending")).clack(.caption).foregroundStyle(Ink.text2)
            }
        }
        if response.journeys != nil, response.interpretation.from != nil, response.interpretation.to != nil, !response.outsideTimetable {
            journeyResults(response)
        } else {
            trainResults(response)
        }
    }

    /// Two stations: the planner's journeys, direct and with changes in one list, by departure; a filter for how many
    /// changes (it filters, it doesn't sort), and when it leaves nothing, the offer to include more changes.
    @ViewBuilder
    private func journeyResults(_ response: SearchResponse) -> some View {
        // While typing, the stations to pick from; once the search is sent, only the results.
        if focused, !response.suggestions.isEmpty {
            Text(l10n.t("add.stations")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            stationList(response.suggestions)
        }
        journeyFilterBar(count: model.journeys?.count ?? 0)
        if model.hasHiddenEarlierJourneys {
            Button(l10n.t("board.showEarlier")) { model.showEarlier = true }.buttonStyle(LinkButtonStyle())
        }
        if let list = model.journeys, !list.isEmpty {
            VStack(spacing: 16) {
                ForEach(list) { journey in JourneyResultCard(journey: journey) { model.pickedJourney = journey } }
            }
        } else if model.moreWithMoreChanges {
            Text(l10n.t("add.noJourneyWithFilter")).clack(.body).foregroundStyle(Ink.text2)
            Button(l10n.t("add.includeMoreChanges")) {
                model.maxChanges = 2
                model.minComfort = 0
            }
            .buttonStyle(.clack(wide: true))
        } else {
            Text(l10n.t("add.noJourney")).clack(.body).foregroundStyle(Ink.text2)
        }
        Button(l10n.t("manual.cta")) { model.manual = true }
            .buttonStyle(LinkButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    @ViewBuilder
    private func trainResults(_ response: SearchResponse) -> some View {
        let interpretation = response.interpretation
        let hasResults = !(response.results ?? []).isEmpty
        if !response.suggestions.isEmpty
            && !(interpretation.to != nil && response.suggestions.first?.id == interpretation.to?.id && hasResults) {
            Text(l10n.t("add.stations")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            stationList(response.suggestions)
        }
        if response.outsideTimetable {
            Banner {
                Text(historyMessage(response))
            }
        }
        if let list = response.results, !list.isEmpty {
            FlowLayout(spacing: 8, lineSpacing: 8) {
                ForEach(AddTrainLogic.Filter.allCases, id: \.self) { filter in
                    ChipButton(text: l10n.t("add.filter\(filter == .all ? "All" : filter == .long ? "Long" : filter == .regional ? "Regional" : "Commuter")"), active: model.filter == filter) { model.filter = filter }
                }
            }
            if model.hasHiddenEarlier {
                Button(l10n.t("board.showEarlier")) { model.showEarlier = true }.buttonStyle(LinkButtonStyle())
            }
            VStack(spacing: 16) {
                ForEach(model.results ?? []) { result in
                    ResultCard(result: result) { model.pick(result) }
                }
            }
        }
        if let list = response.results, list.isEmpty, !response.outsideTimetable {
            Text(interpretation.trainNumber.map { l10n.t("add.noTrain", ["number": $0]) }
                ?? ((response.connections ?? []).isEmpty ? l10n.t("add.noDirect") : l10n.t("add.noDirectChange")))
                .clack(.body).foregroundStyle(Ink.text2)
        }
        if let list = response.results, list.isEmpty, let connections = response.connections, !connections.isEmpty {
            Text(l10n.t("add.withChange")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            VStack(spacing: 16) {
                ForEach(connections) { connection in ConnectionResultCard(connection: connection) { model.pickedConnection = connection } }
            }
        }
        if response.outsideTimetable ? response.history != "loading" : response.results != nil {
            Button(l10n.t("manual.cta")) { model.manual = true }
                .buttonStyle(LinkButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    /// Why an older day has no results yet: being fetched, failed, or before the record (Norway and Finland say from when).
    private func historyMessage(_ response: SearchResponse) -> String {
        switch response.history {
        case "loading": return l10n.t("add.historyLoading")
        case "failed": return l10n.t("add.historyFailed")
        case "norway", "finland":
            let from = response.historyFrom.flatMap(Format.isoToNoonMs).map { Format.fullDate($0, tz: "UTC", language: app.settings.language) } ?? ""
            return l10n.t(response.history == "norway" ? "add.historyNorway" : "add.historyFinland", ["date": from])
        default: return l10n.t("add.historyUnavailable")
        }
    }
}

/// Today, tomorrow, or a date to pick, with the chosen day written beside.
private struct DateRow: View {
    @Environment(L10n.self) private var l10n
    @Environment(AppModel.self) private var app
    @Binding var date: String
    /// The zone of the station the trip starts at, when the search named it: "today" is its day (Helsinki is an hour
    /// ahead of Stockholm).
    var tz = Format.defaultZone
    @State private var picking = false

    var body: some View {
        let today = Format.todayIso(tz: tz)
        let tomorrow = Format.addDaysIso(today, days: 1)
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ChipButton(text: l10n.t("add.today"), active: date == today) { date = today }
            ChipButton(text: l10n.t("add.tomorrow"), active: date == tomorrow) { date = tomorrow ?? date }
            ChipButton(text: l10n.t("add.pickDate"), active: date != today && date != tomorrow) { picking = true }
            HStack(spacing: 0) {
                Text(Format.day(Format.isoToNoonMs(date) ?? 0, tz: "UTC", language: app.settings.language))
                    .fontWeight(.semibold).foregroundStyle(Ink.text)
                if date < today {
                    Text(" · \(l10n.t("add.pastTrip"))").foregroundStyle(Ink.slightInk).fontWeight(.medium)
                }
            }
            .clack(.body).padding(.leading, 4)
        }
        .sheet(isPresented: $picking) {
            let maxDate = AddTrainLogic.date(fromIso: Format.addDaysIso(today, days: 365) ?? today, tz: tz) ?? .now
            VStack(spacing: 12) {
                DatePicker(
                    l10n.t("add.pickDate"),
                    selection: Binding(get: { AddTrainLogic.date(fromIso: date, tz: tz) ?? .now }, set: { date = AddTrainLogic.iso(from: $0, tz: tz) }),
                    in: ...maxDate, displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(Ink.accent)
                Button(l10n.t("common.done")) { picking = false }.buttonStyle(.clack(.primary, wide: true))
            }
            .padding(16)
            .presentationDetents([.medium])
            .presentationBackground(Ink.surface)
            .presentationCornerRadius(Radius.sheet)
        }
    }
}

// MARK: results

private struct ResultCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let result: TripResult
    let onPick: () -> Void

    var body: some View {
        let op = result.operatorId.flatMap { app.operatorsById[$0] }
        let type = result.trainType.flatMap { id in app.trainTypes.first { $0.id == id } }
        let plus = Format.dayOffset(from: result.from.time, fromTz: result.from.tz, to: result.to.time, toTz: result.to.tz)
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(Format.time(result.from.time, tz: result.from.tz, clock: app.settings.clock)).clack(.bigTime).foregroundStyle(Ink.text)
                    Text(Format.duration(Double(result.durationMin)))
                        .clack(.caption).foregroundStyle(Ink.text2)
                        .frame(maxWidth: .infinity)
                        .background { DashedHorizontalLine() }
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Format.time(result.to.time, tz: result.to.tz, clock: app.settings.clock)).clack(.bigTime).foregroundStyle(Ink.text)
                        if plus > 0 { TimePair.plusText(plus) }
                    }
                }
                .monospacedDigit()
                HStack(spacing: 12) {
                    Text(result.from.name)
                    Spacer(minLength: 0)
                    Text(result.to.name).multilineTextAlignment(.trailing)
                }
                .clack(.stopName).fontWeight(.semibold).foregroundStyle(Ink.text2)
                if let type {
                    HStack(spacing: 12) {
                        TrainPicture(type: type, operatorId: result.operatorId, height: 28).frame(width: 120, alignment: .leading).clipped()
                        Text(type.name).clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
                ServiceHeader(op: op, number: result.trainNumber, size: .medium, category: result.product, name: op == nil ? result.routeName : nil)
                Text(Format.join([
                    result.stopsBetween > 0 ? l10n.t("add.stopsBetween", count: result.stopsBetween) : l10n.t("add.direct"),
                    result.alsoKnownAs.isEmpty ? nil : l10n.t("add.alsoKnownAs", ["numbers": result.alsoKnownAs.joined(separator: ", ")]),
                ]))
                .clack(.caption).foregroundStyle(Ink.text2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DashedHorizontalLine: View {
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                path.move(to: CGPoint(x: proxy.size.width * 0.06, y: proxy.size.height / 2))
                path.addLine(to: CGPoint(x: proxy.size.width * 0.94, y: proxy.size.height / 2))
            }
            .stroke(Ink.text3, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }
}

/// Two trains and the change between them, as one option.
private struct ConnectionResultCard: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let connection: TimetableConnection
    var onPick: (() -> Void)?

    var body: some View {
        let first = connection.first
        let second = connection.second
        let total = Double(Int(((second.to.time - first.from.time) / 60_000).rounded()))
        let plus = Format.dayOffset(from: first.from.time, fromTz: first.from.tz, to: second.to.time, toTz: second.to.tz)
        let card = VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(Format.time(first.from.time, tz: first.from.tz, clock: app.settings.clock)).clack(.bigTime).foregroundStyle(Ink.text)
                Text(Format.duration(total)).clack(.caption).foregroundStyle(Ink.text2).frame(maxWidth: .infinity).background { DashedHorizontalLine() }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(Format.time(second.to.time, tz: second.to.tz, clock: app.settings.clock)).clack(.bigTime).foregroundStyle(Ink.text)
                    if plus > 0 { TimePair.plusText(plus) }
                }
            }
            .monospacedDigit()
            ForEach([first, second], id: \.id) { result in
                let op = result.operatorId.flatMap { app.operatorsById[$0] }
                VStack(alignment: .leading, spacing: 2) {
                    ServiceHeader(op: op, number: result.trainNumber, size: .small, name: op == nil ? result.routeName : nil)
                    (TimePair.text(.init(time: result.from.time, tz: result.from.tz), .init(time: result.to.time, tz: result.to.tz), clock: app.settings.clock)
                        + Text(Format.separator + "\(result.from.name) → \(result.to.name)"))
                        .clack(.caption).foregroundStyle(Ink.text2).lineLimit(2)
                }
            }
            Text(l10n.t("add.changeAt", ["station": connection.changeAt.name, "min": String(connection.changeMin)])).clack(.caption).foregroundStyle(Ink.text2)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        Group {
            if let onPick { Button(action: onPick) { card }.buttonStyle(.plain) } else { card }
        }
    }
}

// MARK: confirm

/// "Where did you get on and off?": the train's stops, with the two ends to choose (AddTripPage.tsx `Confirm`).
private struct ConfirmStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(\.colorScheme) private var scheme
    let result: TripResult
    var backLabel: String?
    let onBack: () -> Void
    let onSaved: (LegDetail) -> Void

    @State private var trip: TimetableTrip?
    @State private var geometry: TripGeometry?
    @State private var picked: AddTrainLogic.Picked
    @State private var duplicate = false
    @State private var error: String?
    @State private var saving = false

    init(result: TripResult, originChosen: Bool, backLabel: String? = nil, onBack: @escaping () -> Void, onSaved: @escaping (LegDetail) -> Void) {
        self.result = result
        self.backLabel = backLabel
        self.onBack = onBack
        self.onSaved = onSaved
        // Where you got on first, then where you got off; unless the search already said where you got on.
        _picked = State(initialValue: AddTrainLogic.initialPick(result, originChosen: originChosen))
    }

    var body: some View {
        let op = result.operatorId.flatMap { app.operatorsById[$0] }
        let hex = MapStyle.opColor(op?.brandColor, dark: scheme == .dark)
        let color = operatorColor(op?.brandColor, scheme: scheme)
        let from = trip?.stops.first { $0.seq == picked.fromSeq }
        let to = trip?.stops.first { $0.seq == picked.toSeq }
        let dep = (from?.dep ?? from?.arr)?.ms
        let arr = (to?.arr ?? to?.dep)?.ms
        Button(action: onBack) {
            HStack(spacing: 8) {
                LucideIcon(name: "arrow-left", size: 18)
                Text(backLabel ?? l10n.t("add.back"))
            }
        }
        .buttonStyle(LinkButtonStyle())
        Text(l10n.t("add.confirmTitle")).clack(.headline).foregroundStyle(Ink.text)
        if let trip {
            let map = AddTrainLogic.mapRoute(stops: trip.stops, geometry: geometry, fromSeq: picked.fromSeq, toSeq: picked.toSeq)
            let ridden = trip.stops.filter { $0.seq >= picked.fromSeq && $0.seq <= picked.toSeq }
            RouteMapView(
                color: hex, route: map.route, context: map.context,
                stops: ridden.map { MapStop(lat: $0.lat, lon: $0.lon, name: $0.name, kind: $0.seq == picked.fromSeq || $0.seq == picked.toSeq ? .end : .mid) },
                interactive: false, controls: false,
                label: from.flatMap { f in to.map { l10n.t("detail.mapLabel", ["from": f.name, "to": $0.name]) } }
            )
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        }
        ServiceHeader(op: op, number: result.trainNumber, size: .medium, category: result.product, name: op == nil ? result.routeName : nil)
        if let from, let to, let dep, let arr, let trip {
            let d = AddTrainLogic.distance(stops: trip.stops, geometry: geometry, fromSeq: picked.fromSeq, toSeq: picked.toSeq)
            (Text("\(from.name) → \(to.name)").fontWeight(.semibold).foregroundStyle(Ink.text)
                + Text(" · \(d.approximate ? "≈ " : "")\(Format.distance(d.metres, unit: app.settings.distanceUnit, language: app.settings.language)) · \(Format.duration((arr - dep) / 60_000))").foregroundStyle(Ink.text2))
                .clack(.body)
        }
        endPicker(from: from, to: to)
        Text(picked.picking == .from ? l10n.t("add.tapFrom") : l10n.t("add.tapTo")).clack(.caption).foregroundStyle(Ink.text2)
        VStack(spacing: 0) {
            ForEach(trip?.stops ?? []) { stop in stopRow(stop, color: color) }
        }
        if duplicate {
            Banner(kind: .warn) {
                Text(l10n.t("add.duplicate"))
                HStack(spacing: 8) {
                    Button(l10n.t("add.addAnyway")) { Task { await save(force: true) } }.buttonStyle(.clack(.primary, small: true)).disabled(saving)
                    Button(l10n.t("add.cancel")) { duplicate = false }.buttonStyle(.clack(small: true))
                }
            }
        }
        if let error { Banner(kind: .error) { Text(l10n.t("add.saveError", ["message": error])) } }
        Button(l10n.t("add.addToClack")) { Task { await save(force: false) } }
            .buttonStyle(.clack(.primary, wide: true))
            .disabled(trip == nil || saving || duplicate)
            .padding(.top, 8)
            .task(id: result.id) { await load() }
    }

    private func endPicker(from: TripStop?, to: TripStop?) -> some View {
        HStack(spacing: 4) {
            ForEach([AddTrainLogic.End.from, .to], id: \.self) { end in
                let active = picked.picking == end
                Button {
                    picked.picking = end
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t(end == .from ? "add.from" : "add.to")).clack(.captionUpper).foregroundStyle(active ? Ink.onAccent : Ink.text2)
                        Text((end == .from ? from : to)?.name ?? "—").clack(.rowTitle).foregroundStyle(active ? Ink.onAccent : Ink.text).lineLimit(1)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(active ? Ink.accent : .clear, in: RoundedRectangle(cornerRadius: Radius.input - 3, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .hairlineBorder(radius: Radius.input)
        .accessibilityLabel(l10n.t("add.tapToChoose"))
    }

    private func stopRow(_ stop: TripStop, color: Color) -> some View {
        let role = AddTrainLogic.role(stop, in: picked)
        let end = role == .from || role == .to
        let time = stop.seq == picked.toSeq ? (stop.arr ?? stop.dep) : (stop.dep ?? stop.arr)
        let restriction: String? = picked.picking == .from && stop.noPickup && stop.seq < picked.toSeq ? l10n.t("add.noBoarding")
            : picked.picking == .to && stop.noDropoff && stop.seq > picked.fromSeq ? l10n.t("add.noAlighting") : nil
        let selectable = AddTrainLogic.isSelectable(stop, in: picked)
        // The ride between the two ends is drawn as travelled (the operator's colour); the rest is a hairline.
        let inRide = role == .between || end
        let above = TripDetailLogic.RailHalf(ridden: inRide && role != .from, fill: inRide && role != .from ? 1 : 0)
        let below = TripDetailLogic.RailHalf(ridden: inRide && role != .to, fill: inRide && role != .to ? 1 : 0)
        let stops = trip?.stops ?? []
        var notes: [StopRow.Note] = []
        if end { notes.append(.init(l10n.t(role == .from ? "add.from" : "add.to"), .accent)) }
        if let restriction { notes.append(.init(restriction)) }
        return Button {
            if let next = AddTrainLogic.tap(stop, in: picked) {
                picked = next
                duplicate = false
            }
        } label: {
            StopRow(
                name: stop.name, emphasis: role == .outside ? .dim : end ? .ridden : .plain, notes: notes,
                rail: StopRail(
                    color: color, big: end, ridden: inRide, startsHere: stop.seq == stops.first?.seq, endsHere: stop.seq == stops.last?.seq,
                    above: above, below: below
                ),
                time: time?.ms, tz: stop.tz, clock: app.settings.clock, compact: true
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // A stop that can't become the end being chosen does nothing when tapped (it isn't dimmed, as on the web).
        .allowsHitTesting(selectable || end)
    }

    private func load() async {
        // Both at once: the stops shouldn't wait for the map. The mini map is a nice-to-have: without it the summary
        // falls back to straight-line distance.
        async let route = try? app.client.timetableTripGeometry(result.key, date: result.serviceDate)
        do {
            trip = try await app.client.timetableTrip(result.key, date: result.serviceDate)
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        geometry = await route
    }

    private func save(force: Bool) async {
        saving = true
        error = nil
        do {
            onSaved(try await app.client.createLeg(CreateLegBody(
                tripKey: result.key, serviceDate: result.serviceDate, fromSeq: picked.fromSeq, toSeq: picked.toSeq, force: force ? true : nil
            )))
        } catch let apiError as APIError where apiError.status == 409 {
            duplicate = true
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        saving = false
    }
}

/// Saving both trains of a connection: each checked for a duplicate like a single train.
private struct ConfirmConnectionStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let connection: TimetableConnection
    let onBack: () -> Void
    let onSaved: (LegDetail) -> Void
    @State private var saving = false
    @State private var dupes: [Int] = []
    @State private var kept: LegDetail?
    @State private var error: String?

    var body: some View {
        let legs = [connection.first, connection.second]
        Button(action: onBack) {
            HStack(spacing: 8) {
                LucideIcon(name: "arrow-left", size: 18)
                Text(l10n.t("add.back"))
            }
        }
        .buttonStyle(LinkButtonStyle())
        Text(l10n.t("add.connectionTitle")).clack(.headline).foregroundStyle(Ink.text)
        ConnectionResultCard(connection: connection)
        InfoNote(l10n.t("add.connectionNote"), more: l10n.t("add.connectionNoteMore"))
        if !dupes.isEmpty {
            Banner(kind: .warn) {
                Text(dupes.count == legs.count ? l10n.t("add.duplicate") : l10n.t("add.duplicateOne", ["train": legs[dupes[0]].trainNumber ?? ""]))
                HStack(spacing: 8) {
                    if let kept { Button(l10n.t("add.keepAsIs")) { onSaved(kept) }.buttonStyle(.clack(small: true)) }
                    Button(l10n.t("add.addAnyway")) { Task { await save(force: true) } }.buttonStyle(.clack(.primary, small: true)).disabled(saving)
                }
            }
        }
        if let error { Banner(kind: .error) { Text(l10n.t("add.saveError", ["message": error])) } }
        Button(l10n.t("add.addBoth")) { Task { await save(force: false) } }
            .buttonStyle(.clack(.primary, wide: true))
            .disabled(saving || !dupes.isEmpty)
            .padding(.top, 8)
    }

    private func save(force: Bool) async {
        let legs = [connection.first, connection.second]
        saving = true
        error = nil
        var already: [Int] = []
        var last: LegDetail?
        do {
            for (index, r) in legs.enumerated() {
                // Adding anyway: only the ones that were already there (the other one is saved).
                if force && !dupes.isEmpty && !dupes.contains(index) { continue }
                do {
                    last = try await app.client.createLeg(CreateLegBody(tripKey: r.key, serviceDate: r.serviceDate, fromSeq: r.from.seq, toSeq: r.to.seq, force: force ? true : nil))
                } catch let apiError as APIError where apiError.status == 409 {
                    already.append(index)
                }
            }
            if !already.isEmpty && !force {
                dupes = already
                kept = last
            } else if let last {
                onSaved(last)
            }
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        saving = false
    }
}

// MARK: done

/// Added: an animated check, the route, and what the trip did for your Passport when it already happened.
private struct DoneStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(Router.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let leg: LegDetail
    let onAnother: () -> Void
    @State private var drawn = false

    var body: some View {
        let l = leg.leg
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(Ink.onTime.opacity(0.35), lineWidth: 3)
                CheckShape().trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                    .stroke(Ink.onTime, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.35).delay(0.1), value: drawn)
            }
            .frame(width: 72, height: 72)
            .onAppear { drawn = true }
            Text(l10n.t("add.added")).clack(.sheetTitle).foregroundStyle(Ink.text)
            Text("\(l.origin?.name ?? "") → \(l.destination?.name ?? "")").clack(.rowTitle).foregroundStyle(Ink.text)
            Text([l.operator?.name, l.trainNumber].compactMap { $0 }.joined(separator: " ")).clack(.caption).foregroundStyle(Ink.text2)
            // A trip that already happened: what it did for your Passport.
            if (l.actualArr?.ms ?? l.schedArr?.ms ?? .infinity) <= Date.now.timeIntervalSince1970 * 1000 {
                TripProgressView(legId: l.id)
            }
            HStack(spacing: 12) {
                Button(l10n.t("add.viewTrip")) {
                    router.closeAdd()
                    router.tab = .trips
                    router.tripsPath = [.trip(l.id)]
                }
                .buttonStyle(.clack(.primary))
                Button(l10n.t("add.addAnother"), action: onAnother).buttonStyle(.clack())
            }
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .multilineTextAlignment(.center)
    }
}

/// The tick of the success check: 15,27 to 22,34 to 37,18 on a 52 box.
private struct CheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 52
        var path = Path()
        path.move(to: CGPoint(x: 15 * s, y: 27 * s))
        path.addLine(to: CGPoint(x: 22 * s, y: 34 * s))
        path.addLine(to: CGPoint(x: 37 * s, y: 18 * s))
        return path
    }
}

// MARK: manual

/// Adding a trip by hand, for a train no timetable we have can find: Norway before yesterday, a heritage run, a train
/// abroad. Where you got on and off, the date and times (each station's local time), and optionally who ran it.
private struct ManualTripStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let date: String
    let from: StationHit?
    let to: StationHit?
    let onBack: () -> Void
    let onSaved: (LegDetail) -> Void

    @State private var fromStation: StationHit?
    @State private var toStation: StationHit?
    @State private var dep = Date(timeIntervalSince1970: 0)
    @State private var arr = Date(timeIntervalSince1970: 0)
    @State private var depSet = false
    @State private var arrSet = false
    @State private var operatorId = ""
    @State private var trainNumber = ""
    @State private var category = "intercity"
    @State private var error: String?
    @State private var saving = false

    private static let categories = ["intercity", "regional", "commuter", "night", "heritage"]

    private var ready: Bool { fromStation != nil && toStation != nil && fromStation?.id != toStation?.id && depSet && arrSet }

    var body: some View {
        Button(l10n.t("common.back"), action: onBack).buttonStyle(LinkButtonStyle())
        Text(l10n.t("manual.title")).clack(.headline).foregroundStyle(Ink.text)
        InfoNote(l10n.t("manual.intro"), more: l10n.t("manual.introMore"))
        Card(spacing: 0) {
            ManualStationField(label: l10n.t("manual.from"), value: $fromStation)
            ManualStationField(label: l10n.t("manual.to"), value: $toStation)
            timeRow(l10n.t("manual.dep"), value: $dep, set: $depSet)
            timeRow(l10n.t("manual.arr"), value: $arr, set: $arrSet)
            row(l10n.t("manual.operator")) {
                Picker("", selection: $operatorId) {
                    Text(l10n.t("manual.unknown")).tag("")
                    ForEach(app.operators.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { Text($0.name).tag($0.id) }
                }
                .tint(Ink.text)
            }
            row(l10n.t("manual.number"), last: true) {
                TextField("", text: $trainNumber)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundStyle(Ink.text)
                    .onChange(of: trainNumber) { _, new in if new.count > 10 { trainNumber = String(new.prefix(10)) } }
                    .frame(maxWidth: 140)
            }
        }
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(Self.categories, id: \.self) { c in
                ChipButton(text: l10n.t("manual.kinds.\(c)"), active: category == c) { category = c }
            }
        }
        InfoNote(l10n.t("manual.timesNote"), more: l10n.t("manual.timesNoteMore"))
        if let error { Banner(kind: .error) { Text(error) } }
        Button(l10n.t("manual.save")) { Task { await save() } }.buttonStyle(.clack(.primary)).disabled(!ready || saving)
            .onAppear {
                fromStation = fromStation ?? from
                toStation = toStation ?? to
            }
    }

    private func row<Content: View>(_ label: String, last: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label).clack(.settingsRow).foregroundStyle(Ink.text)
            Spacer(minLength: 0)
            content()
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Ink.hairline).frame(height: 1) } }
    }

    private func timeRow(_ label: String, value: Binding<Date>, set: Binding<Bool>) -> some View {
        row(label) {
            DatePicker("", selection: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = $0; set.wrappedValue = true }), displayedComponents: .hourAndMinute)
                .labelsHidden()
                .opacity(set.wrappedValue ? 1 : 0.5)
                .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .gmt)
        }
    }

    private func save() async {
        guard let fromStation, let toStation else { return }
        func hhmm(_ d: Date) -> String {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
            return String(format: "%02d:%02d", calendar.component(.hour, from: d), calendar.component(.minute, from: d))
        }
        saving = true
        error = nil
        do {
            onSaved(try await app.client.createManualLeg(ManualLegBody(
                fromStationId: fromStation.id, toStationId: toStation.id, date: date, dep: hhmm(dep), arr: hhmm(arr),
                operatorId: operatorId.isEmpty ? nil : operatorId, trainNumber: trainNumber.isEmpty ? nil : trainNumber, category: category
            )))
        } catch {
            self.error = (error as? APIError)?.message ?? error.localizedDescription
        }
        saving = false
    }
}

/// A station to search for and pick; once picked it shows as a removable chip.
private struct ManualStationField: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    let label: String
    @Binding var value: StationHit?
    @State private var query = ""
    @State private var hits: [StationHit] = []

    var body: some View {
        Group {
            if let value {
                HStack {
                    Text(label).clack(.settingsRow).foregroundStyle(Ink.text)
                    Spacer(minLength: 0)
                    ChipButton(text: value.name, removable: true) { self.value = nil }
                        .accessibilityLabel(l10n.t("manual.change", ["station": value.name]))
                }
                .frame(minHeight: 52)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    SearchField(text: $query, prompt: label)
                    ForEach(hits) { hit in
                        StationRow(station: hit) {
                            value = hit
                            query = ""
                        }
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Ink.hairline).frame(height: 1) }
        .task(id: query) {
            guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                hits = []
                return
            }
            try? await Task.sleep(for: .milliseconds(150))
            if Task.isCancelled { return }
            hits = Array(((try? await app.client.searchStations(query)) ?? []).prefix(5))
        }
    }
}

/// The planner's two filters (DESIGN §segmented control): how many changes, and how short a change may be, in the
/// change gauge's words. The second is hidden for direct journeys, which have no change to judge.
private struct JourneyFilterSheet: View {
    @Environment(L10n.self) private var l10n
    @Bindable var model: AddTrainModel
    let onDone: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(l10n.t("liveMap.filters")).clack(.boardSheetTitle).foregroundStyle(Ink.text)
                Spacer()
                if model.maxChanges < 2 || model.minComfort > 0 {
                    Button(l10n.t("liveMap.clearFilters")) {
                        model.maxChanges = 2
                        model.minComfort = 0
                    }
                    .buttonStyle(LinkButtonStyle())
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(l10n.t("add.changesLabel")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                SegmentedControl(selection: $model.maxChanges, options: [(0, l10n.t("add.changesMin")), (1, l10n.t("add.upTo1")), (2, l10n.t("add.upTo2"))])
            }
            if model.maxChanges > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.t("add.comfortLabel")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                    SegmentedControl(selection: $model.minComfort, options: [(0, l10n.t("add.comfortAnyShort")), (1, l10n.t("add.comfortNormalShort")), (2, l10n.t("comfort.relaxed"))])
                }
            }
            Button(l10n.t("common.done"), action: onDone).buttonStyle(.clack(.primary, wide: true))
        }
        .padding(20)
        .animation(.default, value: model.maxChanges > 0)
    }
}

