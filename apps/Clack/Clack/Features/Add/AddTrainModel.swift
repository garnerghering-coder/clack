//
//  AddTrainModel.swift
//  Clack
//

import Foundation
import Observation

/// What the Add a train sheet holds: the date, the text, what the search found, and which step it's on
/// (AddTripPage.tsx): search, then the confirm step for a train or a connection, or a manual trip, then done.
@MainActor
@Observable
final class AddTrainModel {
    var date = Format.todayIso()
    var query = {
        #if DEBUG
        // `-addQuery "Stockholm → Göteborg"` fills the search field on launch, to check the results.
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-addQuery"), args.indices.contains(i + 1) { return args[i + 1] }
        #endif
        return ""
    }()
    private(set) var response: SearchResponse?
    private(set) var popular: [StationHit] = []
    private(set) var loading = false
    var searchFailed = false
    var filter = AddTrainLogic.Filter.all
    /// Bumped to ask again while an older day's timetable is fetched from the archive.
    private(set) var retry = 0
    var manual = false
    var picked: TripResult?
    var pickedConnection: TimetableConnection?
    var saved: LegDetail?
    /// Opened with a trip already chosen (from a board or a link): going back leaves instead of searching.
    var openedWithTrip = false
    /// A leg to mark "not taken" once something is saved (replacing a cancelled or missed train).
    var replaceLegId: String?

    /// Changes whenever the search should run again.
    var searchKey: String { "\(query)|\(date)|\(retry)" }

    var interpretation: SearchResponse.Interpretation? { response?.interpretation }

    var results: [TripResult]? {
        response?.results?.filter { AddTrainLogic.includes($0, filter) }
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
            picked = AddTrainLogic.result(from: trip, fromSeq: link.fromSeq, toSeq: link.toSeq)
        } catch {
            searchFailed = true
        }
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

    /// An older day's timetable is on its way: ask again until it's in.
    func waitForHistory() async {
        guard let history = response?.history, history == "loading" || history == "failed" else { return }
        try? await Task.sleep(for: .seconds(history == "loading" ? 3 : 15))
        if !Task.isCancelled { retry += 1 }
    }

    /// Saved one: if this replaced a cancelled or missed train, that one is marked as not taken, which you asked for by
    /// choosing this one; it stays in your trips and can be undone there.
    func didSave(_ leg: LegDetail, _ client: APIClient) {
        if let replace = replaceLegId, replace != leg.id {
            Task { _ = try? await client.answerRide(replace, .no) }
        }
        saved = leg
    }

    func reset() {
        saved = nil
        manual = false
        picked = nil
        pickedConnection = nil
        query = ""
    }
}
