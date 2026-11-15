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
/// isn't answering) again and again while the phone has a connection mean server trouble. The rule is
/// `ConnectionTracker` (ClackCore, tested); this holds it for the views and wakes the waiting retries when the server
/// or the connection comes back.
@MainActor
@Observable
final class ConnectionState {
    typealias State = ConnectionTracker.State

    private var tracker = ConnectionTracker()

    private(set) var state: State = .online

    /// The server can't be reached, for either reason (the single flag the trip page, Explore and the widgets read).
    var isOffline: Bool { state != .online }

    /// The phone has a usable connection (NWPathMonitor's `satisfied`). Assumed until the monitor first says.
    var hasPath: Bool { tracker.hasPath }

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            Task { @MainActor in self?.pathChanged(satisfied: satisfied) }
        }
        monitor.start(queue: DispatchQueue(label: "clack.connection"))
    }

    /// A request's outcome. The server answering again after trouble wakes every retry still waiting, so an open
    /// screen recovers with the strip instead of sitting out its countdown.
    func report(_ reach: Reach) {
        let cameBack = tracker.report(reach)
        publish()
        if cameBack { RetryWake.shared.wake() }
    }

    /// The app came to the front: whatever was waiting to try again goes now.
    func becameActive() {
        if isOffline || RetryWake.shared.waiting > 0 { RetryWake.shared.wake() }
    }

    private func pathChanged(satisfied: Bool) {
        let cameBack = tracker.pathChanged(satisfied: satisfied)
        publish()
        if cameBack { RetryWake.shared.wake() }
    }

    private func publish() {
        if tracker.state != state { state = tracker.state }
    }
}
