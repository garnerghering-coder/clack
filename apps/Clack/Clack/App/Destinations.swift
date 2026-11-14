//
//  Destinations.swift
//  Clack
//

import ClackCore
import ClackDesign
import SwiftUI
import UIKit

extension View {
    /// Where each route leads. Applied to the root of every tab's stack.
    func appDestinations() -> some View {
        navigationDestination(for: AppRoute.self) { route in
            DestinationView(route: route)
        }
    }
}

private struct DestinationView: View {
    @Environment(L10n.self) private var l10n
    let route: AppRoute

    var body: some View {
        switch route {
        case .trip(let id): TripDetailScreen(id: id).modifier(ZoomDestination(id: "trip-\(id)"))
        case .journey(let id): JourneyScreen(id: id).modifier(ZoomDestination(id: "journey-\(id)"))
        case .following(let token): FollowingScreen(token: token)
        case .settings: SettingsScreen()
        case .about: AboutScreen()
        case .privacy: PrivacyScreen()
        case .stations: StationsRedirect()
        case .board(let id, let arrivals): BoardScreen(stationId: id, arrivals: arrivals)
        case .stationMap(let link): StationMapScreen(link: link)
        case .passportBreakdown: PassportBreakdownScreen()
        case .passportMilestones: MilestonesScreen()
        case .walkLogger: WalkLoggerScreen()
        case .testAlerts: TestAlertsScreen()
        }
    }
}

/// `.stations` from an old link: Explore's station search instead (the Stations screen moved there).
private struct StationsRedirect: View {
    @Environment(Router.self) private var router

    var body: some View {
        Color.clear.onAppear {
            // Take this placeholder off the stack it was pushed on, then show the search.
            for tab in PrimaryTab.allCases { router.setPath(router.path(for: tab).filter { $0 != .stations }, for: tab) }
            router.openStationSearch()
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

// MARK: zoom from a card (polish pass 1)

extension EnvironmentValues {
    /// The namespace a tab's stack shares between its cards and the screens they open, for the zoom transition.
    @Entry var zoomNamespace: Namespace.ID?
}

/// A trip or journey card: the place its screen zooms out of, and back into (iOS 18 and later; a push before).
struct ZoomSource: ViewModifier {
    let id: String
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.matchedTransitionSource(id: id, in: namespace) { $0.clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous)) }
        } else {
            content
        }
    }
}

/// A trip's or journey's screen: zooms out of the card that opened it (iOS 18 and later). Opened from anywhere else
/// (a link, the Passport), there is no card with its id and it arrives as a push.
struct ZoomDestination: ViewModifier {
    let id: String
    @Environment(\.zoomNamespace) private var namespace

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}
