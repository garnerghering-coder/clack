//
//  WidgetPush.swift
//  Clack
//
//  WidgetKit's push address for this phone's widgets (iOS 26+, docs/swift-port/API.md 2.13 "Widget push"). The widget
//  extension is handed it (`WidgetPushHandler.pushTokenDidChange`); the server wants it as `widgetToken` in
//  `PUT /api/devices`, next to the phone's own address, which only the app has. So both are kept in the App Group's
//  defaults: the extension writes its token there and sends it itself when the app has registered this phone; the app
//  sends it with every registration of its own.
//

import Foundation

public nonisolated enum WidgetPush {
    static let tokenKey = "clack.widgetPushToken"
    static let deviceKey = "clack.registeredDevice"
    static let environmentKey = "clack.registeredDeviceEnvironment"

    /// The widgets' push address (hex), once WidgetKit has given one.
    public static func token(_ defaults: UserDefaults? = SharedSettings.defaults) -> String? {
        defaults?.string(forKey: tokenKey)
    }

    public static func setToken(_ hex: String, defaults: UserDefaults? = SharedSettings.defaults) {
        defaults?.set(hex, forKey: tokenKey)
    }

    /// The app registered this phone with the server (alerts are on): its address and push environment. The extension
    /// sends its token only then, so it never brings back a phone whose alerts were switched off.
    public static func setRegistered(token: String, environment: String, defaults: UserDefaults? = SharedSettings.defaults) {
        defaults?.set(token, forKey: deviceKey)
        defaults?.set(environment, forKey: environmentKey)
    }

    /// The server forgot this phone (alerts switched off, or the data deleted).
    public static func clearRegistered(_ defaults: UserDefaults? = SharedSettings.defaults) {
        defaults?.removeObject(forKey: deviceKey)
        defaults?.removeObject(forKey: environmentKey)
    }

    /// What the extension sends when its token changes: the phone the app registered, with the widgets' address; nil
    /// when the app hasn't registered this phone.
    public static func registration(widgetToken: String, defaults: UserDefaults? = SharedSettings.defaults) -> DeviceRegistration? {
        guard let token = defaults?.string(forKey: deviceKey), let environment = defaults?.string(forKey: environmentKey) else { return nil }
        return DeviceRegistration(token: token, environment: environment, widgetToken: .set(widgetToken))
    }
}
