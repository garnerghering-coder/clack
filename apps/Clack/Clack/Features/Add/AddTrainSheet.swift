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
    @State private var model: AddTrainModel

    init(request: Router.AddRequest) {
        self.request = request
        // Opening with a train starts at "Opening…" from the first frame, not at the search.
        _model = State(initialValue: AddTrainModel(opening: request.link))
    }

    var body: some View {
        SheetFrame(title: l10n.t("add.title"), onClose: { router.closeAdd() }) {
            content
        }
        .environment(model)
        .task { await model.loadPopular(app.client) }
        .task {
            if let link = request.link { await model.prefill(link, app.client) }
            if let query = request.query {
                if let date = request.date { model.date = date }
                model.query = query
                model.replaceLegId = request.replaceLegId
                model.deleteReplaced = request.deleteReplaced
            }
        }
        .task(id: model.searchKey) {
            await model.runSearch(app.client)
            #if DEBUG
            // `-addLater <n>` presses Show later n times once the journeys are in, to look at the paging and the day line.
            let args = CommandLine.arguments
            if let at = args.firstIndex(of: "-addLater"), at + 1 < args.count, let n = Int(args[at + 1]), model.window != nil {
                for _ in 0..<n { await model.showLaterJourneys(app.client) }
            }
            #endif
        }
        .task(id: model.response?.history) { await model.waitForHistory() }
        .task(id: model.response?.journeysPending == true) { await model.waitForJourneys() }
        #if DEBUG
        // `-addPickJourney`: opens the first planned journey once the list is in (to look at its page).
        .task(id: model.journeys?.count ?? -1) {
            if CommandLine.arguments.contains("-addPickJourney"), model.pickedJourney == nil, let first = model.journeys?.first { model.pickedJourney = first }
        }
        #endif
        .task(id: model.date) { await model.prepareHistory(app.client) }
        .haptic(.success, trigger: model.saved?.id)
    }

    @ViewBuilder
    private var content: some View {
        if let saved = model.saved {
            DoneStep(leg: saved) { model.reset() }
        } else if model.manual {
            ManualTripStep(date: model.date, from: model.interpretation?.from, to: model.interpretation?.to) { model.manual = false } onSaved: { model.didSave($0, app.client); app.justAdded = $0.leg.id; app.tripsChanged() }
        } else if let journey = model.pickedJourney {
            PlannedJourneyStep(journey: journey) { model.pickedJourney = nil } onSaved: { model.didSave($0, app.client); app.justAdded = $0.leg.id; app.tripsChanged() }
        } else if let connection = model.pickedConnection {
            ConfirmConnectionStep(connection: connection) { model.pickedConnection = nil } onSaved: { model.didSave($0, app.client); app.justAdded = $0.leg.id; app.tripsChanged() }
        } else if let picked = model.picked {
            ConfirmStep(
                result: picked, originChosen: model.originChosen, backLabel: model.openedWithTrip ? l10n.t("common.back") : nil,
                onBack: { model.openedWithTrip ? router.closeAdd() : (model.picked = nil) }, onSaved: { model.didSave($0, app.client); app.justAdded = $0.leg.id; app.tripsChanged() }
            )
        } else if let link = model.opening {
            // Opened with a train: say which while it loads, never the empty search with the keyboard up.
            OpeningStep(link: link) { await model.prefill(link, app.client) }
        } else {
            ScrollViewReader { proxy in SearchStep(scroller: proxy) }
        }
    }
}

// MARK: opening a linked train

