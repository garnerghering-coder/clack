//
//  Notifications.swift
//  Clack
//

import ClackCore
import SwiftUI
import UIKit
import UserNotifications

/// Alerts on the phone (owner, 2026-10-23): asks for permission when the person turns them on, tells the server this
/// phone's push address, and opens the right trip when an alert is tapped. The alerts themselves are made by the
/// server (it watches the trains), so they arrive with the app closed.
@MainActor
@Observable
final class NotificationManager: NSObject {
    static let shared = NotificationManager()

    /// What iOS lets the app do: the person can turn alerts off in iPhone Settings at any time.
    private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// Apple's address for this phone, once it has given one.
    private(set) var token: String?
    /// The Live Activity push-to-start address (iOS 17.2+), if any.
    private(set) var startToken: String?
    /// A trip an alert pointed at, for the root view to open.
    var openRequest: OpenRequest?

    struct OpenRequest: Equatable {
        let legId: String
        let journeyId: String?
        let kind: String
    }

    /// Debug builds talk to Apple's sandbox, TestFlight and App Store builds to production.
    static var environment: String {
        #if DEBUG
        "sandbox"
        #else
        "production"
        #endif
    }

    var denied: Bool { authorization == .denied }

    func refresh() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if authorization == .authorized || authorization == .provisional || authorization == .ephemeral {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    /// Asks for permission (the first time) and, if allowed, registers with Apple. True when alerts can be sent.
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .timeSensitive])) ?? false
        await refresh()
        return granted
    }

    func didRegister(_ data: Data) {
        token = data.map { String(format: "%02x", $0) }.joined()
    }

    func setStartToken(_ data: Data) {
        startToken = data.map { String(format: "%02x", $0) }.joined()
    }

    private var uploaded: String?

    /// Tells the server this phone's address (when alerts are on and Apple has given one), once per change.
    func sync(_ client: APIClient, enabled: Bool) async {
        guard enabled, let token else { return }
        let key = "\(token)|\(startToken ?? "")|\(client.userID)"
        guard uploaded != key else { return }
        do {
            try await client.registerDevice(token: token, environment: Self.environment, startToken: startToken)
            uploaded = key
        } catch {
            uploaded = nil
        }
    }

    /// The server forgets this phone (alerts switched off, or the data deleted).
    func forget(_ client: APIClient) async {
        guard let token else { return }
        try? await client.forgetDevice(token)
        uploaded = nil
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// An alert that arrives while the app is open still shows, as a banner.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Tapping an alert opens the trip it is about (a change opens the whole journey).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let legId = info["legId"] as? String else { return }
        let request = OpenRequest(legId: legId, journeyId: info["journeyId"] as? String, kind: info["kind"] as? String ?? "")
        await MainActor.run { NotificationManager.shared.openRequest = request }
    }
}

/// Receives what Apple sends back about this phone: the address alerts go to.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in NotificationManager.shared.didRegister(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Clack: could not register for alerts: %@", error.localizedDescription)
    }
}
