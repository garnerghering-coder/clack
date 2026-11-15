//
//  ConnectionState.swift
//  Clack
//

import ClackCore
import Foundation
import Network
import Observation

/// Whether Clack's server can be reached, and when it can't, why: the phone has no connection (`offline`), or it has
/// one and the server isn't answering (`serverTrouble`). The strip at the top says which. The phone's side comes from
/// NWPathMonitor; the server's from every request (`APIClient.reachability`): any answer from the server itself, even
/// an error, means online (apps/web/src/api.ts); failures to reach it (no answer in time, the proxy in front saying it
/// isn't answering) again and again while the phone has a connection mean server trouble.
@MainActor
@Observable
final class ConnectionState {
    enum State: Equatable {
        case online
        case offline
        case serverTrouble
    }

    private(set) var state: State = .online

    /// The server can't be reached, for either reason (the single flag the trip page, Explore and the widgets read).
    var isOffline: Bool { state != .online }

    /// The phone has a usable connection (NWPathMonitor's `satisfied`). Assumed until the monitor first says.
    private(set) var hasPath = true
    /// Failures in a row to reach the server, since its last answer.
    private var failures = 0
    /// The last failure was URLSession's "no connection" (it can know before the monitor does).
    private var lastFailedOffline = false
    /// Failures in a row, with a connection, before the strip blames the server: one lost answer is as often the
    /// network's hiccup as the server's. Until then the strip says no connection, as it always did.
    static let troubleAfter = 2

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in self?.pathChanged(satisfied: satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "clack.connection"))
    }

    /// A request's outcome.
    func report(_ reach: Reach) {
        switch reach {
        case .answered:
            failures = 0
            lastFailedOffline = false
        case .failed(let kind):
            failures += 1
            lastFailedOffline = kind == .offline
        }
        update()
    }

    /// The app came to the front: whatever was waiting to try again goes now.
    func becameActive() {
        if isOffline || RetryWake.shared.waiting > 0 { RetryWake.shared.wake() }
    }

    private func pathChanged(satisfied: Bool) {
        let cameBack = satisfied && !hasPath
        hasPath = satisfied
        // The failures were the old connection's; the retries this wakes will tell about the new one.
        if cameBack {
            failures = 0
            lastFailedOffline = false
        }
        update()
        if cameBack { RetryWake.shared.wake() }
    }

    private func update() {
        let next: State =
            if !hasPath { .offline }
            else if failures == 0 { .online }
            else if lastFailedOffline { .offline }
            // One lost answer: what the strip said before stays (no connection, the old single flag), until it repeats.
            else if failures < Self.troubleAfter { state == .serverTrouble ? .serverTrouble : .offline }
            else { .serverTrouble }
        if next != state { state = next }
    }
}
