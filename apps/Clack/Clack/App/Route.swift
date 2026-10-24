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
    /// Kept for old launch arguments and links only: opening it shows Explore's station search instead.
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
        // `-firstRun` shows the welcome and the alerts question again, as on a new phone.
        if args.contains("-firstRun") {
            UserDefaults.standard.removeObject(forKey: FirstRun.welcomeSeenKey)
            UserDefaults.standard.removeObject(forKey: FirstRun.alertsAskedKey)
            UserDefaults.standard.removeObject(forKey: FirstRun.alertsIntroSeenKey)
        }
        // `-sheetTrain <number>|<date>[|<key>]` opens that train in place, as a board row on Trips does.
        if let raw = value("-sheetTrain") {
            let parts = raw.split(separator: "|").map(String.init)
            if parts.count >= 2 { trainRequest = TrainRequest(number: parts[0], date: parts[1], key: parts.count > 2 ? parts[2] : nil) }
        }
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
            // Stations live in Explore's search now.
            if raw == "stations" { openStationSearch() }
            if raw == "about" { tripsPath = [.settings, .about] }
            if raw == "privacy" { tripsPath = [.settings, .privacy] }
            if raw == "testalerts" { tripsPath = [.settings, .testAlerts] }
            let parts = raw.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 {
                if parts[0] == "trip" { tripsPath = [.trip(parts[1])] }
                if parts[0] == "journey" { tripsPath = [.journey(parts[1])] }
                if parts[0] == "map" {
                    tab = .explore
                    explorePath = [.board(stationId: parts[1], arrivals: false), .stationMap(StationMapLink(stationId: parts[1]))]
                }
                if parts[0] == "layover" {
                    // `-open layover:<station>|<from track>|<to track>|<arrive ms>|<depart ms>`
                    let p = parts[1].split(separator: "|").map(String.init)
                    if p.count == 5 {
                        tripsPath = [.stationMap(StationMapLink(stationId: p[0], from: p[1], to: p[2], arrival: Double(p[3]), departure: Double(p[4]), live: true))]
                    }
                }
                if parts[0] == "board" {
                    tab = .explore
                    explorePath = [.board(stationId: parts[1], arrivals: false)]
                }
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
        if route == .stations { return openStationSearch() }
        setPath(path(for: tab) + [route], for: tab)
    }

    /// Opens a train on Explore's map (the sheet's "Show on live map", and links from outside).
    func openTrain(number: String, date: String, key: String? = nil) {
        trainRequest = nil
        pendingTrain = PendingTrain(number: number, date: date, key: key)
        tab = .explore
    }

    /// A train tapped inside the app (a board row, a followed train, a disruption's "Live"): on Explore the map moves
    /// to it; anywhere else its sheet opens over the screen you're on, and closing it leaves you where you were.
    func presentTrain(number: String, date: String, key: String? = nil) {
        switch Navigation.trainOpening(tab: tab) {
        case .focusOnMap: openTrain(number: number, date: date, key: key)
        case .sheet: trainRequest = TrainRequest(number: number, date: date, key: key)
        }
    }

    /// The train sheet shown over the current screen, when there is one.
    var trainRequest: TrainRequest?

    struct TrainRequest: Identifiable, Hashable {
        let id = UUID()
        var number: String
        var date: String
        var key: String?
    }

    /// Explore's search, opened empty with your stations under it (Trips' old station directory). Explore reads and
    /// clears it.
    var stationSearchRequest: UUID?

    func openStationSearch() {
        trainRequest = nil
        explorePath = []
        tab = .explore
        stationSearchRequest = UUID()
    }

    /// What the back button on the top screen of the showing tab says: the screen underneath, or the tab's name.
    func backLabel(_ l10n: L10n) -> String {
        l10n.t(Navigation.backLabelKey(below: Navigation.below(path(for: tab)).map(\.screen), tab: tab))
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
        trainRequest = nil
        setPath(path, for: tab)
        self.tab = tab
    }
}

extension AppRoute {
    /// What kind of screen this is, for the back button of the one above it.
    var screen: Navigation.Screen {
        switch self {
        case .trip: .trip
        case .journey: .journey
        case .settings: .settings
        case .about: .about
        case .privacy: .privacy
        case .board: .board
        case .stationMap: .stationMap
        case .stations: .other
        #if DEBUG
        case .testAlerts: .other
        #endif
        }
    }
}
