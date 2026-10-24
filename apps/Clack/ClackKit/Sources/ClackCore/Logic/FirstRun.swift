//
//  FirstRun.swift
//  Clack
//

import Foundation

/// The first time Clack opens, and asking about alerts. The welcome over the empty Trips tab ends on a page asking for
/// alerts (owner, 2026-10-25, replacing "no prompts at first" from 2026-10-24); someone who had Clack before that page
/// existed sees it once by itself at launch. "Not now" leaves one card on an upcoming trip as the next chance. Each is
/// remembered on the phone (`UserDefaults`) so it is shown once.
public nonisolated enum FirstRun {
    public static let welcomeSeenKey = "clack.firstRun.welcomeSeen"
    public static let alertsAskedKey = "clack.firstRun.alertsAsked"
    public static let alertsIntroSeenKey = "clack.firstRun.alertsIntroSeen"

    /// The alerts page by itself, at launch: once, while alerts are off and iOS would still let them on (not asked
    /// yet, or allowed but Clack's switch never turned on), and not when the welcome (which ends on the same page) is
    /// about to show.
    public static func showsAlertsIntro(notDetermined: Bool, allowedButOff: Bool = false, introSeen: Bool, welcomeDue: Bool) -> Bool {
        (notDetermined || allowedButOff) && !introSeen && !welcomeDue
    }

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
