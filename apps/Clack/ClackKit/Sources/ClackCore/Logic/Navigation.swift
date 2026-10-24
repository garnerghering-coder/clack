//
//  Navigation.swift
//  Clack
//

import Foundation

/// Where taps lead inside the app (owner, 2026-10-24: trains open in place, stations live in Explore). The app's
/// `Router` follows these; they are here so they can be tested.
public nonisolated enum Navigation {
    /// How a train opened from inside the app (a board row, a followed train, a disruption's "Live") is shown.
    public enum TrainOpening: Equatable, Sendable {
        /// On Explore: the map moves to it and its sheet opens, as before.
        case focusOnMap
        /// Anywhere else: its sheet slides up over the screen you're on, and closing it leaves you there.
        case sheet
    }

    public static func trainOpening(tab: PrimaryTab) -> TrainOpening {
        tab == .explore ? .focusOnMap : .sheet
    }

    /// The kinds of screen a tab's stack can hold, for naming the back button after the one underneath.
    public enum Screen: Equatable, Sendable {
        case trip, journey, settings, about, privacy, board, stationMap, other
    }

    /// The back button's words: the screen it goes back to, or the tab's own name when it goes back to the tab's first
    /// screen. A screen without a short name says "Back".
    public static func backLabelKey(below: Screen?, tab: PrimaryTab) -> String {
        guard let below else {
            switch tab {
            case .trips: return "nav.trips"
            case .explore: return "nav.explore"
            case .passport: return "nav.passport"
            }
        }
        switch below {
        case .trip: return "nav.trip"
        case .journey: return "nav.journey"
        case .settings: return "settings.title"
        case .about: return "about.title"
        case .board: return "board.departures"
        case .privacy, .stationMap, .other: return "common.back"
        }
    }

    /// The screen underneath the top one of a stack (`path` is the stack above the tab's first screen, bottom first):
    /// nil when the top one sits right on the tab's first screen.
    public static func below<T>(_ path: [T]) -> T? {
        path.count >= 2 ? path[path.count - 2] : nil
    }
}
