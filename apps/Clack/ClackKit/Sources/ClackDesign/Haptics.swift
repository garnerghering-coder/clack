//
//  Haptics.swift
//  ClackDesign
//

import SwiftUI

/// The app's haptic vocabulary (polish pass 1, DECISIONS H1), Apple's meanings, each used for one thing only. Nothing
/// plays for scrolling, navigation or ordinary buttons.
public enum Haptic: Sendable {
    /// A value changing under the finger (date chips, year chips). Not where a system control already plays one.
    case selection
    /// Something snapping into place: a sheet reaching a detent, a split-flap landing.
    case snap
    /// A trip added, a medal or stamp earned, a follow confirmed.
    case success
    /// A trip on screen becomes cancelled.
    case warning
    /// An action failed.
    case error

    public var feedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .snap: .impact(weight: .light)
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }
}

extension View {
    /// Plays `haptic` when `trigger` changes. Trigger on the user's action or a real event, never on loaded state.
    public func haptic<T: Equatable>(_ haptic: Haptic, trigger: T) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }

    /// Plays `haptic` when `trigger` changes and `condition(old, new)` holds (say, only when false turns true).
    public func haptic<T: Equatable>(_ haptic: Haptic, trigger: T, condition: @escaping (T, T) -> Bool) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger, condition: condition)
    }
}
