//
//  WidgetPushHandler.swift
//  ClackWidgets
//
//  WidgetKit push (iOS 26+, docs/swift-port/API.md 2.13 "Widget push"): when a tracked trip changes, the server sends
//  `{"aps":{"content-changed":true}}` to the widgets' push address, and WidgetKit asks the providers for new timelines.
//  The push carries no data; the providers fetch (`WidgetData.load`). Here the extension is handed its push address and
//  gets it to the server: kept in the App Group for the app's own registrations, and sent at once with the phone's
//  address when the app has registered this phone (alerts on).
//

import ClackCore
import Foundation
import SwiftUI
import WidgetKit

@available(iOS 26.0, *)
struct ClackWidgetPushHandler: WidgetPushHandler {
    func pushTokenDidChange(_ pushInfo: WidgetPushInfo, widgets: [WidgetInfo]) {
        let hex = hexToken(pushInfo.token)
        WidgetPush.setToken(hex)
        guard let body = WidgetPush.registration(widgetToken: hex), let client = WidgetData.client() else { return }
        Task {
            do {
                try await client.registerDevice(body)
            } catch {
                // The app sends it with its next registration.
                NSLog("Clack widgets: could not send the push address: %@", error.localizedDescription)
            }
        }
    }
}

extension WidgetConfiguration {
    /// Reloads this widget when the server says a trip changed (iOS 26+; earlier, the timelines and the app's writes
    /// keep it fresh).
    @MainActor
    func freshnessPushHandler() -> some WidgetConfiguration {
        if #available(iOS 26.0, *) {
            return pushHandler(ClackWidgetPushHandler.self)
        } else {
            return self
        }
    }
}
