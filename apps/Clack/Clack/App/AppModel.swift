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

    private(set) var identity: String
    private(set) var client: APIClient
    let l10n: L10n
    let connection: ConnectionState
    let offlineCache: OfflineCache
    @ObservationIgnored private(set) var live: LiveHub
    @ObservationIgnored private(set) var stations: StationDirectory

    /// The last change to settings couldn't be saved.
    private(set) var saveFailed = false

    private(set) var state: LoadState = .loading
    private(set) var settings: Settings = .defaults
    private(set) var operators: [Operator] = []
    private(set) var operatorsById: [String: Operator] = [:]
    private(set) var trainTypes: [TrainType] = []
    private(set) var amenities: [AmenityEntry] = []

    /// The full leg for a trip, fetched once per leg for the session (the featured card's stops and route).
    @ObservationIgnored var legDetails: [String: LegDetail] = [:]

    /// Whether the server has a basemap to draw (`GET /api/map/status`), asked once per session. Without one the maps
    /// show just their background, with the routes on it.
    @ObservationIgnored private var basemapTask: Task<Bool, Never>?

    func mapHasBasemap() async -> Bool {
        if let basemapTask { return await basemapTask.value }
        let client = client
        let task = Task<Bool, Never> { ((try? await client.get(["map", "status"])) as MapStatus?)?.basemap != nil }
        basemapTask = task
        return await task.value
    }

    /// The operators' logos have been fetched (or the attempt gave up): badges can show them from the first frame.
    private(set) var logosSettled = false

    /// Fetches every operator's logo into the logo store, so badges show them at once instead of after a download.
    func prefetchLogos() async {
        let base = Config.apiBase.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let urls = operators.compactMap { $0.logoUrl }.compactMap { URL(string: base + $0) }
        await LogoStore.shared.prefetch(urls)
        logosSettled = true
    }

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
        // The theme paints before the server answers: the last one is kept on the phone (SPEC: no flash).
        if let raw = UserDefaults.standard.string(forKey: Self.themeKey) { settings.theme = ThemeSetting.knownCases.first { $0.rawValue == raw } ?? .dark }
    }

    private static let themeKey = "clack.theme"

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
            UserDefaults.standard.set(loaded.0.theme.rawValue, forKey: Self.themeKey)
            self.operators = loaded.1
            self.operatorsById = Dictionary(loaded.1.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            self.trainTypes = loaded.2
            self.amenities = loaded.3
            l10n.language = loaded.0.language
            state = .ready
            Task { await prefetchLogos() }
        } catch {
            state = .failed
        }
    }

    /// Changes settings: shown at once, then saved; if saving fails the change is undone and the error is shown.
    func update(_ patch: SettingsPatch) async {
        guard let optimistic = settings.applying(patch) else { return }
        let previous = settings
        settings = optimistic
        l10n.language = optimistic.language
        saveFailed = false
        do {
            let saved = try await client.updateSettings(patch)
            settings = saved
            l10n.language = saved.language
            UserDefaults.standard.set(saved.theme.rawValue, forKey: Self.themeKey)
        } catch {
            settings = previous
            l10n.language = previous.language
            saveFailed = true
        }
    }

    /// App Review 5.1.1(v): whatever the server keeps for this phone, and the copies on it, are deleted at once. The
    /// phone then starts over with a new id, as on a fresh install. Returns whether the server confirmed.
    func deleteMyData() async -> Bool {
        do {
            try await client.deleteMyData()
        } catch {
            return false
        }
        await offlineCache.clear()
        for key in UserDefaults.standard.dictionaryRepresentation().keys where key.hasPrefix("clack.") {
            UserDefaults.standard.removeObject(forKey: key)
        }
        Identity.delete()
        let fresh = Identity.current()
        let cache = offlineCache
        let connection = connection
        identity = fresh
        client = APIClient(userID: fresh, cache: cache) { reachable in
            Task { @MainActor in connection.report(reachable: reachable) }
        }
        live = LiveHub(client: client)
        stations = StationDirectory(client: client)
        legDetails = [:]
        settings = .defaults
        l10n.language = .en
        await load()
        return true
    }
}

/// `GET /api/map/status`: the basemap's details when it has been downloaded, else null.
nonisolated struct MapStatus: Decodable, Sendable {
    nonisolated struct Basemap: Decodable, Sendable {}
    let basemap: Basemap?
}