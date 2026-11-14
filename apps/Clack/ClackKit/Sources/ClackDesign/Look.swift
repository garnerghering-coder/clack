//
//  Look.swift
//  ClackDesign
//

import ClackCore
import SwiftUI

/// The look choices of polish pass 1 (Polish/DECISIONS.md), one switch each, so any of them can be put back by
/// changing one line here. Each case names the old behaviour (`.yellow`, `.glass`, …) beside the new one.
public enum Look {
    /// What a chosen chip or segment is filled with (DECISIONS L1). Owner, 2026-11-14: one yellow thing per screen, the
    /// primary action; a selection is ink (the text colour, with the background colour on it). `.yellow` was the look
    /// before (DESIGN §2.1).
    public static let selection: SelectionFill = .ink

    /// What a button in the content (cards, rows, sheets) is drawn with (DECISIONS L2). Owner, 2026-11-14: Liquid Glass
    /// belongs to the navigation and control layer (bars, floating controls over a map); in content a button is a
    /// solid fill. `.glass` was the look before (DESIGN §2.3). Floating controls keep glass either way.
    public static let contentButtons: ContentButtons = .solid

    /// The tint of an on/off switch (DECISIONS L3). `.system` is the system's green; `.yellow` was the look before.
    public static let toggles: ToggleTint = .system

    /// The platform on a trip's time block (DECISIONS L4): `.tag` is the grey platform tag of the stop list,
    /// `.yellow` the solid yellow tag before.
    public static let timeBlockPlatform: PlatformLook = .tag

    /// A sheet's background and corners (DECISIONS L5): `.system` leaves them to iOS (Liquid Glass belongs to the
    /// control layer, polish brief: "remove custom backgrounds on bars and sheets"); `.surface` was the look before,
    /// the surface colour with 24 pt corners.
    public static let sheets: SheetLook = .system

    /// What Explore's train dots are coloured by on a new phone (DECISIONS B73.1; Garner chooses from the A/B
    /// comparison in Polish/compare/). `.operatorBrand` was the look before; `.lateOnly` is the designer's (neutral, a
    /// colour only when late). Anyone can still choose in Explore's filters.
    public static let mapDots: ExploreLogic.ColorBy = .operatorBrand

    public enum SelectionFill: Sendable { case ink, yellow }
    public enum SheetLook: Sendable { case system, surface }
    public enum ContentButtons: Sendable { case solid, glass }
    public enum ToggleTint: Sendable { case system, yellow }
    public enum PlatformLook: Sendable { case tag, yellow }

    /// The fill of a chosen chip or segment.
    public static var selectionFill: Color { selection == .ink ? Ink.text : Ink.accent }
    /// The text on a chosen chip or segment.
    public static var onSelection: Color { selection == .ink ? Ink.bg : Ink.onAccent }
    /// The tint of a `Toggle`: the system's green, said explicitly (left alone, a switch took the app-wide accent ink).
    public static var toggleTint: Color { toggles == .yellow ? Ink.accent : .green }
}

extension View {
    /// A `Toggle`'s tint as `Look.toggles` says.
    public func clackToggleTint() -> some View {
        tint(Look.toggleTint)
    }
}
