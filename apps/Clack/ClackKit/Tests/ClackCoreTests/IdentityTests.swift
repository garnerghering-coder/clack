//
//  IdentityTests.swift
//  ClackCoreTests
//
//  The phone's id: kept in the shared iCloud Keychain item, moved there from the old local one, never replaced.
//

import Foundation
import Testing
@testable import ClackCore

/// A Keychain in memory. `refuseShared` acts like an unsigned build that can't use the access group.
private final class FakeKeychain: IdentityKeychain, @unchecked Sendable {
    private let lock = NSLock()
    private var shared: String?
    private var legacy: String?
    var refuseShared = false

    init(shared: String? = nil, legacy: String? = nil) {
        self.shared = shared
        self.legacy = legacy
    }

    var sharedValue: String? { lock.withLock { shared } }
    var legacyValue: String? { lock.withLock { legacy } }

    func readShared() -> String? { lock.withLock { shared } }
    func writeShared(_ id: String) -> Bool {
        lock.withLock {
            if refuseShared { return false }
            shared = id
            return true
        }
    }
    func readLegacy() -> String? { lock.withLock { legacy } }
    func writeLegacy(_ id: String) { lock.withLock { legacy = id } }
    func deleteLegacy() { lock.withLock { legacy = nil } }
    func deleteAll() { lock.withLock { shared = nil; legacy = nil } }
}

struct IdentityTests {
    @Test func aFirstLaunchMakesAnIdAndKeepsIt() {
        let keychain = FakeKeychain()
        let first = Identity.current(keychain: keychain)
        #expect(UUID(uuidString: first) != nil)
        #expect(keychain.sharedValue == first)
        #expect(Identity.current(keychain: keychain) == first)
    }

    @Test func anOldLocalIdMovesToTheSharedItemAndTheOldOneGoes() {
        let keychain = FakeKeychain(legacy: "11111111-2222-3333-4444-555555555555")
        #expect(Identity.current(keychain: keychain) == "11111111-2222-3333-4444-555555555555")
        #expect(keychain.sharedValue == "11111111-2222-3333-4444-555555555555")
        #expect(keychain.legacyValue == nil)
        // The next launch reads the shared item, the same id.
        #expect(Identity.current(keychain: keychain) == "11111111-2222-3333-4444-555555555555")
    }

    @Test func noNewIdIsMadeWhileAnOldOneExists() {
        let keychain = FakeKeychain(legacy: "old-id")
        keychain.refuseShared = true
        // The shared write fails: the old id keeps being used, and stays where it is.
        #expect(Identity.current(keychain: keychain) == "old-id")
        #expect(Identity.current(keychain: keychain) == "old-id")
        #expect(keychain.legacyValue == "old-id")
        #expect(keychain.sharedValue == nil)
    }

    @Test func theSharedIdWinsOverAnOldLocalOne() {
        // Another iPhone's id arrived through iCloud: that is the account's id.
        let keychain = FakeKeychain(shared: "from-icloud", legacy: "local")
        #expect(Identity.current(keychain: keychain) == "from-icloud")
    }

    @Test func aNewIdStillSurvivesWhereTheSharedItemIsRefused() {
        let keychain = FakeKeychain()
        keychain.refuseShared = true
        let first = Identity.current(keychain: keychain)
        #expect(keychain.legacyValue == first)
        #expect(Identity.current(keychain: keychain) == first)
    }

    @Test func deletingForgetsEveryCopyAndTheNextIdIsNew() {
        let keychain = FakeKeychain(shared: "a", legacy: "b")
        Identity.delete(keychain: keychain)
        #expect(keychain.sharedValue == nil && keychain.legacyValue == nil)
        let fresh = Identity.current(keychain: keychain)
        #expect(fresh != "a" && fresh != "b")
    }

    @Test func theWidgetsReadTheIdButNeverMakeOne() {
        // A widget before the app's first launch: no id, and none made (the app would then adopt it).
        let empty = FakeKeychain()
        #expect(Identity.existing(keychain: empty) == nil)
        #expect(empty.sharedValue == nil && empty.legacyValue == nil)
        #expect(Identity.existing(keychain: FakeKeychain(shared: "s", legacy: "l")) == "s")
        // An old local id is read where it is, not moved.
        let old = FakeKeychain(legacy: "l")
        #expect(Identity.existing(keychain: old) == "l")
        #expect(old.sharedValue == nil && old.legacyValue == "l")
    }
}