/// The sheet opened with a train ("Use this instead" on a disruption, Plan on a train): what's being opened while it
/// loads, then the confirm step. When it can't be opened, the train named, why, Try again, and the search as the way
/// on (never an empty search that looks like nothing happened).
private struct OpeningStep: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Environment(AddTrainModel.self) private var model
    let link: AddTrainLink
    let retry: () async -> Void

    /// "SJ 421", or the day when the opener didn't name it.
    private var train: String {
        if let title = link.title, !title.isEmpty { return title }
        let day = Format.isoToNoonMs(link.date).map { Format.day($0, tz: "UTC", language: app.settings.language) } ?? link.date
        return l10n.t("add.opening.trainOn", ["day": day])
    }

    var body: some View {
        if let kind = model.openFailure {
            ErrorStateView(message: l10n.t("add.opening.failed", ["train": train]), kind: kind, status: model.openRetry.status, retry: retry)
                .countsError("add.open")
            Button(l10n.t("add.opening.searchInstead")) { model.searchInstead() }
                .buttonStyle(LinkButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, Space.s)
        } else {
            HStack(spacing: Space.s) {
                ProgressView().controlSize(.small)
                Text(l10n.t("add.opening.title", ["train": train])).clack(.rowTitle).foregroundStyle(Ink.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            GrowingWait(context: l10n.t("add.opening.slow"), status: model.openRetry.status) {
                ResultCardSample()
            }
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
    /// The sheet's scroll view, to keep the list in place when rows are added above it.
    var scroller: ScrollViewProxy?

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
            // So do the results themselves, once the search is whole (both stations, or a train number): the list gets
            // the screen and a tap on a card can't land on a key (user test 2026-11-07, five of seven testers).
            .onChange(of: model.response.map(Self.isWholeSearch) ?? false) { _, whole in if whole { focused = false } }

        if model.query.isEmpty {
            FlowLayout(spacing: Space.s, lineSpacing: Space.s) {
                Text(l10n.t("add.examples")).clack(.caption).foregroundStyle(Ink.text2)
                ForEach(AddTrainLogic.examples, id: \.self) { example in
                    ChipButton(text: example) { model.query = example }
                }
            }
            // The other way in, said once where people look for it (user test 2026-11-07: nobody knew).
            Text(l10n.t("add.shareTicketHint")).clack(.caption).foregroundStyle(Ink.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        if model.searchFailed {
            ErrorStateView(
                message: model.searchFailure == nil ? l10n.t("add.searchError") : l10n.t("add.searchFailed"),
                kind: model.searchFailure, status: model.searchRetry.status, retry: { model.searchAgain() }
            ).countsError("add.search")
        }

        if model.query.isEmpty, !model.popular.isEmpty {
            Text(l10n.t("add.popular")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            stationList(model.popular)
        } else if let response = model.response {
            results(response)
        } else if model.loading {
            // The first search of a query: the quick station names already, the journeys still coming.
            if !model.suggestionsShown.isEmpty {
                Text(l10n.t("add.stations")).clack(.sectionHeader).foregroundStyle(Ink.text2)
                stationList(model.suggestionsShown)
            }
            // Grows with the wait: "Still loading…" after 5 s, why it can take a while after 15 s, and a retry's
            // countdown when the request is waiting to try again.
            GrowingWait(context: l10n.t("add.slowSearch"), status: model.searchRetry.status) {
                VStack(spacing: Space.l) {
                    ResultCardSample()
                    ResultCardSample()
                }
            }
        }
    }

    /// A search that has all it needs: two stations with the planner's answer in, or a train number with its results.
    nonisolated private static func isWholeSearch(_ r: SearchResponse) -> Bool {
        (r.interpretation.from != nil && r.interpretation.to != nil && r.journeys != nil) || (r.interpretation.trainNumber != nil && r.results != nil)
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
        let changesSet = model.maxChanges != AddTrainModel.defaultMaxChanges
        let active = (changesSet ? 1 : 0) + (model.minComfort > 0 && model.maxChanges > 0 ? 1 : 0)
        let summary = [
            changesSet ? (model.maxChanges == 0 ? l10n.t("add.changesNone") : l10n.t("add.changesUpTo", count: model.maxChanges)) : nil,
            model.minComfort > 0 && model.maxChanges > 0 ? l10n.t(["add.comfortAny", "add.comfortNormal", "add.comfortRelaxed"][model.minComfort]) : nil,
        ].compactMap { $0 }.joined(separator: Format.separator)
        return HStack(alignment: .center, spacing: Space.m) {
            VStack(alignment: .leading, spacing: Space.xxs) {
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
                // The system's detents, so the sheet grows with the text instead of clipping it (polish pass 1: a fixed
                // 190/300 pt cut off at the accessibility sizes).
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func results(_ response: SearchResponse) -> some View {
        if response.journeysPending == true {
            // The planner is building the day: the direct trains now, the journeys with changes in a moment.
            HStack(spacing: Space.s) {
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
        if focused, !model.suggestionsShown.isEmpty {
            Text(l10n.t("add.stations")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            stationList(model.suggestionsShown)
        }
        journeyFilterBar(count: model.journeys?.count ?? 0)
        // A whole day whose first train leaves late: said in words, so a reduced timetable (works, a Sunday) isn't
        // mistaken for a list anchored to the wrong hour, and nobody pages into the day before looking for the morning.
        if model.pagedJourneys.isEmpty, let late = model.lateFirstJourney() {
            let tz = late.legs.first?.from.tz ?? Format.defaultZone
            Banner {
                Text(l10n.t("add.noEarlierThatDay", ["time": Format.time(late.dep, tz: tz, clock: app.settings.clock), "day": Format.day(late.dep, tz: tz, language: app.settings.language)]))
            }
        }
        // Paging: six hours earlier or later per press. The button names the day it reaches into when that is another
        // day, and every day's first journey carries a day line (user test 2026-11-07: "the date chip lied to me").
        if model.window != nil {
            pagingButton(model.earlierDay(language: app.settings.language).map { l10n.t("add.showEarlierDay", ["day": $0]) } ?? l10n.t("board.showEarlier"), busy: model.pagingEarlier) {
                let first = model.journeys?.first?.id
                await model.showEarlierJourneys(app.client)
                // The new rows go in above: keep what was at the top where it was, so nothing jumps and a drag at the
                // top can't pull the sheet down by surprise.
                if let first { scroller?.scrollTo(first, anchor: .top) }
            }
        }
        if let list = model.journeys, !list.isEmpty {
            VStack(spacing: Space.l) {
                ForEach(Array(list.enumerated()), id: \.element.id) { i, journey in
                    if let day = model.daySeparator(before: journey, previous: i > 0 ? list[i - 1] : nil, language: app.settings.language) {
                        Text(day).clack(.captionUpper).foregroundStyle(Ink.text2).frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, i > 0 ? 8 : 0)
                    }
                    JourneyResultCard(journey: journey) { model.pickedJourney = journey }.id(journey.id)
                }
                // Some journeys are hidden by the change filter (owner, 2026-10-30: a 4-change night via
                // København was found but never shown): offer them under the list too, not only when none pass.
                if model.moreWithMoreChanges {
                    Button(l10n.t("add.includeMoreChanges")) {
                        model.maxChanges = AddTrainModel.maxChangesLimit
                        model.minComfort = 0
                    }
                    .buttonStyle(.clack(.secondary, small: true))
                }
            }
        } else if model.moreWithMoreChanges {
            Text(l10n.t("add.noJourneyWithFilter")).clack(.body).foregroundStyle(Ink.text2)
            Button(l10n.t("add.includeMoreChanges")) {
                model.maxChanges = AddTrainModel.maxChangesLimit
                model.minComfort = 0
            }
            .buttonStyle(.clack(wide: true))
        } else if model.date != Format.todayIso(), let noon = Format.isoToNoonMs(model.date) {
            Text(l10n.t("add.noJourneyThatDay", ["day": Format.day(noon, tz: "UTC", language: app.settings.language)])).clack(.body).foregroundStyle(Ink.text2)
        } else {
            Text(l10n.t("add.noJourney")).clack(.body).foregroundStyle(Ink.text2)
        }
        if model.window != nil {
            if model.laterEmpty { Text(l10n.t("add.noLaterJourneys")).clack(.caption).foregroundStyle(Ink.text2) }
            pagingButton(model.laterDay(language: app.settings.language).map { l10n.t("add.showLaterDay", ["day": $0]) } ?? l10n.t("board.showLater"), busy: model.pagingLater) { await model.showLaterJourneys(app.client) }
        }
        Button(l10n.t("manual.cta")) { model.manual = true }
            .buttonStyle(LinkButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.top, Space.s)
    }

    /// Show earlier / Show later as a plain system link, replaced by a spinner and "Looking for more…" while it runs.
    private func pagingButton(_ label: String, busy: Bool, action: @escaping () async -> Void) -> some View {
        HStack(spacing: Space.s) {
            if busy {
                ProgressView().controlSize(.small)
                Text(l10n.t("add.searchingMore")).clack(.caption).foregroundStyle(Ink.text2)
            } else {
                Button(label) { Task { await action() } }.buttonStyle(LinkButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func trainResults(_ response: SearchResponse) -> some View {
        let interpretation = response.interpretation
        let hasResults = !(response.results ?? []).isEmpty
        if !model.suggestionsShown.isEmpty
            && !(interpretation.to != nil && model.suggestionsShown.first?.id == interpretation.to?.id && hasResults) {
            Text(l10n.t("add.stations")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            stationList(model.suggestionsShown)
        }
        if response.outsideTimetable {
            Banner {
                HStack(spacing: Space.s) {
                    if response.history == "loading" { ProgressView().controlSize(.small) }
                    Text(historyMessage(response))
                }
            }
        }
        if let list = response.results, !list.isEmpty {
            // One row that scrolls sideways, in every language (polish pass 1: it wrapped to two lines in English and
            // ran off the edge in Swedish).
            ScrollView(.horizontal) {
                HStack(spacing: Space.s) {
                    ForEach(AddTrainLogic.Filter.allCases, id: \.self) { filter in
                        ChipButton(text: l10n.t("add.filter\(filter == .all ? "All" : filter == .long ? "Long" : filter == .regional ? "Regional" : "Commuter")"), active: model.filter == filter) { model.filter = filter }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            if model.hasHiddenEarlier {
                Button(l10n.t("board.showEarlier")) { model.showEarlier = true }.buttonStyle(LinkButtonStyle())
            }
            if model.showingOnlyDeparted {
                Text(l10n.t("add.departedToday")).clack(.caption).foregroundStyle(Ink.text2)
            }
            // Only trains abroad carry this number today: say so, and when it runs at home (user test 2026-11-07:
            // "421" on a Sunday gave a Danish IC 421 and nothing about SJ's).
            if let number = interpretation.trainNumber, let days = response.otherDays, !days.isEmpty, let country = response.otherDaysCountry {
                let day = Format.isoToNoonMs(model.date).map { Format.day($0, tz: "UTC", language: app.settings.language) } ?? model.date
                otherDaysNote(l10n.t("add.noTrainAtHome", ["number": number, "country": l10n.t("countries.\(country)"), "day": day]), days: days)
            }
            VStack(spacing: Space.l) {
                ForEach(model.results ?? []) { result in
                    ResultCard(result: result) { model.pick(result) }
                }
            }
        }
        if let list = response.results, list.isEmpty, !response.outsideTimetable {
            if let number = interpretation.trainNumber {
                // Not on this day: say which day it is, and the days the train does run (a chip moves the search
                // there), so a ticket and the app can be told apart (user test 2026-11-07, six of seven testers).
                let day = Format.isoToNoonMs(model.date).map { Format.day($0, tz: "UTC", language: app.settings.language) } ?? model.date
                let name = [interpretation.operator?.text, number].compactMap { $0 }.joined(separator: " ")
                VStack(alignment: .leading, spacing: Space.s) {
                    otherDaysNote(l10n.t("add.noTrainOnDay", ["train": name, "day": day]), days: response.otherDays ?? [])
                    Text(l10n.t("add.noTrainHint")).clack(.caption).foregroundStyle(Ink.text2)
                }
            } else {
                Text((response.connections ?? []).isEmpty ? l10n.t("add.noDirect") : l10n.t("add.noDirectChange"))
                    .clack(.body).foregroundStyle(Ink.text2)
            }
        }
        if let list = response.results, list.isEmpty, let connections = response.connections, !connections.isEmpty {
            Text(l10n.t("add.withChange")).clack(.sectionHeader).foregroundStyle(Ink.text2)
            VStack(spacing: Space.l) {
                ForEach(connections) { connection in ConnectionResultCard(connection: connection) { model.pickedConnection = connection } }
            }
        }
        if response.outsideTimetable ? response.history != "loading" : response.results != nil {
            Button(l10n.t("manual.cta")) { model.manual = true }
                .buttonStyle(LinkButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, Space.s)
        }
    }

    /// A line and the days a train does run, each a chip that moves the search to that day.
    @ViewBuilder
    private func otherDaysNote(_ line: String, days: [String]) -> some View {
        Text(line).clack(.body).foregroundStyle(Ink.text)
        if !days.isEmpty {
            Text(l10n.t("add.runsOn")).clack(.caption).foregroundStyle(Ink.text2)
            FlowLayout(spacing: Space.s, lineSpacing: Space.s) {
                ForEach(days, id: \.self) { iso in
                    ChipButton(text: Format.isoToNoonMs(iso).map { Format.day($0, tz: "UTC", language: app.settings.language) } ?? iso) { model.date = iso }
                }
            }
        }
    }

    /// Why an older day has no results yet: being fetched, failed, or not in the record. Each country says its own
    /// (Norway and Finland from when, Denmark which stretches it has); never one country's words for another's day,
    /// so a value this app doesn't know, or Sweden's "unavailable" for a search that starts abroad, gets the neutral
    /// line.
    private func historyMessage(_ response: SearchResponse) -> String {
        let language = app.settings.language
        let long = { (iso: String) in Format.isoToNoonMs(iso).map { Format.fullDate($0, tz: "UTC", language: language) } ?? iso }
        switch response.history {
        case "loading": return l10n.t("add.historyLoading")
        case "failed": return l10n.t("add.historyFailed")
        case "norway", "finland":
            let from = response.historyFrom.map(long) ?? ""
            return l10n.t(response.history == "norway" ? "add.historyNorway" : "add.historyFinland", ["date": from])
        case "denmark":
            guard let first = response.historyFrom else { return l10n.t("add.historyNone") }
            let ranges = AddTrainLogic.coveredRanges(from: first, gaps: response.historyGaps ?? []).map { range in
                range.to.map { l10n.t("add.historyRange", ["from": long(range.from), "to": long($0)]) }
                    ?? l10n.t("add.historyRangeOpen", ["from": long(range.from)])
            }
            let list = ranges.formatted(.list(type: .and).locale(Format.locale(language)))
            return l10n.t("add.historyDenmark", ["date": long(model.date), "ranges": list])
        case "unavailable":
            // The server says why for the search's first country (its from station, else its to); without stations it
            // asks Sweden first.
            let country = response.interpretation.from?.country ?? response.interpretation.to?.country ?? "SE"
            return l10n.t(country == "SE" ? "add.historyUnavailable" : "add.historyNone")
        default: return l10n.t("add.historyNone")
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
        FlowLayout(spacing: Space.s, lineSpacing: Space.s) {
            ChipButton(text: l10n.t("add.today"), active: date == today) { date = today }
            ChipButton(text: l10n.t("add.tomorrow"), active: date == tomorrow) { date = tomorrow ?? date }
            // A picked day is the button's own label (owner, 2026-10-30: no separate date line).
            let picked = date != today && date != tomorrow
            ChipButton(text: picked ? Format.day(Format.isoToNoonMs(date) ?? 0, tz: "UTC", language: app.settings.language) : l10n.t("add.pickDate"), active: picked) { picking = true }
            if date < today {
                Text(l10n.t("add.pastTrip")).clack(.body).fontWeight(.medium).foregroundStyle(Ink.slightInk).padding(.leading, Space.xs)
            }
        }
        .sheet(isPresented: $picking) {
            let maxDate = AddTrainLogic.date(fromIso: Format.addDaysIso(today, days: 365) ?? today, tz: tz) ?? .now
            VStack(spacing: Space.m) {
                DatePicker(
                    l10n.t("add.pickDate"),
                    selection: Binding(get: { AddTrainLogic.date(fromIso: date, tz: tz) ?? .now }, set: { date = AddTrainLogic.iso(from: $0, tz: tz) }),
                    in: ...maxDate, displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                // The chosen day in the selection ink; yellow stays on Done, the one action (Look.selection).
                .tint(Look.selectionFill)
                Button(l10n.t("common.done")) { picking = false }.buttonStyle(.clack(.primary, wide: true))
            }
            .padding(Space.l)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
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
        let dep = Format.time(result.from.time, tz: result.from.tz, clock: app.settings.clock)
        let arr = Format.time(result.to.time, tz: result.to.tz, clock: app.settings.clock)
        let duration = Format.duration(Double(result.durationMin), language: l10n.language)
        Button(action: onPick) {
            VStack(alignment: .leading, spacing: Space.s) {
                TimesRow(dep: dep, arr: arr, duration: duration, plus: plus)
                AdaptiveStack(spacing: Space.m) {
                    Text(result.from.name).lineLimit(2)
                    Spacer(minLength: 0)
                    Text(result.to.name).multilineTextAlignment(.trailing).lineLimit(2)
                }
                .clack(.stopName).fontWeight(.semibold).foregroundStyle(Ink.text2)
                if let type {
                    HStack(spacing: Space.m) {
                        TrainPicture(type: type, operatorId: result.operatorId, height: 28).frame(width: 120, alignment: .leading).clipped()
                        // A typical type for the line, not a fact about this run (user test 2026-11-07: "X2000" here,
                        // the planned "SJ 3000 (X55)" on the trip, read as the app not knowing what it was).
                        Text(l10n.t("add.usuallyType", ["type": type.name])).clack(.caption).foregroundStyle(Ink.text2)
                    }
                }
                // Without the operator's mark the route's name stands in, unless it is only the number again
                // (user test 2026-11-07: "427 427 ?").
                ServiceHeader(op: op, number: result.trainNumber, size: .medium, category: result.product, name: AddTrainLogic.standInName(result, op: op))
                Text(Format.join([
                    result.stopsBetween > 0 ? l10n.t("add.stopsBetween", count: result.stopsBetween) : l10n.t("add.direct"),
                    result.alsoKnownAs.isEmpty ? nil : l10n.t("add.alsoKnownAs", ["numbers": result.alsoKnownAs.joined(separator: ", ")]),
                ]))
                .clack(.caption).foregroundStyle(Ink.text2)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
            .hairlineBorder(radius: Radius.card)
        }
        .buttonStyle(.press)
        // One sentence for VoiceOver, not a dozen pieces.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(l10n.t("add.resultLabel", [
            "train": [op?.name, result.trainNumber].compactMap { $0 }.joined(separator: " "),
            "from": result.from.name, "dep": dep, "to": result.to.name, "arr": arr, "duration": duration,
        ]))
        .accessibilityAddTraits(.isButton)
    }
}

/// Departure, the trip's length on a dashed line, arrival. The times never shrink or wrap; at large text sizes the
/// three stack instead of squeezing (polish pass 1: "07:2 / 2" at AX3).
private struct TimesRow: View {
    let dep: String
    let arr: String
    let duration: String
    let plus: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                time(dep)
                Text(duration)
                    .clack(.caption).foregroundStyle(Ink.text2)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .background { DashedHorizontalLine() }
                arrival
            }
            VStack(alignment: .leading, spacing: Space.xxs) {
                time(dep)
                Text(duration).clack(.caption).foregroundStyle(Ink.text2)
                arrival
            }
        }
        .monospacedDigit()
    }

    private func time(_ text: String) -> some View {
        Text(text).clack(.bigTime).foregroundStyle(Ink.text).fixedSize()
    }

    private var arrival: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
            time(arr)
            if plus > 0 { TimePair.plusText(plus) }
        }
        .fixedSize()
    }
}

/// While the first results load: a card shaped like a result (times, names, a train, a line), so nothing moves when
/// the real ones arrive.
private struct ResultCardSample: View {
    var body: some View {
        Placeholder {
            VStack(alignment: .leading, spacing: Space.s) {
                TimesRow(dep: "08:03", arr: "10:51", duration: "2h 48m", plus: 0)
                HStack {
                    Text(verbatim: "Stockholm C")
                    Spacer(minLength: 0)
                    Text(verbatim: "Göteborg C")
                }
                .clack(.stopName).fontWeight(.semibold)
                Color.clear.frame(height: 28)
                ServiceHeader(op: nil, number: "523", size: .medium)
                Text(verbatim: "4 stops between").clack(.caption)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
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
        let card = VStack(alignment: .leading, spacing: Space.s) {
            TimesRow(
                dep: Format.time(first.from.time, tz: first.from.tz, clock: app.settings.clock),
                arr: Format.time(second.to.time, tz: second.to.tz, clock: app.settings.clock),
                duration: Format.duration(total, language: l10n.language), plus: plus
            )
            ForEach([first, second], id: \.id) { result in
                let op = result.operatorId.flatMap { app.operatorsById[$0] }
                VStack(alignment: .leading, spacing: Space.xxs) {
                    ServiceHeader(op: op, number: result.trainNumber, size: .small, name: AddTrainLogic.standInName(result, op: op))
                    (TimePair.text(.init(time: result.from.time, tz: result.from.tz), .init(time: result.to.time, tz: result.to.tz), clock: app.settings.clock)
                        + Text(verbatim: Format.separator + "\(result.from.name) → \(result.to.name)"))
                        .clack(.caption).foregroundStyle(Ink.text2).lineLimit(2)
                }
            }
            Text(l10n.t("add.changeAt", ["station": connection.changeAt.name, "min": String(connection.changeMin)])).clack(.caption).foregroundStyle(Ink.text2)
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .hairlineBorder(radius: Radius.card)
        Group {
            if let onPick { Button(action: onPick) { card }.buttonStyle(.press) } else { card }
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
    /// Why saving failed (the phone offline, or the server), for the banner's words.
    @State private var failure: APIError.Kind?
    /// The train's stops couldn't be fetched (said as such, with Try again; not as a save error).
    @State private var loadFailed = false
    /// Why the stops didn't load, for the error's cause line.
    @State private var loadFailure: APIError.Kind?
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
            HStack(spacing: Space.s) {
                LucideIcon(name: "arrow-left", size: 18)
                Text(backLabel ?? l10n.t("add.back"))
            }
        }
        .buttonStyle(LinkButtonStyle())
        Text(l10n.t("add.confirmTitle")).clack(.headline).foregroundStyle(Ink.text)
        if loadFailed {
            ErrorStateView(message: l10n.t("add.tripLoadFailed"), kind: loadFailure ?? app.connectionKind, retry: { await load() })
        } else if trip == nil {
            // The map's place is held from the first frame, so the picker and the stops below don't jump down when
            // the train arrives (polish pass 1: the main button moved about 100 pt under a finger).
            Skeleton(height: 180, radius: Radius.card)
        }
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
        ServiceHeader(op: op, number: result.trainNumber, size: .medium, category: result.product, name: AddTrainLogic.standInName(result, op: op))
        if trip == nil, !loadFailed {
            // The summary line's place, held too.
            Text(verbatim: "\(result.from.name) → \(result.to.name) · 000 km · 0h 00m").clack(.body).redacted(reason: .placeholder)
        }
        if let from, let to, let dep, let arr, let trip {
            let d = AddTrainLogic.distance(stops: trip.stops, geometry: geometry, fromSeq: picked.fromSeq, toSeq: picked.toSeq)
            (Text(verbatim: "\(from.name) → \(to.name)").fontWeight(.semibold).foregroundStyle(Ink.text)
                + Text(" · \(d.approximate ? "≈ " : "")\(Format.distance(d.metres, unit: app.settings.distanceUnit, language: app.settings.language)) · \(Format.duration((arr - dep) / 60_000, language: l10n.language))").foregroundStyle(Ink.text2))
                .clack(.body)
        }
        endPicker(from: from, to: to)
        Text(picked.picking == .from ? l10n.t("add.tapFrom") : l10n.t("add.tapTo")).clack(.caption).foregroundStyle(Ink.text2)
        VStack(spacing: 0) {
            if trip == nil, !loadFailed {
                ForEach(0..<6, id: \.self) { _ in Skeleton(height: 40, radius: Radius.tag).padding(.vertical, Space.xxs) }
            }
            ForEach(trip?.stops ?? []) { stop in stopRow(stop, color: color) }
        }
        if duplicate {
            Banner(kind: .warn) {
                Text(l10n.t("add.duplicate"))
                HStack(spacing: Space.s) {
                    Button(l10n.t("add.addAnyway")) { Task { await save(force: true) } }.buttonStyle(.clack(.primary, small: true)).disabled(saving)
                    Button(l10n.t("add.cancel")) { duplicate = false }.buttonStyle(.clack(small: true))
                }
            }
        }
        if error != nil { Banner(kind: .error) { Text(FailureText.line(l10n.t("add.saveFailed"), failure, app: app, l10n: l10n)) } }
        Color.clear.frame(height: 0)
            .sheetAction(l10n.t("add.addToClack"), enabled: !(trip == nil || saving || duplicate)) { Task { await save(force: false) } }
            .task(id: result.id) { await load() }
    }

    private func endPicker(from: TripStop?, to: TripStop?) -> some View {
        HStack(spacing: Space.xs) {
            ForEach([AddTrainLogic.End.from, .to], id: \.self) { end in
                let active = picked.picking == end
                Button {
                    picked.picking = end
                } label: {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(l10n.t(end == .from ? "add.from" : "add.to")).clack(.captionUpper).foregroundStyle(active ? Look.onSelection : Ink.text2)
                        Text((end == .from ? from : to)?.name ?? "—").clack(.rowTitle).foregroundStyle(active ? Look.onSelection : Ink.text).lineLimit(2)
                    }
                    .padding(.horizontal, Space.m).padding(.vertical, Space.s)
                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .background(active ? Look.selectionFill : .clear, in: RoundedRectangle(cornerRadius: Radius.inner(Radius.input, padding: Space.xs), style: .continuous))
                }
                .buttonStyle(.press(radius: Radius.inner(Radius.input, padding: Space.xs), scales: false))
                // Each end says what it is and what it holds ("From, Stockholm C"); the hint says what a tap does.
                .accessibilityLabel(Format.join([l10n.t(end == .from ? "add.from" : "add.to"), (end == .from ? from : to)?.name], separator: ", "))
                .accessibilityHint(l10n.t("add.tapToChoose"))
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(Space.xs)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Radius.input, style: .continuous))
        .hairlineBorder(radius: Radius.input)
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
        .buttonStyle(.pressRow)
        // A stop that can't become the end being chosen is dimmed and disabled, so it doesn't look tappable and
        // VoiceOver doesn't call it a button (polish pass 1: it looked like the others and did nothing).
        .disabled(!(selectable || end))
        .opacity(selectable || end || role == .outside ? 1 : 0.45)
    }

    private func load() async {
        // Both at once: the stops shouldn't wait for the map. The mini map is a nice-to-have: without it the summary
        // falls back to straight-line distance.
        loadFailed = false
        async let route = try? app.client.timetableTripGeometry(result.key, date: result.serviceDate)
        do {
            trip = try await app.client.timetableTrip(result.key, date: result.serviceDate)
        } catch {
            loadFailure = APIError.classify(error)
            loadFailed = true
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
            self.failure = FailureText.kind(error)
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
    /// Why saving failed (the phone offline, or the server), for the banner's words.
    @State private var failure: APIError.Kind?

    var body: some View {
        let legs = [connection.first, connection.second]
        Button(action: onBack) {
            HStack(spacing: Space.s) {
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
                HStack(spacing: Space.s) {
                    if let kept { Button(l10n.t("add.keepAsIs")) { onSaved(kept) }.buttonStyle(.clack(small: true)) }
                    Button(l10n.t("add.addAnyway")) { Task { await save(force: true) } }.buttonStyle(.clack(.primary, small: true)).disabled(saving)
                }
            }
        }
        if error != nil { Banner(kind: .error) { Text(FailureText.line(l10n.t("add.saveFailed"), failure, app: app, l10n: l10n)) } }
        // Pinned at the bottom like every step's main button, above the keyboard and in reach.
        Color.clear.frame(height: 0)
            .sheetAction(l10n.t("add.addBoth"), enabled: !(saving || !dupes.isEmpty)) { Task { await save(force: false) } }
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
            self.failure = FailureText.kind(error)
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
    /// The journey the saved train belongs to (its other trains, saved now or before), when it has one.
    @State private var journey: Journey?
    @State private var alertsBusy = false
    @State private var alertsJustOn = false

    var body: some View {
        let l = leg.leg
        let legs = (journey?.legs.map(\.leg)).flatMap { $0.count > 1 ? $0 : nil }
        let first = legs?.first ?? l, last = legs?.last ?? l
        let ahead = (l.schedDep?.ms ?? 0) > Date.now.timeIntervalSince1970 * 1000
        VStack(spacing: Space.m) {
            ZStack {
                Circle().stroke(Ink.onTime.opacity(0.35), lineWidth: 3)
                CheckShape().trim(from: 0, to: drawn || reduceMotion ? 1 : 0)
                    .stroke(Ink.onTime, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .animation(Motion.appear.animation(reduceMotion: reduceMotion), value: drawn)
            }
            .frame(width: 72, height: 72)
            // Drawn once the view is on screen (user test 2026-11-07: "it never drew a tick, just a ring").
            .task {
                try? await Task.sleep(for: .milliseconds(150))
                drawn = true
            }
            Text(l10n.t("add.added")).clack(.sheetTitle).foregroundStyle(Ink.text)
            // A journey is named whole (user test 2026-11-07: "Added" named only the last of two trains).
            Text(verbatim: "\(first.origin?.name ?? "") → \(last.destination?.name ?? "")").clack(.rowTitle).foregroundStyle(Ink.text)
            if let legs {
                Text(l10n.t("journey.label", count: legs.count) + Format.separator + legs.map { [$0.operator?.name, $0.trainNumber].compactMap { $0 }.joined(separator: " ") }.joined(separator: ", "))
                    .clack(.caption).foregroundStyle(Ink.text2)
            } else {
                Text([l.operator?.name, l.trainNumber].compactMap { $0 }.joined(separator: " ")).clack(.caption).foregroundStyle(Ink.text2)
            }
            // A trip that already happened: what it did for your Passport.
            if (l.actualArr?.ms ?? l.schedArr?.ms ?? .infinity) <= Date.now.timeIntervalSince1970 * 1000 {
                TripProgressView(legId: l.id)
            }
            // A trip ahead: the offer of alerts here, the moment it matters (user test 2026-11-07: "Flighty asks
            // straight away"; the switch was two screens deep in Settings).
            if ahead, !app.notifications.denied {
                if app.settings.notify {
                    HStack(spacing: Space.s) {
                        LucideIcon(name: "bell", size: 16).foregroundStyle(Ink.accentInk)
                        Text(l10n.t(alertsJustOn ? "alertsPrompt.nowOn" : "alertsPrompt.on")).clack(.caption).foregroundStyle(Ink.text2)
                    }
                    .padding(.top, Space.xs)
                } else {
                    VStack(spacing: Space.s) {
                        // The reason first, then the button that asks iOS (polish pass 1: lead with the reason).
                        Text(l10n.t("alertsPrompt.body")).clack(.caption).foregroundStyle(Ink.text2)
                        Button {
                            Task { await turnOnAlerts() }
                        } label: {
                            Label { Text(l10n.t("alertsPrompt.turnOn")) } icon: { LucideIcon(name: "bell", size: 16) }
                        }
                        .buttonStyle(.clack(small: true))
                        .disabled(alertsBusy)
                    }
                    .padding(.top, Space.xs)
                }
            }
            HStack(spacing: Space.m) {
                Button(l10n.t(legs != nil ? "add.viewJourney" : "add.viewTrip")) {
                    router.closeAdd()
                    router.tab = .trips
                    if let legs, let id = legs.first?.journeyId { router.tripsPath = [.journey(id)] } else { router.tripsPath = [.trip(l.id)] }
                }
                .buttonStyle(.clack(.primary))
                Button(l10n.t("add.addAnother"), action: onAnother).buttonStyle(.clack())
            }
            .padding(.top, Space.m)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Space.xxl + Space.s)
        .multilineTextAlignment(.center)
        .task(id: l.journeyId) {
            guard let id = l.journeyId else { return }
            journey = try? await app.client.journey(id)
        }
    }

    private func turnOnAlerts() async {
        alertsBusy = true
        if await app.notifications.requestPermission() {
            await app.update(SettingsPatch(notify: true))
            Usage.shared.count(.feature, "alerts.on")
            alertsJustOn = true
        }
        UserDefaults.standard.set(true, forKey: FirstRun.alertsAskedKey)
        alertsBusy = false
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
    // The wheels start at a travelling hour, not midnight (user test 2026-11-07: "~40 wheel rows for two times").
    @State private var dep = Date(timeIntervalSince1970: 8 * 3600)
    @State private var arr = Date(timeIntervalSince1970: 9 * 3600)
    @State private var depSet = false
    @State private var arrSet = false
    @State private var operatorId = ""
    @State private var trainNumber = ""
    @State private var category = "intercity"
    @State private var error: String?
    /// Why saving failed (the phone offline, or the server), for the banner's words.
    @State private var failure: APIError.Kind?
    @State private var saving = false
    @FocusState private var numberFocused: Bool

    private static let categories = ["intercity", "regional", "commuter", "night", "heritage"]

    private var ready: Bool { fromStation != nil && toStation != nil && fromStation?.id != toStation?.id && depSet && arrSet }

    var body: some View {
        Button(l10n.t("common.back"), action: onBack).buttonStyle(LinkButtonStyle())
        Text(l10n.t("manual.title")).clack(.headline).foregroundStyle(Ink.text)
        // The day it is for, so nobody has to trust that it was remembered (user test 2026-11-07).
        if let noon = Format.isoToNoonMs(date) {
            Text(Format.longDate(noon, tz: "UTC", language: app.settings.language)).clack(.body).foregroundStyle(Ink.text2)
        }
        InfoNote(l10n.t("manual.intro"), more: l10n.t("manual.introMore"))
        Card(spacing: 0) {
            ManualStationField(label: l10n.t("manual.from"), value: $fromStation)
            ManualStationField(label: l10n.t("manual.to"), value: $toStation)
            timeRow(l10n.t("manual.dep"), value: $dep, set: $depSet)
            timeRow(l10n.t("manual.arr"), value: $arr, set: $arrSet)
            row(l10n.t("manual.operator")) {
                OperatorPickerButton(selection: $operatorId)
            }
            row(l10n.t("manual.number"), last: true) {
                TextField("", text: $trainNumber)
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundStyle(Ink.text)
                    .focused($numberFocused)
                    .onChange(of: trainNumber) { _, new in if new.count > 10 { trainNumber = String(new.prefix(10)) } }
                    .frame(maxWidth: 140)
                // The number pad has no key of its own to close it (user test 2026-11-07: it hid the Save button). Done
                // sits in the row, beside the field: a bar above the keyboard is unreliable in this sheet and, on iOS 26,
                // floats over the form (run 2).
                if numberFocused {
                    Button(l10n.t("common.done")) { numberFocused = false }
                        .buttonStyle(LinkButtonStyle())
                }
            }
        }
        FlowLayout(spacing: Space.s, lineSpacing: Space.s) {
            ForEach(Self.categories, id: \.self) { c in
                ChipButton(text: l10n.t("manual.kinds.\(c)"), active: category == c) { category = c }
            }
        }
        InfoNote(l10n.t("manual.timesNote"), more: l10n.t("manual.timesNoteMore"))
        if error != nil { Banner(kind: .error) { Text(FailureText.line(l10n.t("add.saveFailed"), failure, app: app, l10n: l10n)) } }
        Color.clear.frame(height: 0)
            .sheetAction(l10n.t("manual.save"), enabled: ready && !saving) { Task { await save() } }
            .onAppear {
                fromStation = fromStation ?? from
                toStation = toStation ?? to
            }
    }

    private func row<Content: View>(_ label: String, last: Bool = false, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: Space.m) {
            Text(label).clack(.settingsRow).foregroundStyle(Ink.text)
            Spacer(minLength: 0)
            content()
        }
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Ink.hairline).frame(height: 1) } }
    }

    private func timeRow(_ label: String, value: Binding<Date>, set: Binding<Bool>) -> some View {
        row(label) {
            if set.wrappedValue {
                DatePicker("", selection: Binding(get: { value.wrappedValue }, set: { new in
                    value.wrappedValue = new
                    // The arrival follows the departure (an hour on) until it is set itself: one wheel less to spin.
                    if !arrSet, label == l10n.t("manual.dep") { arr = new.addingTimeInterval(3600) }
                }), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .environment(\.timeZone, TimeZone(identifier: "UTC") ?? .gmt)
            } else {
                // Not set yet: said in words, not as a faded picker that looked disabled (polish pass 1).
                Button(l10n.t("manual.setTime")) {
                    set.wrappedValue = true
                    if !arrSet, label == l10n.t("manual.dep") { arr = dep.addingTimeInterval(3600) }
                }
                .buttonStyle(.clack(small: true))
            }
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
            self.failure = FailureText.kind(error)
        }
        saving = false
    }
}

/// Who ran the train: a button with the choice, opening a sheet that lists every operator with its mark, searchable,
/// the home country's first (user test 2026-11-07: a plain menu of 25 names closed at every scroll, and Vy was below
/// the fold).
struct OperatorPickerButton: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Binding var selection: String
    @State private var open = false

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: Space.s) {
                if let op = app.operatorsById[selection] {
                    OperatorBadge(op: op, size: .small)
                    Text(op.name)
                } else {
                    Text(l10n.t("manual.unknown"))
                }
                LucideIcon(name: "chevron-down", size: 14).foregroundStyle(Ink.text2)
            }
            .clack(.body).foregroundStyle(Ink.text)
            .padding(.vertical, Space.s).padding(.horizontal, Space.m)
            .background(Ink.surfaceRaised, in: RoundedRectangle(cornerRadius: Radius.controlSm, style: .continuous))
            .hairlineBorder(radius: Radius.controlSm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(l10n.t("manual.operator"))
        .sheet(isPresented: $open) {
            OperatorPickerSheet(selection: $selection) { open = false }
                .environment(app)
                .environment(l10n)
                .preferredColorScheme(app.colorScheme)
        }
    }
}

struct OperatorPickerSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(L10n.self) private var l10n
    @Binding var selection: String
    let onDone: () -> Void
    @State private var query = ""

    private var operators: [Operator] {
        let home = app.settings.homeCountry?.rawValue.uppercased()
        let q = query.trimmingCharacters(in: .whitespaces)
        return app.operators
            .filter { q.isEmpty || $0.name.localizedCaseInsensitiveContains(q) || $0.shortName.localizedCaseInsensitiveContains(q) || ($0.company?.localizedCaseInsensitiveContains(q) ?? false) }
            .sorted { a, b in
                let ha = a.country == home, hb = b.country == home
                return ha != hb ? ha : a.name.localizedCompare(b.name) == .orderedAscending
            }
    }

    private func subtitle(_ op: Operator) -> String {
        let country = l10n.t("countries.\(op.country)")
        return [op.company, country].compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            // The system's selection list (DESIGN §2.3, native controls): a tap picks and closes. The list wants an
            // optional; "" (not sure) is a row of its own, so nil never comes back from it.
            List(selection: Binding<String?>(get: { selection }, set: { selection = $0 ?? "" })) {
                Text(l10n.t("manual.unknown")).tag("")
                ForEach(operators) { op in
                    HStack(spacing: Space.m) {
                        OperatorBadge(op: op, size: .small)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(op.name)
                            // "NT" alone said nothing (user test 2026-11-07): the company and country under the mark.
                            Text(subtitle(op)).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .tag(op.id)
                }
            }
            .onChange(of: selection) { onDone() }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: l10n.t("manual.operatorSearch"))
            .navigationTitle(l10n.t("manual.operator"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(l10n.t("common.close"), action: onDone) } }
        }
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
                VStack(alignment: .leading, spacing: Space.s) {
                    SearchField(text: $query, prompt: label)
                    ForEach(hits) { hit in
                        StationRow(station: hit) {
                            value = hit
                            query = ""
                        }
                    }
                }
                .padding(.vertical, Space.s)
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

/// The planner's two filters as a system `Form`: how many changes, and how short a change may be, in the change
/// gauge's words. The second is hidden for direct journeys, which have no change to judge.
private struct JourneyFilterSheet: View {
    @Environment(L10n.self) private var l10n
    @Bindable var model: AddTrainModel
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(l10n.t("add.changesLabel")) {
                    // Direct · 1 · 2 · 3 · 4 · 5 (the planner does up to five changes, owner 2026-10-28).
                    FormSegmentedControl(selection: $model.maxChanges, options: [(0, l10n.t("add.changesDirectShort"))] + (1...AddTrainModel.maxChangesLimit).map { ($0, String($0)) })
                    Text(model.maxChanges == 0 ? l10n.t("add.changesNone") : l10n.t("add.changesUpTo", count: model.maxChanges)).font(.footnote).foregroundStyle(.secondary)
                }
                if model.maxChanges > 0 {
                    Section(l10n.t("add.comfortLabel")) {
                        FormSegmentedControl(selection: $model.minComfort, options: [(0, l10n.t("add.comfortAnyShort")), (1, l10n.t("add.comfortNormalShort")), (2, l10n.t("comfort.relaxed"))])
                    }
                }
            }
            .tint(Ink.accentInk)
            .navigationTitle(l10n.t("liveMap.filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.maxChanges != AddTrainModel.defaultMaxChanges || model.minComfort > 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(l10n.t("liveMap.clearFilters")) {
                            model.maxChanges = AddTrainModel.defaultMaxChanges
                            model.minComfort = 0
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button(l10n.t("common.done"), action: onDone) }
            }
            .motion(.layout, value: model.maxChanges > 0)
        }
    }
}

extension AddTrainLogic {
    /// The name shown in place of a missing operator mark: the route's name, unless it is only the train number again
    /// (user test 2026-11-07: "427 427 ?"; polish pass 1 put this one rule on every card).
    static func standInName(routeName: String?, trainNumber: String?, op: Operator?) -> String? {
        op == nil && routeName != trainNumber ? routeName : nil
    }

    static func standInName(_ result: TripResult, op: Operator?) -> String? {
        standInName(routeName: result.routeName, trainNumber: result.trainNumber, op: op)
    }
}
