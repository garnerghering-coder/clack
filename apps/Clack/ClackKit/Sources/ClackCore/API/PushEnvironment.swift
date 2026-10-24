//
//  PushEnvironment.swift
//  Clack
//

import Foundation

/// Which of Apple's push servers this build's tokens belong to: `sandbox` or `production`. A token sent to the wrong one
/// gets `BadDeviceToken`. The build configuration doesn't say (a Release build run from Xcode is still signed for
/// development), the signing does: the provisioning profile inside the app carries the `aps-environment` entitlement.
/// App Store and TestFlight builds have no profile inside, and are production.
public nonisolated enum PushEnvironment {
    public static let sandbox = "sandbox"
    public static let production = "production"

    /// The environment for an app with this `embedded.mobileprovision` (nil: no profile in the bundle).
    public static func resolve(profile: Data?) -> String {
        guard let profile else { return production }
        return apsEnvironment(inProfile: profile) == "production" ? production : sandbox
    }

    /// The `aps-environment` entitlement in a provisioning profile: `development`, `production`, or nil. The profile is
    /// a signed (CMS) envelope around a plain XML property list; this reads the list without checking the signature.
    public static func apsEnvironment(inProfile data: Data) -> String? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return nil }
        let xml = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: xml, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any] else { return nil }
        return entitlements["aps-environment"] as? String
    }
}
