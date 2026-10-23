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

    private(set) var state: LoadState = .loading
    private(set) var settings: Settings = .defaults
    private(set) var operators: [Operator] = []
    private(set) var trainTypes: [TrainType] = []
    private(set) var amenities: [AmenityEntry] = []

    /// The server couldn't be reached on the last request: the offline banner shows.
    private(set) var isOffline = false
    /// The landing rule has run for this launch (it runs once).
    var hasLanded = false

    init(identity: String = Identity.current(), l10n: L10n = L10n()) {
        self.identity = identity
        self.client = APIClient(userID: identity)
        self.l10n = l10n
    }

    /// The colour scheme the `theme` setting asks for: `system` follows the phone, the default is dark.
    var colorScheme: ColorScheme? {
        switch settings.theme {
        case .system: nil
        case .light: .light
        case .dark, .unknown: .dark
        }
    }

    /// Loads the four reference documents at once. The language setting switches the texts as soon as it arrives.
    func load() async {
        state = .loading
        do {
            async let settings: Settings = client.get(["settings"])
            async let operators: [Operator] = client.get(["operators"])
            async let trainTypes: [TrainType] = client.get(["train-types"])
            async let amenities: [AmenityEntry] = client.get(["amenities"])
            let loaded = try await (settings, operators, trainTypes, amenities)
            self.settings = loaded.0
            self.operators = loaded.1
            self.trainTypes = loaded.2
            self.amenities = loaded.3
            l10n.language = loaded.0.language
            isOffline = false
            state = .ready
        } catch {
            noteFailure(error)
            state = .failed
        }
    }

    /// A request worked: the server is reachable.
    func noteSuccess() {
        isOffline = false
    }

    /// A request failed. A network failure or a timeout means offline; an answer from the server (an error status)
    /// means the server is there.
    func noteFailure(_ error: Error) {
        if error is APIError { return }
        isOffline = true
    }
}
