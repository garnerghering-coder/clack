//
//  AddTrainModel.swift
//  Clack
//

import ClackCore
import Foundation
import Observation

/// What the Add a train sheet holds: the date, the text, what the search found, and which step it's on
/// (AddTripPage.tsx): search, then the confirm step for a train or a connection, or a manual trip, then done.
@MainActor
@Observable
final class AddTrainModel {
    var date = {
        #if DEBUG
        // `-addDate 2026-10-29` starts the sheet on that day.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-addDate"), args.indices.contains(i + 1) { return args[i + 1] }
        #endif
        return Format.todayIso()
    }() { didSet { if date != oldValue { showEarlier = false } } }
    /// Today's list starts at now; this brings back the trains that left more than ten minutes ago.
    var showEarlier = false
    var query = {
        #if DEBUG
        // `-addQuery "Stockholm → Göteborg"` fills the search field on launch, to check the results.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-addQuery"), args.indices.contains(i + 1) { return args[i + 1] }
        #endif
        return ""
    }() { didSet { if query != oldValue { showEarlier = false } } }
    private(set) var response: SearchResponse?
    private(set) var popular: [StationHit] = []
    private(set) var loading = false
    var searchFailed = false
    var filter = AddTrainLogic.Filter.all
    /// Bumped to ask again while an older day's timetable is fetched from the archive.
    private(set) var retry = 0
    var manual = false
    var picked: TripResult?
    /// Where the person got on was already chosen (a route search or a link with the boarding stop): the stop picker
    /// then starts at where they got off (`AddTrainLogic.firstEnd`).
    var originChosen = false
    var pickedConnection: TimetableConnection?
    /// A planned journey opened from the results (its detail screen).
    var pickedJourney: PlannedJourney?
    /// Most changes a journey may have: 0 direct only, 1, or 2 (the default). Filters, doesn't sort.
    var maxChanges = 2
    /// The shortest change you'll accept: 0 any the planner offers (tight too), 1 normal or more, 2 relaxed only
    /// (owner, 2026-10-28). Filters, doesn't sort.
    var minComfort = 0
    var saved: LegDetail?
    /// Opened with a trip already chosen (from a board or a link): going back leaves instead of searching.
    var openedWithTrip = false
    /// A leg to mark "not taken" once something is saved (replacing a cancelled or missed train).
    var replaceLegId: String?

    /// Changes whenever the search should run again.
    var searchKey: String { "\(query)|\(date)|\(retry)" }

    var interpretation: SearchResponse.Interpretation? { response?.interpretation }

    /// Today's trips that left more than ten minutes ago are left out, unless `showEarlier`.
    private func isEarlier(_ result: TripResult) -> Bool {
        date == Format.todayIso() && result.from.time < Date.now.timeIntervalSince1970 * 1000 - 10 * 60_000
    }

    var results: [TripResult]? {
        response?.results?.filter { AddTrainLogic.includes($0, filter) && (showEarlier || !isEarlier($0)) }
    }

    /// The planner's journeys for two stations, within the change filter, without those that left earlier today.
    var journeys: [PlannedJourney]? {
        response?.journeys?.filter { passes($0) && (showEarlier || !isEarlier($0.dep)) }
    }

    private func passes(_ j: PlannedJourney) -> Bool {
        j.changes.count <= maxChanges && j.changes.allSatisfy { Self.rank($0.comfort) >= minComfort }
    }

    /// tight 0, normal 1, relaxed 2 (risky never comes from the planner).
    static func rank(_ c: ChangeComfort) -> Int {
        switch c {
        case .relaxed: 2
        case .normal: 1
        default: 0
        }
    }

    /// Journeys are hidden by the filters alone (offer to show them all).
    var moreWithMoreChanges: Bool {
        (response?.journeys ?? []).contains { !passes($0) && (showEarlier || !isEarlier($0.dep)) }
    }

