//
//  TripLiveActivity.swift
//  ClackWidgets
//

import ActivityKit
import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

/// The trip you are on, on the Lock Screen, in the Dynamic Island, in StandBy, and (iOS 18+) in the Apple Watch Smart
/// Stack and CarPlay (owner, 2026-10-24). The faces themselves are in ClackDesign (`TripCard.swift`), so the app's Debug
/// gallery can draw them in the island's real shapes; this file only puts them in their places, with the island's
/// margins. Tapping opens the leg in the app. Words come from the shared locale files, in the app's language
/// (`SharedSettings`).

/// The texts and settings for the card, read once per render from the App Group.
@MainActor
private enum CardText {
    static let l10n = L10n(language: SharedSettings.language())

    static func card(_ attributes: TripActivityAttributes, _ state: TripActivityAttributes.ContentState) -> TripCardFace {
        let language = SharedSettings.language()
        if l10n.language != language { l10n.language = language }
        let start = TripCardStart(
            legId: attributes.legId, train: attributes.train, from: attributes.from, to: attributes.to,
            fromTz: attributes.fromTz, toTz: attributes.toTz, color: attributes.color
        )
        return TripCardFace(start: start, state: state, l10n: l10n, clock: SharedSettings.clock())
    }
}

/// Picks the layout for where the card is shown (iOS 18+).
@available(iOS 18.0, *)
private struct FamilyCard: View {
    @Environment(\.activityFamily) private var family
    let card: TripCardFace
    let stale: Bool

    var body: some View {
        switch family {
        case .small: TripCardSmall(card: card, stale: stale)
        default: TripCardLockScreen(card: card, stale: stale)
        }
    }
}

/// The Lock Screen, StandBy and (iOS 18+) the small presentations.
private struct Presentation: View {
    let card: TripCardFace
    let stale: Bool

    var body: some View {
        if #available(iOS 18.0, *) { FamilyCard(card: card, stale: stale) } else { TripCardLockScreen(card: card, stale: stale) }
    }
}

/// Whether the island is narrow now (iOS 27+: iPhone in landscape, or two activities sharing it on the newest phones).
@available(iOS 27.0, *)
private struct LimitedReader<Content: View>: View {
    @Environment(\.isDynamicIslandLimitedInWidth) private var limited
    @ViewBuilder let content: (Bool) -> Content
    var body: some View { content(limited) }
}

private struct CompactLeading: View {
    let card: TripCardFace
    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedReader { TripIslandCompactLeading(card: card, limited: $0) }
        } else {
            TripIslandCompactLeading(card: card)
        }
    }
}

private struct CompactTrailing: View {
    let card: TripCardFace
    var body: some View {
        if #available(iOS 27.0, *) {
            LimitedReader { TripIslandCompactTrailing(card: card, limited: $0) }
        } else {
            TripIslandCompactTrailing(card: card)
        }
    }
}

// MARK: the widget

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        // Apple Watch Smart Stack and CarPlay get the small layout, StandBy the medium one (iOS 18+).
        if #available(iOS 18.0, *) {
            return configuration.supplementalActivityFamilies([.small, .medium])
        } else {
            return configuration
        }
    }

    private var configuration: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            let card = CardText.card(context.attributes, context.state)
            Presentation(card: card, stale: context.isStale)
                .environment(card.l10n)
                .widgetURL(card.url)
                .activityBackgroundTint(Ink.bg)
                .activitySystemActionForegroundColor(Ink.accentInk)
        } dynamicIsland: { context in
            let card = CardText.card(context.attributes, context.state)
            // Small things beside the camera, the rest in a bottom block of two rows, inside the system's own margins
            // (custom ones, with three rows, made the island crop the top and bottom lines).
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) { TripIslandExpandedLeading(card: card) }
                DynamicIslandExpandedRegion(.trailing) { TripIslandExpandedTrailing(card: card) }
                DynamicIslandExpandedRegion(.bottom) { TripIslandExpandedBottom(card: card, stale: context.isStale).environment(card.l10n) }
            } compactLeading: {
                CompactLeading(card: card)
            } compactTrailing: {
                CompactTrailing(card: card)
            } minimal: {
                TripIslandMinimal(card: card)
            }
            .widgetURL(card.url)
            .keylineTint(card.line)
        }
    }
}
