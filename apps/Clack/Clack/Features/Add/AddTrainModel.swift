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
    /// Most changes a journey may have: 0 direct only, up to 5; two by default. Filters, doesn't sort (the planner is
    /// always asked for the most, so changing the filter never searches again).
    var maxChanges = AddTrainModel.defaultMaxChanges
    static let defaultMaxChanges = 2
    static let maxChangesLimit = 5
    /// One page of journeys: six hours, moved earlier or later on request.
    static let pageHours = 6
    private static var pageMs: Double { Double(pageHours) * 3600_000 }
    /// Journeys from Show earlier and Show later, added to the first answer's; the window the whole list covers.
    private(set) var pagedJourneys: [PlannedJourney] = []
    private(set) var window: SearchResponse.Window?
    private(set) var pagingEarlier = false
    private(set) var pagingLater = false
    /// The last Show later found nothing, which the list says.
    private(set) var laterEmpty = false
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

    /// The planner's journeys for two stations, every page so far, by departure, within the change filter. Today's
    /// first page starts ten minutes ago (the window the server was asked for), so nothing is hidden here.
    var journeys: [PlannedJourney]? {
        guard let first = response?.journeys else { return nil }
        return allJourneys(first).filter { passes($0) }
    }

    private func allJourneys(_ first: [PlannedJourney]) -> [PlannedJourney] {
        var seen = Set<String>()
        return (first + pagedJourneys)
            .sorted { ($0.dep, $0.arr) < ($1.dep, $1.arr) }
            .filter { seen.insert($0.id).inserted }
    }

    /// A line to write above `journey` when it leaves on a different day than the one before it (or than the day
    /// searched, for the first): "Fri 31 Oct". Nil when it's the same day.
    func daySeparator(before journey: PlannedJourney, previous: PlannedJourney?, language: Language) -> String? {
        let tz = journey.legs.first?.from.tz ?? "Europe/Stockholm"
        let day = Format.localDate(journey.dep, tz: tz)
        let before = previous.map { Format.localDate($0.dep, tz: $0.legs.first?.from.tz ?? tz) } ?? date
        return day == before ? nil : Format.day(journey.dep, tz: tz, language: language)
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
        allJourneys(response?.journeys ?? []).contains { !passes($0) }
    }

    /// Six more hours of journeys before the list. The server plans the day the window falls in, so this walks back
    /// across midnight by itself.
    func showEarlierJourneys(_ client: APIClient) async {
        guard let w = window, !pagingEarlier else { return }
        pagingEarlier = true
        defer { pagingEarlier = false }
        let start = w.start - Self.pageMs
        if let page = await fetchPage(client, after: start) {
            pagedJourneys += page
            window = .init(start: start, end: w.end)
        }
    }

    /// Six more hours of journeys after the list.
    func showLaterJourneys(_ client: APIClient) async {
        guard let w = window, !pagingLater else { return }
        pagingLater = true
        defer { pagingLater = false }
        if let page = await fetchPage(client, after: w.end) {
            pagedJourneys += page
            window = .init(start: w.start, end: w.end + Self.pageMs)
            laterEmpty = page.isEmpty
        }
    }

    /// One window of journeys, waiting a few times while the server builds a new day's index. Nil when the search
    /// changed meanwhile or the server didn't answer.
    private func fetchPage(_ client: APIClient, after: Double) async -> [PlannedJourney]? {
        let key = searchKey
        for _ in 0..<6 {
            guard let page = try? await client.search(query, date: date, changes: Self.maxChangesLimit, after: after, hours: Self.pageHours) else { return nil }
            guard key == searchKey else { return nil }
            if page.journeysPending != true { return page.journeys ?? [] }
            try? await Task.sleep(for: .seconds(3))
            if Task.isCancelled { return nil }
        }
        return nil
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
            pagedJourneys = []
            window = nil
            loading = false
            return
        }
        loading = true
        try? await Task.sleep(for: .milliseconds(150))
        if Task.isCancelled { return }
        do {
            // Today's journeys from ten minutes ago, one page at a time; another day whole. The planner is asked for
            // the most changes it does, and the filter picks from that.
            let today = date == Format.todayIso()
            let after: Double? = today ? Date.now.timeIntervalSince1970 * 1000 - 10 * 60_000 : nil
            let answer = try await client.search(query, date: date, changes: Self.maxChangesLimit, after: after, hours: today ? Self.pageHours : nil)
            response = answer
            pagedJourneys = []
            window = answer.window
            laterEmpty = false
            searchFailed = false
            failedTries = 0
            loading = false
        } catch is CancellationError {
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            searchFailed = true
            loading = false
            // A dropped connection or a server still starting: ask again by itself, a few times, 4 s apart.
            if failedTries < 3 {
                failedTries += 1
                try? await Task.sleep(for: .seconds(4))
                if !Task.isCancelled { retry += 1 }
            }
        }
    }

    /// Failed searches in a row (reset by an answer), for the automatic retries.
    private var failedTries = 0

    /// Search pressed again (or the text submitted): runs the same search once more after a failure.
    func searchAgain() {
        failedTries = 0
        if searchFailed { retry += 1 }
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
