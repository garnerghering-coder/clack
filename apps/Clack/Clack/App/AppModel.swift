//
//  AppModel.swift
//  Clack
//

import Foundation
import Observation
import SwiftUI

/// What the whole app shares: the phone's id, the server client, the texts, and the reference data loaded at launch
/// (settings, operators, train types, amenities).
@Observable
final class AppModel {
    enum LoadState: Equatable {
        case loading
        case ready
        case failed
    }

    let identity: String
    let client: APIClient
    let l10n: L10n
    let connection: ConnectionState
    let offlineCache: OfflineCache
    @ObservationIgnored let live: LiveHub
    @ObservationIgnored let stations: StationDirectory

    private(set) var state: LoadState = .loading
    private(set) var settings: Settings = .defaults
    private(set) var operators: [Operator] = []
    private(set) var operatorsById: [String: Operator] = [:]
    private(set) var trainTypes: [TrainType] = []
    private(set) var amenities: [AmenityEntry] = []

    /// The full leg for a trip, fetched once per leg for the session (the featured card's stops and route).
    @ObservationIgnored var legDetails: [String: LegDetail] = [:]

    /// The landing rule has run for this launch (it runs once).
    var hasLanded = false

    /// The server couldn't be reached on the last request: the offline strip shows.
    var isOffline: Bool { connection.isOffline }

    init(identity: String = Identity.current(), l10n: L10n = L10n()) {
        let connection = ConnectionState()
        let cache = OfflineCache()
        let client = APIClient(userID: identity, cache: cache) { reachable in
            Task { @MainActor in connection.report(reachable: reachable) }
        }
        self.identity = identity
        self.l10n = l10n
        self.connection = connection
        self.offlineCache = cache
        self.client = client
        self.live = LiveHub(client: client)
        self.stations = StationDirectory(client: client)
    }

    /// The colour scheme the `theme` setting asks for: `system` follows the phone, the default is dark.
    var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark, .unknown: .dark
        }
    }

    /// How this person walks through a station: pace, step-free routes only, heavy luggage.
    var walkProfile: WalkProfile {
        WalkProfile(pace: settings.walkPace, stepFree: settings.stepFree, luggage: settings.heavyLuggage)
    }

    /// Loads the four reference documents at once. The language setting switches the texts as soon as it arrives.
    func load() async {
        state = .loading
        do {
            async let settings = client.settings()
            async let operators = client.operators()
            async let trainTypes = client.trainTypes()
            async let amenities = client.amenities()
            let loaded = try await (settings, operators, trainTypes, amenities)
            self.settings = loaded.0
            self.operators = loaded.1
            self.operatorsById = Dictionary(loaded.1.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.trainTypes = loaded.2
            self.amenities = loaded.3
            l10n.language = loaded.0.language
            state = .ready
        } catch {
            state = .failed
        }
    }
}
