//
//  Route.swift
//  Clack
//

import Foundation
import Observation
import SwiftUI

/// The Layover Guide's inputs from a connection (the web's `/stations/:id/map?from=&to=&arr=&dep=&a=&b=&xa=&xb=&live=`).
nonisolated struct StationMapLink: Hashable, Sendable {
    var stationId: String
    var from: String?
    var to: String?
    var arrival: Double?
    var departure: Double?
    var operatorA: String?
    var operatorB: String?
    var canceledA = false
    var canceledB = false
    var live = false
}

/// Opens Add a train straight at the confirm step for a timetable trip (`/add?trip=K&date=D&from=&to=&replace=`).
nonisolated struct AddTrainLink: Hashable, Sendable {
    var tripKey: String
    var date: String
    var fromSeq: Int?
    var toSeq: Int?
    /// A leg to mark "not taken" once this one is saved (replacing a cancelled train).
    var replaceLegId: String?
}

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
}

/// Which tab is showing and what each tab has pushed. The last tab is remembered for the next launch
/// (`Landing.saveLastTab`).
@MainActor
@Observable
final class Router {
    var tab: PrimaryTab = .trips
    /// Which part of Trips shows (Passport links to Past).
    var tripsTab: TripsTab = .upcoming

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
        // `-open trip:<id>` or `-open journey:<id>` pushes that screen on the Trips tab.
        if let raw = value("-open") {
            if raw == "settings" { tripsPath = [.settings] }
            if raw == "stations" { tripsPath = [.stations] }
            if raw == "about" { tripsPath = [.settings, .about] }
            if raw == "privacy" { tripsPath = [.settings, .privacy] }
            let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                if parts[0] == "trip" { tripsPath = [.trip(parts[1])] }
                if parts[0] == "journey" { tripsPath = [.journey(parts[1])] }
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
}
