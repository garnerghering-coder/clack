//
//  BuildChannel.swift
//  Clack
//

import Foundation

/// Where this copy of the app came from, which decides who sees the test tools in Settings (station walks, wallet
/// passes, test alerts, the design gallery): Xcode and TestFlight builds do, App Store builds never do (owner,
/// 2026-11-07; App Review 2.1). One answer for every tool: before, some tools were compiled into debug builds only
/// (`#if DEBUG`), so TestFlight, being a release build, never had them.
/// The app asks StoreKit and remembers the answer (`BuildChannel.current()` in the app target).
public nonisolated enum BuildChannel: String, Sendable, CaseIterable {
    case xcode
    case testFlight
    case appStore

    /// Whether the test tools show.
    public var showsTestTools: Bool { self != .appStore }

    /// What StoreKit says about the install, reduced to what the decision needs.
    public enum StoreEnvironment: Sendable { case production, sandbox, xcode, unknown }

    /// The decision, kept apart from StoreKit so it can be tested. A launch argument (`-buildChannel appstore`,
    /// `testflight` or `xcode`) wins, to look at either case in the simulator; it can't be set on an installed copy.
    /// Then: a debug build is Xcode's; a sandbox receipt or a sandbox transaction is TestFlight's; StoreKit's Xcode
    /// environment is Xcode's; anything else, including no answer at all, is the App Store's (the safe side: no tools).
    public static func decide(
        override: String?, isDebug: Bool, receiptName: String?, environment: StoreEnvironment
    ) -> BuildChannel {
        if let override, let forced = parse(override) { return forced }
        if isDebug { return .xcode }
        if receiptName == "sandboxReceipt" { return .testFlight }
        switch environment {
        case .sandbox: return .testFlight
        case .xcode: return .xcode
        case .production, .unknown: return .appStore
        }
    }

    static func parse(_ raw: String) -> BuildChannel? {
        switch raw.lowercased() {
        case "appstore", "app-store": .appStore
        case "testflight": .testFlight
        case "xcode", "debug": .xcode
        default: nil
        }
    }

    /// The launch argument's value, if any (`-buildChannel appstore`).
    public static func launchOverride(_ args: [String] = ProcessInfo.processInfo.arguments) -> String? {
        args.firstIndex(of: "-buildChannel").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
    }
}
