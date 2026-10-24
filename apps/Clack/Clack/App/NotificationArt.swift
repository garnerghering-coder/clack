//
//  NotificationArt.swift
//  Clack
//

import ClackCore
import UserNotifications

/// How an alert sounds: SBB's jingle, bundled with the app (Resources/Sounds). The server's alerts name the same file.
enum NotificationArt {
    static let sound = UNNotificationSound(named: UNNotificationSoundName("sbb_jingle.wav"))
}
