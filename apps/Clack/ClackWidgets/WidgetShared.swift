//
//  WidgetShared.swift
//  ClackWidgets
//
//  What the widget extension adds to the shared widget views (ClackDesign/Widgets): the WidgetKit family as a
//  `WidgetSize`, and the one inset rule applied to every Home Screen widget. The views themselves, the words, the
//  placeholder and the small shared pieces are in ClackDesign, so the app's debug gallery draws the same thing.
//

import ClackCore
import ClackDesign
import SwiftUI
import WidgetKit

extension WidgetFamily {
    /// The Home Screen size, nil for the Lock Screen families.
    var homeSize: WidgetSize? {
        switch self {
        case .systemSmall: .small
        case .systemMedium: .medium
        case .systemLarge, .systemExtraLarge: .large
        default: nil
        }
    }
}

/// The inset rule (`WidgetInsets`): every Home Screen widget turns the system margins off
/// (`.contentMarginsDisabled()` on its configuration) and is padded by this instead; the Lock Screen families keep the
/// system's margins.
private struct WidgetPadding: ViewModifier {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var system

    func body(content: Content) -> some View {
        if let size = family.homeSize {
            content.padding(WidgetInsets.resolved(size, system: system))
        } else {
            content.padding(system)
        }
    }
}

extension View {
    func widgetPadding() -> some View { modifier(WidgetPadding()) }
}