    var hasHiddenEarlierJourneys: Bool {
        !showEarlier && (response?.journeys ?? []).contains { passes($0) && isEarlier($0.dep) }
    }

    private func isEarlier(_ time: Double) -> Bool {
        date == Format.todayIso() && time < Date.now.timeIntervalSince1970 * 1000 - 10 * 60_000
    }

    /// Some results are hidden because they left earlier today.
    var hasHiddenEarlier: Bool {
        !showEarlier && (response?.results ?? []).contains { AddTrainLogic.includes($0, filter) && isEarlier($0) }
    }

    func loadPopular(_ client: APIClient) async {
        popular = (try? await client.popularStations()) ?? []
    }

    /// Opens straight at the confirm step for a timetable trip.
    func prefill(_ link: AddTrainLink, _ client: APIClient) async {
        openedWithTrip = true
        replaceLegId = link.replaceLegId
        do {
            let trip = try await client.timetableTrip(link.tripKey, date: link.date)
            date = link.date
            originChosen = link.fromSeq != nil
            picked = AddTrainLogic.result(from: trip, fromSeq: link.fromSeq, toSeq: link.toSeq)
        } catch {
            searchFailed = true
        }
    }

    /// A search result was chosen: the picker starts at where you got on unless the search named it.
    func pick(_ result: TripResult) {
        originChosen = interpretation?.from != nil
        picked = result
    }

    /// Runs the search after a short pause; a newer search (or the sheet closing) cancels this one.
    func runSearch(_ client: APIClient) async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            response = nil
            loading = false
            return
        }
        loading = true
        try? await Task.sleep(for: .milliseconds(150))
        if Task.isCancelled { return }
        do {
            response = try await client.search(query, date: date)
            searchFailed = false
            loading = false
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            searchFailed = true
            loading = false
        }
    }

    /// An older day's timetable is on its way: ask again every couple of seconds until it's in (every 15 if fetching
    /// it failed), for up to three minutes. One loop for the whole wait: the answer stays "loading" from one search to
    /// the next, so a task started per answer would only ever ask once.
    func waitForHistory() async {
        let started = Date.now
        while let history = response?.history, history == "loading" || history == "failed" {
            try? await Task.sleep(for: .seconds(history == "loading" ? 2 : 15))
            if Task.isCancelled || Date.now.timeIntervalSince(started) > 180 { return }
            // The search may have brought the day in while this slept: then there is nothing to ask again.
            guard let now = response?.history, now == "loading" || now == "failed" else { return }
            retry += 1
        }
    }

    /// The planner was still building the day: ask again every 3 s, for up to two minutes, until the journeys come.
    func waitForJourneys() async {
        let started = Date.now
        while response?.journeysPending == true {
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled || Date.now.timeIntervalSince(started) > 120 { return }
            guard response?.journeysPending == true else { return }
            retry += 1
        }
    }

    /// A day before yesterday was picked: start fetching its timetable now, before anything is typed.
    func prepareHistory(_ client: APIClient) async {
        guard let yesterday = Format.addDaysIso(Format.todayIso(), days: -1), date < yesterday else { return }
        try? await client.prepareHistory(date: date)
    }

    /// Saved one: if this replaced a cancelled or missed train, that one is marked as not taken, which you asked for by
    /// choosing this one; it stays in your trips and can be undone there.
    func didSave(_ leg: LegDetail, _ client: APIClient) {
        if let replace = replaceLegId, replace != leg.id {
            Task { _ = try? await client.answerRide(replace, .no) }
        }
        saved = leg
        Usage.shared.count(.feature, "trips.add")
        if let from = leg.leg.origin?.id, let to = leg.leg.destination?.id { Usage.shared.count(.route, "\(from)>\(to)") }
    }

    func reset() {
        saved = nil
        manual = false
        picked = nil
        originChosen = false
        pickedConnection = nil
        pickedJourney = nil
        maxChanges = 2
        minComfort = 0
        query = ""
    }
}
