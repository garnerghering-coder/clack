//
//  FirstRun.swift
//  Clack
//

import Foundation

/// The first time Clack opens, and the one question about alerts (owner, 2026-10-24). No permission prompts at first:
/// a welcome over the empty Trips tab, then, once there's an upcoming trip, one card on it offering alerts. Each is
/// remembered on the phone (`UserDefaults`) so it is shown once.
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
