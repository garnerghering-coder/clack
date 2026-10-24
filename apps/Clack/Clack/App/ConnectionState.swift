//
//  ConnectionState.swift
//  Clack
//

import ClackCore
import Observation

/// Whether the server could be reached on the last request (the offline strip at the top shows when it couldn't).
/// Any HTTP answer, even an error, means online; a network failure or the 15 s GET timeout means offline
/// (apps/web/src/api.ts).
@MainActor
@Observable
final class ConnectionState {
    private(set) var isOffline = false

    func report(reachable: Bool) {
        if isOffline == reachable { isOffline = !reachable }
    }
}
