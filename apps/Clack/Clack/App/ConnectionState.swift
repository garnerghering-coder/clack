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
/// `ConnectionTracker` (ClackCore, tested); this holds it for the views, wakes the waiting retries when the server
/// or the connection comes back, and tells the network when the app leaves the screen and comes back (`AppPresence`).
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

    /// The interface the phone last used (Wi-Fi, mobile), to tell a switch from a mere update.
    private var interface: NWInterface.InterfaceType?

    /// Away longer than this, the connections held before are taken for dead: the next requests go on new ones.
    static let staleAfter: TimeInterval = 30

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = path.status == .satisfied
            let interface = path.availableInterfaces.first?.type
            Task { @MainActor in self?.pathChanged(satisfied: satisfied, interface: interface) }
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

    /// The app left the screen: the streams close, the polls wait (`AppPresence`).
    func wentAway() {
        AppPresence.shared.left()
        NetworkLog.shared.note("app left the screen")
    }

    /// The app came to the front: the streams and polls go again, and whatever was waiting to try again goes now.
    /// After a while away the old connections are left behind first, so nothing waits 15 s on one that died while the app
    /// was frozen, and the failures from before count for nothing.
    func becameActive() {
        let away = AppPresence.shared.returned()
        if let away {
            NetworkLog.shared.note("app back after \(Int(away)) s")
            if away > Self.staleAfter {
                freshConnections()
                tracker.forget()
                publish()
            }
        }
        if isOffline || RetryWake.shared.waiting > 0 { RetryWake.shared.wake() }
    }

    private func pathChanged(satisfied: Bool, interface: NWInterface.InterfaceType?) {
        let switched = satisfied && self.interface != nil && interface != self.interface
        if satisfied { self.interface = interface }
        let cameBack = tracker.pathChanged(satisfied: satisfied)
        publish()
        if switched || cameBack {
            NetworkLog.shared.note(switched ? "network switched to \(interface.map { "\($0)" } ?? "?")" : "connection back")
            // A switch (Wi-Fi to mobile) strands the connections on the old one: new ones, then everyone tries again.
            freshConnections()
            RetryWake.shared.wake()
        }
    }

    /// The next requests and streams go on new sessions, so on new connections (`Connections`).
    private func freshConnections() {
        Connections.shared.renew()
        NetworkLog.shared.note("new connections from here on")
    }

    private func publish() {
        if tracker.state != state { state = tracker.state }
    }
}
