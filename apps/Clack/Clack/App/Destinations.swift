//
//  Destinations.swift
//  Clack
//

import SwiftUI
import UIKit

/// A screen that is built in a later step: its header and nothing else.
struct ComingSoonScreen: View {
    let title: String

    var body: some View {
        Page {
            BackLink()
            PageHeader(title: title)
        }
    }
}

extension View {
    /// Where each route leads. Applied to the root of every tab's stack.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            DestinationView(route: route)
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DestinationView: View {
    @Environment(L10n.self) private var l10n
    let route: AppRoute

    var body: some View {
        switch route {
        case .trip(let id): TripDetailScreen(id: id)
        case .journey(let id): JourneyScreen(id: id)
        case .settings: SettingsScreen()
        case .about: AboutScreen()
        case .privacy: PrivacyScreen()
        case .stations: StationsScreen()
        case .board(let id, let arrivals): BoardScreen(stationId: id, arrivals: arrivals)
        case .stationMap: ComingSoonScreen(title: l10n.t("nav.stations"))
        }
    }
}

/// With the navigation bar hidden (the screens draw their own headers), keep the edge-swipe that goes back.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}
