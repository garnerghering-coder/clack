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
    }() {
        didSet {
            guard date != oldValue else { return }
            showEarlier = false
            // Another day's answer is not this one's: the skeletons stand in until it comes, never the old day's trains.
            clearAnswer()
        }
    }
    /// Today's list starts at now; this brings back the trains that left more than ten minutes ago.
    var showEarlier = false
    /// The text typed after the stations picked (the field's chips): a station being typed, an operator or a number.
    /// Typing never searches; it only asks for suggestions.
    var query = {
        #if DEBUG
        // `-addQuery "Stockholm → Göteborg"` fills the search field on launch, to check the results.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-addQuery"), args.indices.contains(i + 1) { return args[i + 1] }
        #endif
        return ""
    }() { didSet { if query != oldValue { showEarlier = false } } }
    /// The stations picked so far, shown as chips in the field. Picking the second one searches (owner, 2026-11-17).
    private(set) var fromStation: StationHit?
    private(set) var toStation: StationHit?
    /// What was last searched; nil while the person is still typing or picking.
    private(set) var committed: AddTrainLogic.Commit?
    private(set) var response: SearchResponse?
    /// How the text being typed reads and the stations to pick from (`GET /search/suggest`: nothing from the
    /// timetable, so it answers at once).
    private(set) var suggestion: SearchResponse?
    /// The stations to offer while typing.
    var suggestions: [StationHit] { committed == nil && toStation == nil ? suggestion?.suggestions ?? [] : [] }
    /// "SJ 523" while the text reads as a train number: the row that searches it.
    var numberSearch: String? { committed == nil && toStation == nil ? AddTrainLogic.numberSearch(suggestion?.interpretation) : nil }
    /// The station the text names before the one still being typed ("Uppsala Sto": Uppsala C), picked together with
    /// the destination when one is tapped.
    private var typedOrigin: StationHit? {
        guard fromStation == nil, suggestion?.interpretation.typing == "to" else { return nil }
        return suggestion?.interpretation.from
    }
    /// Where the trip starts, picked or read from the search.
    var routeFrom: StationHit? { fromStation ?? interpretation?.from }
    var routeTo: StationHit? { toStation ?? interpretation?.to }
    private(set) var popular: [StationHit] = []
    private(set) var recentRoutes: [RecentRoute] = []
    /// Days whose planner the server was asked to start building, so each is asked once.
    private var warmed = Set<String>()
    private(set) var loading = false
    var searchFailed = false
    /// Why the last search failed (no connection, the server down…), for the error state's wording.
    private(set) var searchFailure: APIError.Kind?
    /// The search's retries while they wait ("Trying again in 4 s"), heard from its request.
    let searchRetry = RetryTracker()
    /// Opened from a link ("Use this instead", a board's Plan): the train being opened, until its confirm step is in.
    /// The sheet shows that it's opening it, not an empty search.
    private(set) var opening: AddTrainLink?
    /// Opening it failed, and why: the sheet names the train with Try again and a way to search instead.
    private(set) var openFailure: APIError.Kind?
    /// Opening's retries while they wait.
    let openRetry = RetryTracker()
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
    var maxChanges = {
        #if DEBUG
        // `-addChanges 5` starts the change filter there, to look at journeys with many trains.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-addChanges"), args.indices.contains(i + 1), let n = Int(args[i + 1]) { return n }
        #endif
        return AddTrainModel.defaultMaxChanges
    }()
    static let defaultMaxChanges = 2
    static let maxChangesLimit = 5
    /// One page of journeys: six hours, moved earlier or later on request.
    static let pageHours = 6
    private static var pageMs: Double { Double(pageHours) * 3600_000 }
    /// Journeys from Show earlier and Show later, added to the first answer's; the window the whole list covers.
    private(set) var pagedJourneys: [PlannedJourney] = []
    /// The next Show later's journeys, fetched as soon as the list is in so the button answers at once.
    private var prefetchedLater: (key: String, after: Double, page: [PlannedJourney])?
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
    /// Delete the replaced trip instead (another train chosen for a trip still ahead).
    var deleteReplaced = false

    init(opening: AddTrainLink? = nil) {
        self.opening = opening
    }

    /// Changes whenever the search should run again: a new search, another day, or asking again. Not the typing.
    var searchKey: String {
        guard let c = committed else { return "" }
        return "\(c.text)|\(c.fromId ?? "")|\(c.toId ?? "")|\(date)|\(retry)"
    }

    /// Changes whenever the suggestions should be asked for again.
    var suggestKey: String { "\(query)|\(fromStation?.id ?? "")|\(toStation?.id ?? "")|\(committed == nil)" }

    /// The search out is for two stations (journeys), not a train number.
    private(set) var expectsJourneys = true

    /// A search is out or in: the results' part of the screen shows, not the suggestions.
    var searching: Bool { committed != nil }

    var interpretation: SearchResponse.Interpretation? { response?.interpretation }

    /// Today's trips that left more than ten minutes ago are left out, unless `showEarlier`.
    private func isEarlier(_ result: TripResult) -> Bool {
        date == Format.todayIso() && result.from.time < Date.now.timeIntervalSince1970 * 1000 - 10 * 60_000
    }

    /// The filtered results; today's trains that already left are hidden unless asked for, except when they are all
    /// there is: the one train you searched for is never hidden behind "Show earlier" (user test 2026-11-07).
    var results: [TripResult]? {
        guard let all = response?.results?.filter({ AddTrainLogic.includes($0, filter) }) else { return nil }
        let ahead = all.filter { !isEarlier($0) }
        return showEarlier || ahead.isEmpty ? all : ahead
    }

    /// Every result shown has already left today (the list says so instead of hiding them).
    var showingOnlyDeparted: Bool {
        guard !showEarlier, let all = results, !all.isEmpty else { return false }
        return all.allSatisfy { isEarlier($0) }
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

    /// A line to write above `journey` when it leaves on a different day than the one before it: "Fri 31 Oct". The
    /// first journey always carries its day once the list spans more than the day searched (after Show earlier or
    /// later), or when it isn't on that day; nil otherwise (user test 2026-11-07: Saturday's trains stood under a
    /// chip that said Sunday with nothing between).
    func daySeparator(before journey: PlannedJourney, previous: PlannedJourney?, language: Language) -> String? {
        let tz = journey.legs.first?.from.tz ?? "Europe/Stockholm"
        let day = Format.localDate(journey.dep, tz: tz)
        guard let previous else {
            return day != date || !pagedJourneys.isEmpty ? Format.day(journey.dep, tz: tz, language: language) : nil
        }
        let before = Format.localDate(previous.dep, tz: previous.legs.first?.from.tz ?? tz)
        return day == before ? nil : Format.day(journey.dep, tz: tz, language: language)
    }

    /// The day the next "Show earlier" reaches into, when it isn't the day the list starts on (the button then names
    /// it: "Show earlier · Sat 7 Nov"). Nil while paging stays within one day.
    func earlierDay(language: Language) -> String? {
        guard let w = window else { return nil }
        let tz = response?.interpretation.from.flatMap { Format.zone(country: $0.country) } ?? Format.defaultZone
        let reached = w.start - Self.pageMs
        return Format.localDate(reached, tz: tz) == Format.localDate(w.start, tz: tz) ? nil : Format.day(reached, tz: tz, language: language)
    }

    /// The day the next "Show later" reaches into, when it crosses midnight; nil otherwise.
    func laterDay(language: Language) -> String? {
        guard let w = window else { return nil }
        let tz = response?.interpretation.from.flatMap { Format.zone(country: $0.country) } ?? Format.defaultZone
        return Format.localDate(w.end, tz: tz) == Format.localDate(w.end - 1, tz: tz) ? nil : Format.day(w.end, tz: tz, language: language)
    }

    /// For a day searched whole (not today): the first journey of that day when it leaves late in the morning or
    /// later, or nil. The list then says "Nothing before 13:44 on Sun 8 Nov in the timetable", so a reduced weekend
    /// timetable reads as what it is, not as a list anchored to the wrong hour (user test 2026-11-07, København H →
    /// Malmö C on Sun 8 Nov: works, first train 13:44, and two testers pressed Show earlier into Saturday).
    func lateFirstJourney(now: Date = .now) -> PlannedJourney? {
        guard date != Format.todayIso(), let first = response?.journeys?.filter({ passes($0) }).sorted(by: { $0.dep < $1.dep }).first else { return nil }
        let tz = first.legs.first?.from.tz ?? "Europe/Stockholm"
        guard Format.localDate(first.dep, tz: tz) == date else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: tz) ?? .current
        let hour = calendar.component(.hour, from: Date(timeIntervalSince1970: first.dep / 1000))
        return hour >= 9 ? first : nil
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
        // Fetched ahead (`prefetchLater`): no wait.
        if let ahead = prefetchedLater, ahead.key == searchKey, ahead.after == w.end {
            prefetchedLater = nil
            pagedJourneys += ahead.page
            window = .init(start: w.start, end: w.end + Self.pageMs)
            laterEmpty = ahead.page.isEmpty
            return
        }
        pagingLater = true
        defer { pagingLater = false }
        if let page = await fetchPage(client, after: w.end) {
            pagedJourneys += page
            window = .init(start: w.start, end: w.end + Self.pageMs)
            laterEmpty = page.isEmpty
        }
    }

    /// Fetches the next Show later's page in the background once the list's window is known (and again after each
    /// press), so the button opens it at once.
    func prefetchLater(_ client: APIClient) async {
        guard let w = window, prefetchedLater?.after != w.end else { return }
        let key = searchKey
        guard let page = await fetchPage(client, after: w.end), key == searchKey, window?.end == w.end else { return }
        prefetchedLater = (key, w.end, page)
    }

    /// One window of journeys, waiting a few times while the server builds a new day's index. Nil when the search
    /// changed meanwhile or the server didn't answer (its request retries a failure itself, with backoff).
    private func fetchPage(_ client: APIClient, after: Double) async -> [PlannedJourney]? {
        let key = searchKey
        guard let c = committed else { return nil }
        for _ in 0..<6 {
            guard let page = try? await client.search(c.text, date: date, fromId: c.fromId, toId: c.toId, changes: Self.maxChangesLimit, after: after, hours: Self.pageHours) else { return nil }
            guard key == searchKey else { return nil }
            if page.journeysPending != true { return page.journeys ?? [] }
            // Still building: a healthy wait, not a failure, so it stays at 3 s.
            guard await RetryWake.pause(3) else { return nil }
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

    func loadRecentRoutes(_ client: APIClient) async {
        recentRoutes = (try? await client.recentRoutes()) ?? []
    }

    // MARK: typing, picking, searching

    /// The field's text changed by the person: back to picking (the last search's results make way for suggestions).
    func edit(_ text: String) {
        guard text != query else { return }
        query = text
        if committed != nil { clearSearch() }
    }

    /// A suggested station was tapped. The first becomes the origin chip (and the server starts on the day's planner);
    /// the second, or one tapped while the text already named the origin, completes the route and searches.
    func pick(_ station: StationHit, _ client: APIClient) {
        let residue = AddTrainLogic.residue(after: suggestion?.interpretation)
        if let origin = fromStation ?? typedOrigin, origin.id != station.id {
            fromStation = origin
            toStation = station
            query = residue
            suggestion = nil
            search()
        } else {
            fromStation = station
            query = residue
            suggestion = nil
            warm(client)
        }
    }

    /// A chip was tapped: that station and the one after it are taken off, and the search with them.
    func unpick(from: Bool) {
        if from { fromStation = nil }
        toStation = nil
        clearSearch()
    }

    /// Both stations the other way round, searched again (the trip home).
    func swap() {
        guard let from = fromStation, let to = toStation else { return }
        fromStation = to
        toStation = from
        search()
    }

    /// A route from Recent: both stations picked, searched.
    func pick(_ route: RecentRoute) {
        fromStation = route.from
        toStation = route.to
        query = ""
        search()
    }

    /// Text put in whole and searched: an example, or a search opened from another screen.
    func search(text: String) {
        fromStation = nil
        toStation = nil
        query = text
        search()
    }

    /// Return in the field: while a station is being picked (nothing reads as a number), the top suggestion is taken,
    /// as a tap would; else the field is searched as it stands.
    func submit(_ client: APIClient) {
        if committed == nil, toStation == nil, numberSearch == nil, let top = suggestions.first {
            pick(top, client)
        } else {
            search()
        }
    }

    /// Searches the field as it stands (the second pick, Return, the number row). The same search again only asks again
    /// after a failure.
    func search() {
        guard let c = AddTrainLogic.commit(from: fromStation, to: toStation, text: query) else { return }
        if c == committed {
            if searchFailed { retry += 1 }
            return
        }
        clearAnswer()
        // What the skeletons look like: train cards for a number, journeys otherwise.
        expectsJourneys = suggestion?.interpretation.trainNumber == nil || c.fromId != nil
        committed = c
        // Loading from this frame: the skeletons show at once, not after the request has gone out.
        loading = true
    }

    /// Back to picking: no search, no answer.
    private func clearSearch() {
        committed = nil
        clearAnswer()
        loading = false
        searchFailed = false
        searchFailure = nil
    }

    private func clearAnswer() {
        response = nil
        pagedJourneys = []
        window = nil
        prefetchedLater = nil
        laterEmpty = false
    }

    /// Asks the server to start building the day's planner (once per day), while the destination is still typed.
    private func warm(_ client: APIClient) {
        guard !warmed.contains(date) else { return }
        warmed.insert(date)
        let day = date
        Task { try? await client.warmPlanner(date: day) }
    }

    /// The suggestions for the text being typed, after a short pause; a newer keystroke cancels this one. An older
    /// server without the suggest step gets the plain station search for the part being typed.
    func runSuggest(_ client: APIClient) async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard committed == nil, toStation == nil, !text.isEmpty else {
            suggestion = nil
            return
        }
        try? await Task.sleep(for: .milliseconds(120))
        if Task.isCancelled { return }
        do {
            let answer = try await client.suggest(text, date: date, fromId: fromStation?.id)
            if Task.isCancelled { return }
            suggestion = answer
        } catch {
            if APIError.classify(error) == .cancelled || Task.isCancelled { return }
            let hits = (try? await client.searchStations(AddTrainLogic.typedTerm(text), limit: 6)) ?? []
            if Task.isCancelled { return }
            suggestion = SearchResponse(
                date: date, interpretation: .init(operator: nil, trainNumber: nil, from: nil, to: nil, typing: fromStation == nil ? "from" : "to"),
                suggestions: hits.filter { $0.id != fromStation?.id }, results: nil, connections: nil, outsideTimetable: false, history: nil
            )
        }
    }

    /// Opens straight at the confirm step for a timetable trip. Meanwhile the sheet says what it's opening; a failure
    /// that can pass is asked again with backoff (the read policy), and one that doesn't says so with the train named.
    func prefill(_ link: AddTrainLink, _ client: APIClient) async {
        openedWithTrip = true
        replaceLegId = link.replaceLegId
        opening = link
        openFailure = nil
        do {
            let trip = try await openRetry.run { try await client.timetableTrip(link.tripKey, date: link.date) }
            date = link.date
            originChosen = link.fromSeq != nil
            picked = AddTrainLogic.result(from: trip, fromSeq: link.fromSeq, toSeq: link.toSeq)
            opening = nil
        } catch {
            let kind = APIError.classify(error)
            if kind != .cancelled { openFailure = kind }
        }
    }

    /// Gives up opening the linked train and goes to the ordinary search (the replaced trip is still replaced by
    /// whatever is saved).
    func searchInstead() {
        opening = nil
        openFailure = nil
        openedWithTrip = false
    }

    /// A search result was chosen: the picker starts at where you got on unless the search named it.
    func pick(_ result: TripResult) {
        originChosen = interpretation?.from != nil
        picked = result
    }

    /// Runs the search that was asked for (no pause: it was asked for on purpose); a newer one, another day, or the
    /// sheet closing cancels it.
    func runSearch(_ client: APIClient) async {
        guard let c = committed else {
            loading = false
            return
        }
        loading = true
        do {
            // Today's journeys from ten minutes ago, one page at a time; another day whole. The planner is asked for
            // the most changes it does, and the filter picks from that. A dropped connection or a server still
            // starting is asked again by the request itself (up to five tries, 1 s, 2 s, 4 s, 8 s apart, sooner when
            // the connection comes back), and the list says so meanwhile.
            let today = date == Format.todayIso()
            let after: Double? = today ? Date.now.timeIntervalSince1970 * 1000 - 10 * 60_000 : nil
            let answer = try await searchRetry.run {
                try await client.search(c.text, date: date, fromId: c.fromId, toId: c.toId, changes: Self.maxChangesLimit, after: after, hours: today ? Self.pageHours : nil)
            }
            guard c == committed, !Task.isCancelled else { return }
            // Not a search yet (one station alone, Return before its suggestions came): back to picking, with the
            // stations it read to choose from.
            if answer.results == nil, answer.journeys == nil, !answer.outsideTimetable, answer.journeysPending != true {
                clearSearch()
                suggestion = answer
                return
            }
            response = answer
            pagedJourneys = []
            window = answer.window
            laterEmpty = false
            searchFailed = false
            searchFailure = nil
            loading = false
            // Typed as text ("Uppsala Stockholm" and Return): the stations it found become the chips, so the field
            // says what was searched. The search itself stays as it was asked.
            if fromStation == nil || toStation == nil, let route = AddTrainLogic.pickedRoute(from: answer) {
                fromStation = route.from
                toStation = route.to
                query = AddTrainLogic.residue(after: answer.interpretation)
            }
        } catch {
            let kind = APIError.classify(error)
            if kind == .cancelled || c != committed { return }
            searchFailed = true
            searchFailure = kind
            loading = false
        }
    }

    /// Try again after a failure.
    func searchAgain() {
        if searchFailed { retry += 1 }
    }

    /// An older day's timetable is on its way: ask again every couple of seconds until it's in (every 15 if fetching
    /// it failed), for up to three minutes. One loop for the whole wait: the answer stays "loading" from one search to
    /// the next, so a task started per answer would only ever ask once.
    func waitForHistory() async {
        let started = Date.now
        // Loading is healthy (every 2 s); a failed fetch backs off from 15 s, doubling, up to two minutes.
        var retrier = Retrier(RetryPolicy(tries: nil, base: 15, cap: 120, every: 2))
        while let history = response?.history, history == "loading" || history == "failed" {
            let wait = history == "loading" ? retrier.succeeded() ?? 2 : retrier.failed(.serverDown) ?? 15
            guard await RetryWake.pause(wait) else { return }
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
            // A healthy wait (the planner is working), so it keeps its pace.
            guard await RetryWake.pause(3) else { return }
            if Task.isCancelled || Date.now.timeIntervalSince(started) > 120 { return }
            guard response?.journeysPending == true else { return }
            retry += 1
        }
    }

    /// A day before yesterday was picked: start fetching its timetable now, before anything is typed.
    func prepareHistory(_ client: APIClient) async {
        // A new day with the origin already picked: its planner, too.
        if fromStation != nil { warm(client) }
        guard let yesterday = Format.addDaysIso(Format.todayIso(), days: -1), date < yesterday else { return }
        try? await client.prepareHistory(date: date)
    }

    /// Saved one: if this replaced a cancelled or missed train, that one is marked as not taken, which you asked for by
    /// choosing this one; it stays in your trips and can be undone there.
    func didSave(_ leg: LegDetail, _ client: APIClient) {
        if let replace = replaceLegId, replace != leg.id {
            let delete = deleteReplaced
            Task {
                if delete { try? await client.deleteLeg(replace) } else { _ = try? await client.answerRide(replace, .no) }
            }
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
        fromStation = nil
        toStation = nil
        query = ""
        suggestion = nil
        clearSearch()
    }
}
