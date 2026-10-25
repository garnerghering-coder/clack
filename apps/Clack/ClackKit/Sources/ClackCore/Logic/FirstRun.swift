//
//  FirstRun.swift
//  Clack
//

import Foundation

/// The first time Clack opens, and asking about alerts. The welcome over the empty Trips tab offers real trains leaving
/// soon and no permission prompts (owner, 2026-10-25: ask in context, with Apple's prompts); alerts are offered on a trip
/// still ahead, once. Each is remembered on the phone (`UserDefaults`) so it is shown once.
public nonisolated enum FirstRun {
    public static let welcomeSeenKey = "clack.firstRun.welcomeSeen"
    public static let alertsAskedKey = "clack.firstRun.alertsAsked"
    /// The welcome shows over Trips the first time only, and only when there are no trips (someone coming back to a
    /// new phone with their trips already saved doesn't need it). `legs` is nil until the list has loaded.
    public static func showsWelcome(seen: Bool, legs: Int?) -> Bool {
        guard !seen, let legs else { return false }
        return legs == 0
    }

    /// While the welcome is due, the app opens on Trips (where it is) rather than where the landing rule would send a
    /// new phone (Explore). Someone with trips lands as before.
    public static func holdsLanding(seen: Bool, legs: Int) -> Bool { !seen && legs == 0 }

    /// "Get alerts for this train?" on a trip that is still ahead, once: not when alerts are already on, not when iOS
    /// has said no (Settings explains that), and not again after it was answered or closed.
    public static func showsAlertsPrompt(stageBefore: Bool, canceled: Bool, alertsOn: Bool, denied: Bool, asked: Bool) -> Bool {
        stageBefore && !canceled && !alertsOn && !denied && !asked
    }
}
