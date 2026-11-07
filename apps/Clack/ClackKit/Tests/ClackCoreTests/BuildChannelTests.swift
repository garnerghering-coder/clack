//
//  BuildChannelTests.swift
//  ClackTests
//

import Testing
@testable import ClackCore

/// Who sees the test tools: Xcode and TestFlight builds, never App Store ones (owner, 2026-11-07).
struct BuildChannelTests {
    private func decide(
        _ override: String? = nil, debug: Bool = false, receipt: String? = nil,
        env environment: BuildChannel.StoreEnvironment = .unknown
    ) -> BuildChannel {
        BuildChannel.decide(override: override, isDebug: debug, receiptName: receipt, environment: environment)
    }

    @Test func aDebugBuildIsXcodes() {
        #expect(decide(debug: true) == .xcode)
        #expect(decide(debug: true, receipt: "receipt", env: .production) == .xcode)
    }

    @Test func testFlightIsKnownByItsSandboxReceiptOrItsTransaction() {
        #expect(decide(receipt: "sandboxReceipt") == .testFlight)
        // The receipt alone missed TestFlight once (2026-10-28); the transaction's environment catches it too.
        #expect(decide(receipt: nil, env: .sandbox) == .testFlight)
        #expect(decide(receipt: "receipt", env: .sandbox) == .testFlight)
    }

    @Test func storeKitsXcodeEnvironmentIsXcodes() {
        #expect(decide(env: .xcode) == .xcode)
    }

    @Test func anAppStoreCopyOrNoAnswerShowsNoTools() {
        #expect(decide(receipt: "receipt", env: .production) == .appStore)
        // No receipt and no transaction (StoreKit failed): the safe side.
        #expect(decide() == .appStore)
        #expect(!BuildChannel.appStore.showsTestTools)
        #expect(BuildChannel.testFlight.showsTestTools)
        #expect(BuildChannel.xcode.showsTestTools)
    }

    @Test func theLaunchArgumentWins() {
        #expect(decide("appstore", debug: true) == .appStore)
        #expect(decide("testflight", env: .production) == .testFlight)
        #expect(decide("TestFlight") == .testFlight)
        #expect(decide("xcode") == .xcode)
        // An unknown value is ignored.
        #expect(decide("nonsense", debug: true) == .xcode)
        #expect(BuildChannel.launchOverride(["Clack", "-buildChannel", "appstore"]) == "appstore")
        #expect(BuildChannel.launchOverride(["Clack", "-buildChannel"]) == nil)
        #expect(BuildChannel.launchOverride(["Clack"]) == nil)
    }
}
