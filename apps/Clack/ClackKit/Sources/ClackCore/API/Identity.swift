//
//  Identity.swift
//  Clack
//

import Foundation
import Security

/// Where the phone's id is kept. The real one is the Keychain; the tests use a fake.
public protocol IdentityKeychain: Sendable {
    /// The id in the iCloud Keychain item that follows you to a new iPhone.
    func readShared() -> String?
    /// Saves it there. False when the Keychain refuses (an unsigned build, no iCloud Keychain).
    func writeShared(_ id: String) -> Bool
    /// The id as earlier builds kept it: this phone only, no access group.
    func readLegacy() -> String?
    func writeLegacy(_ id: String)
    func deleteLegacy()
    /// Removes the item everywhere it syncs; also clears an old local one.
    func deleteAll()
}

/// The phone's id: a random UUID v4 in the Keychain, sent as `X-Clack-User` (docs/SWIFT_PORT.md B4). There is no sign-in. The
/// id is kept as a synchronizable item in an access group the app and its widgets share, so it survives a reinstall,
/// reaches the widget extension, and follows you to a new iPhone through the iCloud Keychain.
public nonisolated enum Identity {
    /// The id, or a new one saved on first launch. An id kept by an earlier build is moved to the shared item, never replaced.
    public static func current(keychain: IdentityKeychain = SystemKeychain()) -> String {
        #if DEBUG
        // `-userId <uuid>` as a launch argument acts as that phone, to look at a screen with known trips.
        if let override = UserDefaults.standard.string(forKey: "userId"), !override.isEmpty { return override.lowercased() }
        #endif
        if let shared = keychain.readShared() { return shared }
        if let legacy = keychain.readLegacy() {
            // Copy first, delete after: if the write fails the old item stays and keeps being used.
            if keychain.writeShared(legacy) { keychain.deleteLegacy() }
            return legacy
        }
        let fresh = UUID().uuidString.lowercased()
        // If the shared item can't be written (an unsigned build), keep it on this phone so it still survives a relaunch.
        if !keychain.writeShared(fresh) { keychain.writeLegacy(fresh) }
        return fresh
    }

    /// The id if this phone has one, without making or moving one. The widgets use this: only the app creates the id, so a
    /// widget that can't read the Keychain shows its cache instead of fetching as a new, empty phone.
    public static func existing(keychain: IdentityKeychain = SystemKeychain()) -> String? {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "userId"), !override.isEmpty { return override.lowercased() }
        #endif
        return keychain.readShared() ?? keychain.readLegacy()
    }

    /// Forgets the id ("Delete my data"): the next `current()` makes a new one. Also clears the widgets' copy of the data.
    public static func delete(keychain: IdentityKeychain = SystemKeychain()) {
        keychain.deleteAll()
        WidgetSnapshot.clear()
    }
}

/// The real Keychain. Items are service `clack.user`, account `id`.
public struct SystemKeychain: IdentityKeychain {
    private static let service = "clack.user"
    private static let account = "id"

    /// `<team prefix>com.garnerghering.Clack.shared`, from the Info.plist (`$(AppIdentifierPrefix)` is filled in at build time).
    /// Nil where there is none (tests, an unsigned build): then the item has no access group.
    private let accessGroup: String?

    public init(accessGroup: String? = SystemKeychain.bundleAccessGroup) {
        self.accessGroup = accessGroup
    }

    public static var bundleAccessGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "ClackKeychainGroup") as? String, !group.isEmpty,
              !group.contains("$(") else { return nil }
        return group
    }

    private func query(synchronizable: Any) -> [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecAttrSynchronizable as String: synchronizable,
        ]
        if let accessGroup, synchronizable as? Bool == true { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }

    private func read(_ q: [String: Any]) -> String? {
        var q = q
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func readShared() -> String? { read(query(synchronizable: true)) }

    public func writeShared(_ id: String) -> Bool {
        var q = query(synchronizable: true)
        q[kSecValueData as String] = Data(id.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(q as CFDictionary, nil)
        if status != errSecSuccess && status != errSecDuplicateItem {
            NSLog("Clack: the shared id could not be saved (OSStatus \(status))")
        }
        return status == errSecSuccess || status == errSecDuplicateItem
    }

    public func readLegacy() -> String? { read(query(synchronizable: false)) }

    public func writeLegacy(_ id: String) {
        var q = query(synchronizable: false)
        q[kSecValueData as String] = Data(id.utf8)
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(q as CFDictionary, nil)
    }

    public func deleteLegacy() { SecItemDelete(query(synchronizable: false) as CFDictionary) }

    public func deleteAll() { SecItemDelete(query(synchronizable: kSecAttrSynchronizableAny as Any) as CFDictionary) }
}
