//
//  Router.swift
//  Clack
//

import Observation

/// Which tab is showing. The last one is remembered for the next launch (`Landing.saveLastTab`).
@Observable
final class Router {
    var tab: PrimaryTab = .trips
}
