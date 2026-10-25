//
//  NotificationArt.swift
//  Clack
//

import ClackCore
import UserNotifications

/// How an alert sounds: Clack's own chord, bundled with the app (Resources/Sounds). The server's alerts name the same file.
enum NotificationArt {
    static let sound = UNNotificationSound(named: UNNotificationSoundName("clack_arch_chord.wav"))
}
