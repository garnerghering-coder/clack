//
//  Route.swift
//  Clack
//

import ClackCore
import Foundation
import Observation
import ClackDesign
import SwiftUI

/// Where a tap goes: the in-app equivalents of the web's URLs (docs/swift-port/SCREENS.md §1.5).
nonisolated enum AppRoute: Hashable, Sendable {
    case trip(String)
    case journey(String)
    case settings
    case about
    case privacy
    case stations
    case board(stationId: String, arrivals: Bool)
    case stationMap(StationMapLink)
    #if DEBUG
    /// Settings > Test alerts (debug builds only).
    case testAlerts
    #endif
}

/// Which tab is showing and what each tab has pushed. The last tab is remembered for the next launch
/// (`Landing.saveLastTab`).
@MainActor
@Observable
final class Router {
    var tab: PrimaryTab = .trips
    /// Which part of Trips shows (Passport links to Past).
    var tripsTab: TripsTab = .upcoming
    /// Set by any touch or link before the landing rule has decided: it then leaves the tab alone.
    var touched = false

    init() {
        #if DEBUG
        // Launch arguments for checking a screen without tapping: `-tab explore`, `-tripsTab past`.
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        if let raw = value("-tab"), let tab = PrimaryTab(rawValue: raw) { self.tab = tab }
        if let raw = value("-tripsTab"), let tab = TripsTab(rawValue: raw) { tripsTab = tab }
        // `-add` opens the Add a train sheet; `-addTrip <key>|<date>|<from>|<to>` at its confirm step.
        if args.contains("-add") { addRequest = AddRequest(link: nil) }
        if let raw = value("-addTrip") {
            let parts = raw.split(separator: "|").map(String.init)
            if parts.count >= 2 {
                addRequest = AddRequest(link: AddTrainLink(tripKey: parts[0], date: parts[1], fromSeq: parts.count > 2 ? Int(parts[2]) : nil, toSeq: parts.count > 3 ? Int(parts[3]) : nil))
            }
        }
        // `-train <number>|<date>[|<key>]` opens that train on Explore, as a board row does.
        if let raw = value("-train") {
            let parts = raw.split(separator: "|").map(String.init)
            if parts.count >= 2 {
                pendingTrain = PendingTrain(number: parts[0], date: parts[1], key: parts.count > 2 ? parts[2] : nil)
                tab = .explore
            }
        }
        // `-open trip:<id>` or `-open journey:<id>` pushes that screen on the Trips tab.
        if let raw = value("-open") {
            // Asked for a screen: the landing rule leaves it in front, as it does for a link.
            touched = true
            if raw == "settings" { tripsPath = [.settings] }
            if raw == "stations" { tripsPath = [.stations] }
            if raw == "about" { tripsPath = [.settings, .about] }
            if raw == "privacy" { tripsPath = [.settings, .privacy] }
            if raw == "testalerts" { tripsPath = [.settings, .testAlerts] }
            let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                if parts[0] == "trip" { tripsPath = [.trip(parts[1])] }
                if parts[0] == "journey" { tripsPath = [.journey(parts[1])] }
                if parts[0] == "map" { tripsPath = [.stations, .board(stationId: parts[1], arrivals: false), .stationMap(StationMapLink(stationId: parts[1]))] }
                if parts[0] == "layover" {
                    // `-open layover:<station>|<from track>|<to track>|<arrive ms>|<depart ms>`
                    let p = parts[1].split(separator: "|").map(String.init)
                    if p.count == 5 {
                        tripsPath = [.stationMap(StationMapLink(stationId: p[0], from: p[1], to: p[2], arrival: Double(p[3]), departure: Double(p[4]), live: true))]
                    }
                }
                if parts[0] == "board" { tripsPath = [.stations, .board(stationId: parts[1], arrivals: false)] }
            }
        }
        #endif
    }
    var tripsPath: [AppRoute] = []
    var explorePath: [AppRoute] = []
    var passportPath: [AppRoute] = []
    /// The Add a train sheet, when it's open: a full-height sheet over everything, tab bar included.
    var addRequest: AddRequest?
    /// A ticket shared to Clack, waiting to be read.
    var ticketFile: TicketFile?

    struct AddRequest: Identifiable, Hashable {
        let id = UUID()
        var link: AddTrainLink?
    }

    func openAdd(_ link: AddTrainLink? = nil) {
        addRequest = AddRequest(link: link)
    }

    func closeAdd() {
        addRequest = nil
    }

    /// A train Explore should open when it appears (`/explore?train=N&date=D&key=K`; the Explore screen reads and clears it).
    var pendingTrain: PendingTrain?

    struct PendingTrain: Hashable, Sendable {
        var number: String
        var date: String
        var key: String?
    }

    /// The path of a tab, for a `NavigationStack` binding.
    func path(for tab: PrimaryTab) -> [AppRoute] {
        switch tab {
        case .trips: tripsPath
        case .explore: explorePath
        case .passport: passportPath
        }
    }

    func setPath(_ path: [AppRoute], for tab: PrimaryTab) {
        switch tab {
        case .trips: tripsPath = path
        case .explore: explorePath = path
        case .passport: passportPath = path
        }
    }

    /// Pushes a screen on the tab that is showing.
    func push(_ route: AppRoute) {
        setPath(path(for: tab) + [route], for: tab)
    }

    /// Opens a train on Explore (from a board row, a follow, or a link).
    func openTrain(number: String, date: String, key: String? = nil) {
        pendingTrain = PendingTrain(number: number, date: date, key: key)
        tab = .explore
    }

    /// The one way in from outside the app: `clack://` links (widgets, the trip card), alert taps and the `-url` launch
    /// argument. It closes the Add sheet, shows the link's tab with only the linked screen on it, and stops the landing
    /// rule from moving you somewhere else afterwards.
    func open(_ link: DeepLink, app: AppModel) {
        touched = true
        app.hasLanded = true
        addRequest = nil
        // The arrival screen covers everything; another link means you want to see that instead.
        if case .arrival = link {} else if app.arrivals.pending != nil { app.arrivals.dismiss() }
        switch link {
        case .trip(let id): show(.trips, [.trip(id)])
        case .journey(let id): show(.trips, [.journey(id)])
        case .board(let id, let arrivals): show(.explore, [.board(stationId: id, arrivals: arrivals)])
        case .train(let number, let date, let key):
            show(.explore, [])
            pendingTrain = PendingTrain(number: number, date: date, key: key)
        case .tab(let tab): show(tab, [])
        case .add(let link): addRequest = AddRequest(link: link)
        case .arrival(let legId, let journeyId):
            let client = app.client
            let arrivals = app.arrivals
            Task {
                // A link may carry only the leg: its journey (if it has one) is on the leg itself.
                var journey = journeyId
                if journey == nil { journey = (try? await client.leg(legId))?.leg.journeyId }
                arrivals.show(ArrivalMoment(legId: legId, journeyId: journey))
            }
        }
    }

    private func show(_ tab: PrimaryTab, _ path: [AppRoute]) {
        setPath(path, for: tab)
        self.tab = tab
    }
}
