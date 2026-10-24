//
//  Notifications.swift
//  Clack
//

import ClackCore
import ClackDesign
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
    /// Apple's address for this phone, once it has given one in this launch.
    private(set) var token: String?
    /// The Live Activity push-to-start address (iOS 17.2+), if any. Kept between launches: iOS hands it over only when it
    /// changes, so the first sync of a launch sends the one from before.
    private(set) var startToken: String? = UserDefaults.standard.string(forKey: NotificationManager.startTokenKey)
    /// The phone's address from this launch or the last one, to tie trip cards to this phone (a launch in the
    /// background, for a card the server started, may come before Apple hands it over again).
    var deviceToken: String? { token ?? UserDefaults.standard.string(forKey: Self.tokenKey) }

    private static let startTokenKey = "clack.liveActivityStartToken"
    private static let tokenKey = "clack.pushToken"
    /// Where a tapped alert leads, for the root view to open (it may be set before the root view is up, on a cold start).
    var openRequest: DeepLink?

    /// Which of Apple's push servers this build's tokens belong to, read from how the app is signed: the provisioning
    /// profile in the bundle says (a Release build run from Xcode is still development); no profile means App Store or
    /// TestFlight, production. The simulator uses the sandbox.
    nonisolated static let environment: String = {
        #if targetEnvironment(simulator)
        PushEnvironment.sandbox
        #else
        PushEnvironment.resolve(profile: Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision").flatMap { try? Data(contentsOf: $0) })
        #endif
    }()

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
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        await refresh()
        return granted
    }

    func didRegister(_ data: Data) {
        let hex = hexToken(data)
        token = hex
        UserDefaults.standard.set(hex, forKey: Self.tokenKey)
    }

    func setStartToken(_ data: Data) {
        let hex = hexToken(data)
        startToken = hex
        UserDefaults.standard.set(hex, forKey: Self.startTokenKey)
    }

    private var uploaded: String?

    /// Tells the server this phone's address (when alerts are on and Apple has given one, in this launch or the last:
    /// a launch in the background may come before Apple hands it over again), once per change. The push-to-start
    /// address and the widgets' push address (`WidgetPush`, written by the widget extension) go with it only when known:
    /// left out, the server keeps the one it has. Once registered, the extension may send a new widget address itself.
    func sync(_ client: APIClient, enabled: Bool) async {
        guard enabled, let token = deviceToken else { return }
        let widgetToken = WidgetPush.token()
        let key = "\(token)|\(startToken ?? "")|\(widgetToken ?? "")|\(client.userID)"
        guard uploaded != key else { return }
        do {
            try await client.registerDevice(DeviceRegistration(
                token: token, environment: Self.environment, startToken: TokenUpdate(startToken), widgetToken: TokenUpdate(widgetToken)
            ))
            uploaded = key
            WidgetPush.setRegistered(token: token, environment: Self.environment)
        } catch {
            uploaded = nil
        }
    }

    /// The server forgets this phone (alerts switched off, or the data deleted).
    func forget(_ client: APIClient) async {
        WidgetPush.clearRegistered()
        guard let token = deviceToken else { return }
        try? await client.forgetDevice(token)
        uploaded = nil
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// An alert that arrives while the app is open still shows, as a banner.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Tapping an alert opens the trip it is about (a change opens the whole journey, an arrival its celebration).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        guard let legId = info["legId"] as? String else { return }
        let request = DeepLink.forAlert(legId: legId, journeyId: info["journeyId"] as? String, kind: info["kind"] as? String ?? "")
        await MainActor.run { NotificationManager.shared.openRequest = request }
    }
}

/// Receives what Apple sends back about this phone: the address alerts go to, and the server's silent pushes.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        BackgroundRefresh.register()
        return true
    }

    /// A silent push (`content-available`): a trip changed, so the app refreshes what the widgets and the trip card
    /// show, within the 30 seconds iOS gives it.
    func application(
        _ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let push = BackgroundRefresh.Push(userInfo) else { return completionHandler(.noData) }
        Task {
            completionHandler(await BackgroundRefresh.shared.handle(push))
        }
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in NotificationManager.shared.didRegister(deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NSLog("Clack: could not register for alerts: %@", error.localizedDescription)
    }
}
